//
//  CustomServiceManager.swift
//  Edx
//
//  Manages user-defined long-running services: persistence, process lifecycle,
//  and live log capture.
//

import Foundation
import AppKit
import SwiftUI

// MARK: - Log Store

/// Reference-type log buffer so appends don't copy the whole runtime struct.
@MainActor
@Observable
final class CustomServiceLogStore {
    private(set) var lines: [CustomServiceLogLine] = []

    /// Maximum number of retained log lines (older lines are dropped).
    private let maxLines = 2000

    func append(_ text: String, isError: Bool) {
        let pieces = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let now = Date()
        for piece in pieces where !piece.isEmpty {
            lines.append(CustomServiceLogLine(timestamp: now, text: piece, isError: isError))
        }

        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func clear() {
        lines.removeAll()
    }

    var combinedText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

// MARK: - Custom Service Manager

@MainActor
@Observable
final class CustomServiceManager {
    static let shared = CustomServiceManager()

    /// Persisted services.
    private(set) var services: [CustomService]

    /// Runtime status keyed by service id.
    private(set) var runtimes: [UUID: CustomServiceRuntime] = [:]

    /// Release check state keyed by service id.
    private(set) var updateCheckStates: [UUID: CustomServiceUpdateCheckState] = [:]

    /// Live log stores keyed by service id.
    @ObservationIgnored private var logStores: [UUID: CustomServiceLogStore] = [:]

    /// Active processes keyed by service id.
    @ObservationIgnored private var processes: [UUID: Process] = [:]

    /// Ids that were terminated intentionally (stop/restart), to suppress crash reporting.
    @ObservationIgnored private var expectedTerminations: Set<UUID> = []

    /// Repeating timer that drives automatic update checks.
    @ObservationIgnored private var autoCheckTimer: Timer?

    /// When GitHub rate-limits us, automatic checks pause until this time.
    @ObservationIgnored private var rateLimitedUntil: Date?

    private let defaults = UserDefaults.standard
    private let storageKey = "customServices"

    // MARK: - Auto-check settings

    /// UserDefaults keys shared with the settings UI (`@AppStorage`).
    static let autoCheckEnabledKey = "customServiceAutoCheckEnabled"
    static let autoCheckIntervalHoursKey = "customServiceAutoCheckIntervalHours"

    /// Whether automatic update checks are enabled (default on).
    var autoCheckEnabled: Bool {
        defaults.object(forKey: Self.autoCheckEnabledKey) as? Bool ?? true
    }

    /// Interval between automatic checks, in hours (default 6, clamped to >= 1).
    var autoCheckIntervalHours: Int {
        let stored = defaults.object(forKey: Self.autoCheckIntervalHoursKey) as? Int ?? 6
        return max(1, stored)
    }

    private init() {
        self.services = Self.loadServices(from: defaults, key: storageKey)
    }

    // MARK: - Persistence

    private static func loadServices(from defaults: UserDefaults, key: String) -> [CustomService] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomService].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(services) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - CRUD

    func addService(_ service: CustomService) {
        services.append(service)
        persist()
        // Detect installed version and check for updates right away.
        if service.githubRepository != nil {
            checkForUpdates(service, silent: true)
        }
    }

    func updateService(_ service: CustomService) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        let existing = services[index]
        var updated = service
        if updated.githubRepository == existing.githubRepository {
            updated.updateStatus = service.updateStatus ?? existing.updateStatus
        } else {
            // Repository changed: previous release info and skip choice no longer apply.
            updated.updateStatus = nil
            updated.ignoredVersion = nil
        }
        let repositoryChanged = updated.githubRepository != existing.githubRepository
        let versionCommandChanged = updated.versionCommand != existing.versionCommand
        services[index] = updated
        persist()
        // Re-detect version / re-check when the repo or version command changed.
        if updated.githubRepository != nil, repositoryChanged || versionCommandChanged {
            checkForUpdates(updated, silent: true)
        }
    }

    func deleteService(_ service: CustomService) {
        if isRunning(service.id) {
            stop(service)
        }
        services.removeAll { $0.id == service.id }
        runtimes[service.id] = nil
        updateCheckStates[service.id] = nil
        logStores[service.id] = nil
        processes[service.id] = nil
        persist()
    }

    /// Reorder helper used by the list UI.
    func moveServices(fromOffsets source: IndexSet, toOffset destination: Int) {
        services.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Accessors

    func runtime(for id: UUID) -> CustomServiceRuntime {
        runtimes[id] ?? CustomServiceRuntime()
    }

    func status(for id: UUID) -> CustomServiceStatus {
        runtime(for: id).status
    }

    func isRunning(_ id: UUID) -> Bool {
        runtime(for: id).status.isActive
    }

    func logStore(for id: UUID) -> CustomServiceLogStore {
        if let store = logStores[id] {
            return store
        }
        let store = CustomServiceLogStore()
        logStores[id] = store
        return store
    }

    func updateCheckState(for id: UUID) -> CustomServiceUpdateCheckState {
        updateCheckStates[id] ?? CustomServiceUpdateCheckState()
    }

    var menuBarServices: [CustomService] {
        services.filter(\.showInMenuBar)
    }

    // MARK: - Updates

    /// Check a single service for a newer GitHub release.
    /// - Parameter silent: when true, suppresses the transient success/error
    ///   banner text (used by automatic background checks). The persisted
    ///   `updateStatus` is still updated either way.
    func checkForUpdates(_ service: CustomService, silent: Bool = false) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        guard let repositoryText = services[index].githubRepository,
              let repository = GitHubRepository.normalize(repositoryText) else {
            if !silent {
                updateCheckStates[service.id] = CustomServiceUpdateCheckState(
                    isChecking: false,
                    requestID: (updateCheckStates[service.id]?.requestID ?? 0) + 1,
                    message: "custom.service.update.error.invalidRepository".localized()
                )
            }
            return
        }

        // Avoid stacking a second request while one is already in flight.
        guard updateCheckStates[service.id]?.isChecking != true else { return }

        let requestID = (updateCheckStates[service.id]?.requestID ?? 0) + 1
        updateCheckStates[service.id] = CustomServiceUpdateCheckState(isChecking: true, requestID: requestID, message: nil)

        // Snapshot fields needed to detect the installed version off the main actor.
        let versionCommand = service.effectiveVersionCommand
        let workingDirectory = service.workingDirectory
        let environment = service.environment

        Task {
            // Detect the installed version (best-effort) in parallel with the
            // GitHub release lookup.
            async let detected = Self.detectVersion(
                command: versionCommand,
                workingDirectory: workingDirectory,
                environment: environment
            )

            let existingEtag = services[index].updateStatus?.etag
            let githubToken = KeychainHelper.getGitHubToken()
            do {
                let outcome = try await CustomServiceUpdateService.shared.checkLatestRelease(
                    for: repository,
                    etag: existingEtag,
                    token: githubToken
                )
                let detectedVersion = await detected
                await MainActor.run {
                    guard self.updateCheckStates[service.id]?.requestID == requestID else { return }
                    self.rateLimitedUntil = nil
                    if let detectedVersion {
                        self.setDetectedVersion(detectedVersion, for: service.id)
                    }
                    switch outcome {
                    case .updated(let status):
                        self.applyUpdateStatus(status, to: service.id)
                    case .notModified:
                        // Nothing changed on GitHub; just refresh the check time.
                        self.markChecked(service.id)
                    }
                    // Clear the transient banner so the row shows the real outcome
                    // ("up to date" / "new version X" / "ignored"), not a useless
                    // "check complete" message.
                    self.updateCheckStates[service.id] = CustomServiceUpdateCheckState(
                        isChecking: false,
                        requestID: requestID,
                        message: nil
                    )
                }
            } catch {
                let detectedVersion = await detected
                await MainActor.run {
                    guard self.updateCheckStates[service.id]?.requestID == requestID else { return }
                    if let detectedVersion {
                        self.setDetectedVersion(detectedVersion, for: service.id)
                    }
                    if let updateError = error as? CustomServiceUpdateError,
                       case .rateLimited(let reset) = updateError {
                        // Pause automatic checks until the limit resets.
                        self.rateLimitedUntil = reset ?? Date().addingTimeInterval(3600)
                    }
                    let message = Self.updateErrorMessage(error)
                    self.applyUpdateError(message, repository: repository.slug, to: service.id)
                    self.updateCheckStates[service.id] = CustomServiceUpdateCheckState(
                        isChecking: false,
                        requestID: requestID,
                        message: silent ? nil : message
                    )
                }
            }
        }
    }

    /// Run the version-detection command off the main actor and extract a version.
    private static func detectVersion(
        command: String?,
        workingDirectory: String?,
        environment: [String: String]
    ) async -> String? {
        guard let command else { return nil }
        return await Task.detached(priority: .utility) {
            let result = CustomServiceCommandRunner.run(
                commandLine: command,
                workingDirectory: workingDirectory,
                environment: environment,
                timeout: 10
            )
            guard !result.timedOut else { return nil }
            return VersionExtractor.extract(from: result.output)
        }.value
    }

    private func setDetectedVersion(_ version: String, for id: UUID) {
        guard let index = services.firstIndex(where: { $0.id == id }) else { return }
        guard services[index].currentVersion != version else { return }
        services[index].currentVersion = version
        persist()
    }

    /// Refresh the last-checked time on an unchanged (304) result.
    private func markChecked(_ id: UUID) {
        guard let index = services.firstIndex(where: { $0.id == id }) else { return }
        guard var status = services[index].updateStatus else { return }
        status.lastCheckedAt = Date()
        status.errorMessage = nil
        services[index].updateStatus = status
        persist()
    }

    /// Run the configured update command, then re-check version and release.
    func performUpdate(_ service: CustomService) {
        guard let updateCommand = service.normalizedUpdateCommand else { return }
        guard updateCheckStates[service.id]?.isUpdating != true else { return }

        let requestID = (updateCheckStates[service.id]?.requestID ?? 0) + 1
        updateCheckStates[service.id] = CustomServiceUpdateCheckState(
            isChecking: false,
            isUpdating: true,
            requestID: requestID,
            message: "custom.service.update.updating".localized()
        )

        let workingDirectory = service.workingDirectory
        let environment = service.environment
        let id = service.id

        appendLog(id, text: "$ " + updateCommand, isError: false)

        Task {
            let result = await Task.detached(priority: .utility) {
                CustomServiceCommandRunner.run(
                    commandLine: updateCommand,
                    workingDirectory: workingDirectory,
                    environment: environment,
                    timeout: 300
                )
            }.value

            await MainActor.run {
                guard self.updateCheckStates[id]?.requestID == requestID else { return }
                if !result.output.isEmpty {
                    self.appendLog(id, text: result.output, isError: result.exitCode != 0)
                }
                let success = result.exitCode == 0 && !result.timedOut
                self.updateCheckStates[id] = CustomServiceUpdateCheckState(
                    isChecking: false,
                    isUpdating: false,
                    requestID: requestID,
                    message: success
                        ? "custom.service.update.updateSuccess".localized()
                        : "custom.service.update.updateFailed".localized()
                )
                // Refresh installed version + release info after a successful update.
                if success, let refreshed = self.services.first(where: { $0.id == id }) {
                    self.checkForUpdates(refreshed, silent: true)
                }
            }
        }
    }

    /// Check every service that has a configured repository.
    /// - Parameter force: when false, services checked very recently are skipped
    ///   to conserve the unauthenticated GitHub rate limit.
    func checkAllForUpdates(force: Bool = false) {
        // Respect a rate-limit cooldown for automatic runs.
        if !force, let until = rateLimitedUntil, Date() < until { return }

        let now = Date()
        // Skip services checked within the last 30 minutes for scheduled runs.
        let minInterval: TimeInterval = 30 * 60

        for service in services where service.githubRepository != nil {
            if !force,
               let lastChecked = service.updateStatus?.lastCheckedAt,
               now.timeIntervalSince(lastChecked) < minInterval {
                continue
            }
            checkForUpdates(service, silent: true)
        }
    }

    func openLatestRelease(for service: CustomService) {
        guard let urlString = service.updateStatus?.latestReleaseURL,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Skip the currently discovered release so it stops being flagged as available.
    func ignoreLatestVersion(for service: CustomService) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        guard let latest = services[index].updateStatus?.latestVersion,
              !latest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        services[index].ignoredVersion = latest
        persist()
    }

    /// Clear a previously skipped version so its update is flagged again.
    func clearIgnoredVersion(for service: CustomService) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[index].ignoredVersion = nil
        persist()
    }

    /// Adopt the latest discovered release as the current installed version.
    /// Useful after the user has updated the underlying tool.
    func markLatestAsCurrent(for service: CustomService) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        guard let latest = services[index].updateStatus?.latestVersion,
              !latest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        services[index].currentVersion = latest
        services[index].ignoredVersion = nil
        persist()
    }

    private func applyUpdateStatus(_ status: CustomServiceUpdateStatus, to id: UUID) {
        guard let index = services.firstIndex(where: { $0.id == id }) else { return }
        services[index].githubRepository = status.repository
        services[index].updateStatus = status
        persist()
    }

    private static func updateErrorMessage(_ error: Error) -> String {
        if let updateError = error as? CustomServiceUpdateError {
            if let statusCode = updateError.statusCode {
                return String(format: updateError.messageKey.localized(), statusCode)
            }
            return updateError.messageKey.localized()
        }
        return error.localizedDescription
    }

    private func applyUpdateError(_ message: String, repository: String, to id: UUID) {
        guard let index = services.firstIndex(where: { $0.id == id }) else { return }
        let previous = services[index].updateStatus
        services[index].updateStatus = CustomServiceUpdateStatus(
            repository: repository,
            latestVersion: previous?.latestVersion ?? "",
            latestReleaseTitle: previous?.latestReleaseTitle ?? "",
            latestReleaseURL: previous?.latestReleaseURL ?? "",
            latestPublishedAt: previous?.latestPublishedAt,
            lastCheckedAt: Date(),
            errorMessage: message
        )
        persist()
    }

    // MARK: - Automatic update checks

    /// Kick off automatic update checking. Called once during app initialization.
    /// Performs an initial check shortly after launch, then reschedules a
    /// repeating timer based on the configured interval.
    func startAutoUpdateChecks() {
        reconfigureAutoUpdateChecks(runInitialCheck: true)
    }

    /// (Re)configure the auto-check timer. Call after the enabled flag or
    /// interval changes in settings.
    func reconfigureAutoUpdateChecks(runInitialCheck: Bool = false) {
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil

        guard autoCheckEnabled else { return }

        if runInitialCheck {
            // Delay slightly so it doesn't compete with launch work.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
                guard self.autoCheckEnabled else { return }
                self.checkAllForUpdates()
            }
        }

        let interval = TimeInterval(autoCheckIntervalHours) * 3600
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllForUpdates()
            }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        autoCheckTimer = timer
    }

    // MARK: - Lifecycle

    /// Auto-start any services flagged for it. Called once during app initialization.
    func startAutoStartServices() {
        for service in services where service.autoStart {
            start(service)
        }
    }

    func start(_ service: CustomService) {
        guard !isRunning(service.id) else { return }

        let tokens = CommandTokenizer.tokenize(service.command)
        guard let executableToken = tokens.first, !executableToken.isEmpty else {
            setRuntime(service.id, status: .failed("custom.service.error.emptyCommand".localized()),
                       error: "custom.service.error.emptyCommand".localized())
            return
        }

        guard let executablePath = Self.resolveExecutable(executableToken) else {
            let message = String(format: "custom.service.error.notFound".localized(), executableToken)
            appendLog(service.id, text: message, isError: true)
            setRuntime(service.id, status: .failed(message), error: message)
            return
        }

        let arguments = Array(tokens.dropFirst())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        // Augment PATH so child processes can locate sibling tools.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.augmentedPATH(existing: env["PATH"])
        for (key, value) in service.environment {
            env[key] = value
        }
        process.environment = env

        if let workingDirectory = service.workingDirectory,
           !workingDirectory.trimmingCharacters(in: .whitespaces).isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: (workingDirectory as NSString).expandingTildeInPath)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let id = service.id

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.appendLog(id, text: text, isError: false) }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.appendLog(id, text: text, isError: true) }
        }

        process.terminationHandler = { [weak self] proc in
            let code = proc.terminationStatus
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
            Task { @MainActor in self?.handleTermination(id: id, exitCode: code) }
        }

        setRuntime(id, status: .starting)
        appendLog(id, text: "$ " + service.command, isError: false)

        do {
            try process.run()
            processes[id] = process
            var runtime = runtime(for: id)
            runtime.status = .running
            runtime.pid = process.processIdentifier
            runtime.startedAt = Date()
            runtime.lastError = nil
            runtimes[id] = runtime
        } catch {
            let message = String(format: "custom.service.error.launchFailed".localized(), error.localizedDescription)
            appendLog(id, text: message, isError: true)
            setRuntime(id, status: .failed(message), error: message)
            processes[id] = nil
        }
    }

    func stop(_ service: CustomService) {
        stop(id: service.id)
    }

    func stop(id: UUID) {
        guard let process = processes[id], process.isRunning else {
            setRuntime(id, status: .stopped)
            return
        }

        expectedTerminations.insert(id)
        setRuntime(id, status: .stopping)
        appendLog(id, text: "custom.service.log.stopping".localized(), isError: false)

        // Try graceful termination first, then force kill if it lingers.
        process.terminate()

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self else { return }
            if let proc = self.processes[id], proc.isRunning {
                kill(proc.processIdentifier, SIGKILL)
            }
        }
    }

    func restart(_ service: CustomService) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.isRunning(service.id) {
                self.stop(service)
                // Wait for clean shutdown before relaunching.
                for _ in 0..<30 {
                    if !self.isRunning(service.id) { break }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            self.start(service)
        }
    }

    /// Stop every running service. Called during app shutdown.
    func stopAll() {
        for (id, process) in processes where process.isRunning {
            expectedTerminations.insert(id)
            process.terminate()
        }
    }

    // MARK: - Logs

    func clearLogs(for id: UUID) {
        logStore(for: id).clear()
    }

    // MARK: - Internal Helpers

    private func appendLog(_ id: UUID, text: String, isError: Bool) {
        logStore(for: id).append(text, isError: isError)
    }

    private func setRuntime(_ id: UUID, status: CustomServiceStatus, error: String? = nil) {
        var runtime = runtime(for: id)
        runtime.status = status
        if let error {
            runtime.lastError = error
        }
        if !status.isActive {
            runtime.pid = nil
        }
        runtimes[id] = runtime
    }

    private func handleTermination(id: UUID, exitCode: Int32) {
        processes[id] = nil

        var runtime = runtime(for: id)
        runtime.pid = nil
        runtime.lastExitCode = exitCode

        let wasExpected = expectedTerminations.remove(id) != nil

        if wasExpected || exitCode == 0 {
            runtime.status = .stopped
            appendLog(id, text: String(format: "custom.service.log.exited".localized(), exitCode), isError: false)
        } else {
            let message = String(format: "custom.service.log.crashed".localized(), exitCode)
            runtime.status = .failed(message)
            runtime.lastError = message
            appendLog(id, text: message, isError: true)
        }

        runtimes[id] = runtime
    }

    // MARK: - Executable Resolution

    /// Common locations to search for executables when shell lookup does not find them.
    private static let searchPaths: [String] = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        "~/.local/bin",
        "~/.cargo/bin",
        "~/.bun/bin",
        "~/.deno/bin",
        "~/.npm-global/bin",
        "~/go/bin",
        "~/.volta/bin",
        "~/.asdf/shims",
        "~/.local/share/mise/shims"
    ]

    /// Build a PATH value that includes the app environment, login shell PATH, and common dirs.
    static func augmentedPATH(existing: String?) -> String {
        var dirs: [String] = []
        appendPathList(existing, to: &dirs)
        appendPathList(loginShellPATH(), to: &dirs)
        for path in searchPaths {
            dirs.append(NSString(string: path).expandingTildeInPath)
        }

        var seen = Set<String>()
        let ordered = dirs.filter { seen.insert($0).inserted }
        return ordered.joined(separator: ":")
    }

    /// Resolve an executable token to an absolute path.
    static func resolveExecutable(_ token: String) -> String? {
        let fileManager = FileManager.default

        // Absolute or relative path with a slash: use directly.
        if token.contains("/") {
            let expanded = NSString(string: token).expandingTildeInPath
            return fileManager.isExecutableFile(atPath: expanded) ? expanded : nil
        }

        if let shellResolved = resolveExecutableWithLoginShell(token, fileManager: fileManager) {
            return shellResolved
        }

        let pathDirs = augmentedPATH(existing: ProcessInfo.processInfo.environment["PATH"])
            .split(separator: ":")
            .map(String.init)
        for dir in pathDirs {
            let candidate = (dir as NSString).appendingPathComponent(token)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func resolveExecutableWithLoginShell(_ token: String, fileManager: FileManager) -> String? {
        guard let output = loginShellOutput(command: "command -v \"$1\"", token: token) else {
            return nil
        }
        let resolved = NSString(string: output).expandingTildeInPath
        return fileManager.isExecutableFile(atPath: resolved) ? resolved : nil
    }

    private static func loginShellPATH() -> String? {
        loginShellOutput(command: "printf '%s' \"$PATH\"")
    }

    private static func appendPathList(_ pathList: String?, to dirs: inout [String]) {
        guard let pathList, !pathList.isEmpty else { return }
        dirs.append(contentsOf: pathList.split(separator: ":").map(String.init))
    }

    private static func loginShellOutput(command: String, token: String? = nil) -> String? {
        let fileManager = FileManager.default
        let shellPath = loginShellPath(fileManager: fileManager)
        guard fileManager.isExecutableFile(atPath: shellPath) else { return nil }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: shellPath)
        if let token {
            process.arguments = ["-l", "-c", command, "edx-command-lookup", token]
        } else {
            process.arguments = ["-l", "-c", command]
        }
        process.standardOutput = outputPipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loginShellPath(fileManager: FileManager) -> String {
        let candidates = [
            ProcessInfo.processInfo.environment["SHELL"],
            "/bin/zsh",
            "/bin/bash",
            "/bin/sh"
        ].compactMap { $0 }

        return candidates.first { fileManager.isExecutableFile(atPath: $0) } ?? "/bin/sh"
    }
}
