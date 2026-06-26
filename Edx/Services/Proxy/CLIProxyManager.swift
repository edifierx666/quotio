//
//  CLIProxyManager.swift
//  Edx - CLIProxyAPI GUI Wrapper
//

import Foundation
import AppKit

@MainActor
@Observable
final class CLIProxyManager {
    static let shared = CLIProxyManager()
    
    // MARK: - Two-Layer Proxy Architecture
    
    /// The ProxyBridge sits between clients and CLIProxyAPI to handle connection management
    /// This solves the stale connection issue by forcing "Connection: close" on all requests
    let proxyBridge = ProxyBridge()
    
    /// When enabled: clients connect to userPort, ProxyBridge forwards to internalPort
    /// When disabled: clients connect directly to userPort where CLIProxyAPI runs
    var useBridgeMode: Bool {
        get { UserDefaults.standard.bool(forKey: "useBridgeMode") }
        set { UserDefaults.standard.set(newValue, forKey: "useBridgeMode") }
    }
    
    /// Whether to allow network access to the proxy (bind to 0.0.0.0)
    var allowNetworkAccess: Bool {
        get { configHostAllowsNetworkAccess() }
        set {
            ensureConfigExists()
            guard newValue != configHostAllowsNetworkAccess() else { return }
            if newValue {
                ensureApiKeyExistsInConfig()
            }
            updateConfigHost(newValue ? "0.0.0.0" : "127.0.0.1")

            // Restart proxy if running to apply changes
            restartProxyIfRunning()
        }
    }
    
    /// Internal port where CLIProxyAPI runs (when bridge mode is enabled)
    var internalPort: UInt16 {
        ProxyBridge.internalPort(from: proxyStatus.port)
    }
    
    nonisolated static func terminateProxyOnShutdown() {
        let port = shutdownUserPort()
        let useBridge = UserDefaults.standard.bool(forKey: "useBridgeMode")

        // Kill user-facing port
        killProcessOnPort(port)

        // Only kill internal port if bridge mode is enabled
        // to avoid accidentally killing unrelated services
        if useBridge {
            killProcessOnPort(ProxyBridge.internalPort(from: port))
        }
    }

    nonisolated private static func shutdownUserPort() -> UInt16 {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let configURL = appSupport
                .appendingPathComponent("Edx")
                .appendingPathComponent("config.yaml")
            if let content = try? String(contentsOf: configURL, encoding: .utf8),
               let configPort = extractTopLevelPort(from: content) {
                return configPort
            }
        }

        return 8080
    }
    
    /// IMPORTANT: Excludes own PID to prevent killing Edx itself when ProxyBridge is running.
    nonisolated private static func killProcessOnPort(_ port: UInt16) {
        let lsofProcess = Process()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProcess.arguments = ["-ti", "tcp:\(port)"]

        let pipe = Pipe()
        lsofProcess.standardOutput = pipe
        lsofProcess.standardError = FileHandle.nullDevice

        // Get own PID to avoid killing ourselves (ProxyBridge runs in our process)
        let ownPid = ProcessInfo.processInfo.processIdentifier

        do {
            try lsofProcess.run()
            lsofProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return }

            for pidString in output.components(separatedBy: .newlines) {
                if let pid = Int32(pidString.trimmingCharacters(in: .whitespaces)) {
                    // Never kill our own process - ProxyBridge uses NWListener in-process
                    if pid == ownPid {
                        NSLog("[CLIProxyManager] Skipping kill of own PID \(pid) on port \(port) during shutdown")
                        continue
                    }
                    kill(pid, SIGKILL)
                }
            }
        } catch {
        }
    }
    
    private var process: Process?
    private var authProcess: Process?
    private(set) var proxyStatus = ProxyStatus()
    private(set) var isStarting = false
    private(set) var isDownloading = false
    private(set) var isRegeneratingKey = false
    private(set) var downloadProgress: Double = 0
    private(set) var lastError: String?
    
    // MARK: - Managed Upgrade State
    
    /// Current state of the proxy manager.
    private(set) var managerState: ProxyManagerState = .idle
    
    /// User-facing port selected from the local config for the active proxy process.
    private var activeUserPort: UInt16?

    /// Actual CLIProxyAPI port selected for the active proxy process.
    private var activeCLIProxyPort: UInt16?

    /// The active proxy version (if using versioned storage).
    private(set) var activeVersion: String?
    
    /// Last upgrade error message.
    private(set) var upgradeError: String?
    
    /// Whether an upgrade is available.
    private(set) var upgradeAvailable: Bool = false
    
    /// Available upgrade version info.
    private(set) var availableUpgrade: ProxyVersionInfo?
    
    /// Last time a proxy update check was performed.
    var lastProxyUpdateCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastProxyUpdateCheckDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastProxyUpdateCheckDate") }
    }
    
    /// Health monitor task for auto-recovery
    private var healthMonitorTask: Task<Void, Never>?

    /// PIDs that Edx intentionally terminates during stop/restart/upgrade flows.
    private var expectedTerminationPIDs = Set<Int32>()

    /// Pending restart after an unexpected proxy process exit.
    private var crashRestartTask: Task<Void, Never>?

    /// Consecutive restart attempts after unexpected process exits.
    private var crashRestartAttempts: Int = 0
    
    /// Consecutive health check failures
    private var healthCheckFailures: Int = 0
    
    /// Max failures before auto-restart
    private let maxHealthCheckFailures = 3

    /// Max crash restarts before giving up and leaving the proxy stopped.
    private let maxCrashRestartAttempts = 3
    
    /// Health check interval in seconds
    private let healthCheckIntervalSeconds: UInt64 = 30

    /// Initial delay before restarting after an unexpected process exit.
    private let crashRestartBaseDelaySeconds: UInt64 = 2

    /// Maximum restart delay after repeated unexpected process exits.
    private let maxCrashRestartDelaySeconds: UInt64 = 30
    
    /// Compatibility checker instance.
    private let compatibilityChecker = CompatibilityChecker()
    
    /// Storage manager for versioned binaries.
    var storageManager: ProxyStorageManager { ProxyStorageManager.shared }
    
    let binaryPath: String
    let configPath: String
    let authDir: String
    private(set) var managementKey: String
    
    var port: UInt16 {
        get { proxyStatus.port }
        set {
            guard newValue != proxyStatus.port else { return }
            updateProxyStatus(running: proxyStatus.running, port: newValue)
            updateConfigPort(newValue)
            restartProxyIfRunning()
        }
    }
    
    private static let binaryName = "CLIProxyAPI"
    nonisolated private static let cliProxyProcessNames: Set<String> = [
        "cliproxyapi",
        "cli-proxy-api",
        "cli-proxy-api-plus",
        "claude-code-proxy",
        "proxy"
    ]
    
    /// Base URL for the proxy API (always points to CLIProxyAPI directly)
    /// When bridge mode is enabled, this uses the internal port
    var baseURL: String {
        let port = activeCLIProxyPort ?? (useBridgeMode ? internalPort : proxyStatus.port)
        return "http://127.0.0.1:\(port)"
    }
    
    var managementURL: String {
        "\(baseURL)/v0/management"
    }
    
    /// The endpoint URL that clients should use (user-facing port)
    var clientEndpoint: String {
        "http://127.0.0.1:\(proxyStatus.port)"
    }
    
    init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory not found")
        }
        let edxDir = appSupport.appendingPathComponent("Edx")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        try? FileManager.default.createDirectory(at: edxDir, withIntermediateDirectories: true)

        self.binaryPath = edxDir.appendingPathComponent("CLIProxyAPI").path
        self.configPath = edxDir.appendingPathComponent("config.yaml").path
        self.authDir = homeDir.appendingPathComponent(".cli-proxy-api").path
        
        // Always use key from Keychain, generate new if not exists
        // Never read from config because CLIProxyAPI hashes the key on startup
        if let savedKey = KeychainHelper.getLocalManagementKey(), !savedKey.hasPrefix("$2a$") {
            self.managementKey = savedKey
        } else {
            let newKey = UUID().uuidString
            self.managementKey = newKey
            if !KeychainHelper.saveLocalManagementKey(newKey) {
                Log.keychain("Failed to persist local management key, using in-memory value")
            }
        }
        
        // Note: Bridge mode default is registered in AppDelegate.applicationDidFinishLaunching()
        // using UserDefaults.register(defaults:) which is the preferred approach

        try? FileManager.default.createDirectory(atPath: authDir, withIntermediateDirectories: true)

        migrateLegacyVersionedStorageIfNeeded()
        initializeSelectedBinarySourceIfNeeded()
        ensureConfigExists()
        loadUserPortFromConfigIfPresent()
    }

    /// Restart the proxy if it is currently running.
    /// This is used to apply configuration changes that require a restart.
    private func restartProxyIfRunning() {
        guard proxyStatus.running else { return }

        Task {
            NSLog("[CLIProxyManager] Restarting proxy to apply configuration changes...")
            stop()
            // Wait 0.5s for ports to clear
            try? await Task.sleep(nanoseconds: 500_000_000)

            do {
                try await start()
                NSLog("[CLIProxyManager] Proxy restarted successfully")
            } catch {
                NSLog("[CLIProxyManager] Failed to restart proxy: \(error)")
                lastError = "Failed to restart: \(error.localizedDescription)"
            }
        }
    }

    struct LocalProxyConfigSnapshot {
        let proxyURL: String?
        let routingStrategy: String
        let switchProject: Bool
        let switchPreviewModel: Bool
        let requestRetry: Int
        let maxRetryInterval: Int
        let loggingToFile: Bool
        let requestLog: Bool
        let debug: Bool
        let allowNetworkAccess: Bool
    }

    func loadLocalConfigSnapshot() -> LocalProxyConfigSnapshot? {
        guard let content = readLocalConfigContent() else { return nil }

        return LocalProxyConfigSnapshot(
            proxyURL: Self.extractTopLevelString("proxy-url", from: content),
            routingStrategy: Self.extractNestedString(section: "routing", key: "strategy", from: content) ?? "round-robin",
            switchProject: Self.extractNestedBool(section: "quota-exceeded", key: "switch-project", from: content) ?? true,
            switchPreviewModel: Self.extractNestedBool(section: "quota-exceeded", key: "switch-preview-model", from: content) ?? true,
            requestRetry: Self.extractTopLevelInt("request-retry", from: content) ?? 3,
            maxRetryInterval: Self.extractTopLevelInt("max-retry-interval", from: content) ?? 30,
            loggingToFile: Self.extractTopLevelBool("logging-to-file", from: content) ?? true,
            requestLog: Self.extractTopLevelBool("request-log", from: content) ?? false,
            debug: Self.extractTopLevelBool("debug", from: content) ?? false,
            allowNetworkAccess: Self.extractTopLevelHost(from: content) == "0.0.0.0"
        )
    }

    private func readLocalConfigContent() -> String? {
        guard FileManager.default.fileExists(atPath: configPath),
              let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            NSLog("[CLIProxyManager] ERROR: Failed to read config file at \(configPath)")
            return nil
        }

        return content
    }

    @discardableResult
    private func writePatchedConfig(_ patch: (String) -> String) -> Bool {
        guard let content = readLocalConfigContent() else { return false }
        let patchedContent = patch(content)

        guard patchedContent != content else { return true }

        do {
            try patchedContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSLog("[CLIProxyManager] ERROR: Failed to write config file: \(error)")
            return false
        }
    }

    @discardableResult
    private func updateTopLevelConfigValue(key: String, value: String) -> Bool {
        writePatchedConfig { content in
            Self.replaceOrAppendTopLevelValue(key: key, value: value, in: content)
        }
    }

    @discardableResult
    private func updateNestedConfigValue(section: String, key: String, value: String) -> Bool {
        writePatchedConfig { content in
            Self.replaceOrAppendNestedValue(section: section, key: key, value: value, in: content)
        }
    }

    private func updateConfigPort(_ newPort: UInt16) {
        updateTopLevelConfigValue(key: "port", value: "\(newPort)")
    }

    private func loadUserPortFromConfigIfPresent() {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8),
              let configPort = Self.extractTopLevelPort(from: content) else {
            return
        }

        updateProxyStatus(running: proxyStatus.running, port: configPort)
    }

    private func updateProxyStatus(running: Bool? = nil, port: UInt16? = nil) {
        var nextStatus = proxyStatus
        if let running {
            nextStatus.running = running
        }
        if let port {
            nextStatus.port = port
        }
        guard nextStatus.running != proxyStatus.running || nextStatus.port != proxyStatus.port else { return }
        proxyStatus = nextStatus
    }

    private func configHostAllowsNetworkAccess() -> Bool {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return false
        }

        return Self.extractTopLevelHost(from: content) == "0.0.0.0"
    }

    private func updateConfigHost(_ host: String) {
        updateTopLevelConfigValue(key: "host", value: quoteYAMLScalar(host))
    }

    private func ensureApiKeyExistsInConfig() {
        guard FileManager.default.fileExists(atPath: configPath),
              let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return
        }

        var lines = content.components(separatedBy: "\n")
        if let apiKeysIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "api-keys:" }) {
            var hasKey = false
            var scanIndex = apiKeysIndex + 1

            while scanIndex < lines.count {
                let line = lines[scanIndex]
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.isEmpty {
                    break
                }

                if trimmed.hasPrefix("-") {
                    let value = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { hasKey = true }
                    scanIndex += 1
                    continue
                }

                if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                    break
                }

                scanIndex += 1
            }

            if !hasKey {
                let newKey = "edx-local-\(UUID().uuidString)"
                lines.insert("  - \"\(newKey)\"", at: apiKeysIndex + 1)
                try? lines.joined(separator: "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
            }
            return
        }

        let newKey = "edx-local-\(UUID().uuidString)"
        lines.append("")
        lines.append("api-keys:")
        lines.append("  - \"\(newKey)\"")
        lines.append("")
        try? lines.joined(separator: "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
    }
    
    @discardableResult
    func updateConfigAllowRemote(_ enabled: Bool) -> Bool {
        updateNestedConfigValue(section: "remote-management", key: "allow-remote", value: "\(enabled)")
    }

    @discardableResult
    func updateConfigLogging(enabled: Bool) -> Bool {
        updateTopLevelConfigValue(key: "logging-to-file", value: "\(enabled)")
    }

    /// Update routing strategy in the persistent config file.
    func updateConfigRoutingStrategy(_ strategy: String) -> Bool {
        updateNestedConfigValue(section: "routing", key: "strategy", value: quoteYAMLScalar(strategy))
    }

    @discardableResult
    func updateConfigSwitchProject(_ enabled: Bool) -> Bool {
        updateNestedConfigValue(section: "quota-exceeded", key: "switch-project", value: "\(enabled)")
    }

    @discardableResult
    func updateConfigSwitchPreviewModel(_ enabled: Bool) -> Bool {
        updateNestedConfigValue(section: "quota-exceeded", key: "switch-preview-model", value: "\(enabled)")
    }

    @discardableResult
    func updateConfigRequestRetry(_ count: Int) -> Bool {
        updateTopLevelConfigValue(key: "request-retry", value: "\(count)")
    }

    @discardableResult
    func updateConfigMaxRetryInterval(_ seconds: Int) -> Bool {
        updateTopLevelConfigValue(key: "max-retry-interval", value: "\(seconds)")
    }

    @discardableResult
    func updateConfigRequestLog(_ enabled: Bool) -> Bool {
        updateTopLevelConfigValue(key: "request-log", value: "\(enabled)")
    }

    @discardableResult
    func updateConfigDebug(_ enabled: Bool) -> Bool {
        updateTopLevelConfigValue(key: "debug", value: "\(enabled)")
    }
    
    @discardableResult
    func updateConfigProxyURL(_ url: String?, restartIfRunning: Bool = true) -> Bool {
        guard FileManager.default.fileExists(atPath: configPath),
              var content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return false }

        let proxyValue = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let replacement = "proxy-url: \(quoteYAMLScalar(proxyValue))"
        var didWrite = false

        if let range = content.range(of: #"(?m)^proxy-url:\s*[^\n]*"#, options: .regularExpression) {
            content.replaceSubrange(range, with: replacement)
            didWrite = true
        } else if let portRange = content.range(of: #"(?m)^port:\s*[^\n]*\n?"#, options: .regularExpression) {
            let separator = content[portRange].hasSuffix("\n") ? "" : "\n"
            content.insert(contentsOf: "\(separator)\(replacement)\n", at: portRange.upperBound)
            didWrite = true
        } else {
            content = Self.appendLine(replacement, to: content)
            didWrite = true
        }

        if didWrite {
            do {
                try content.write(toFile: configPath, atomically: true, encoding: .utf8)
            } catch {
                NSLog("[CLIProxyManager] ERROR: Failed to write proxy URL config: \(error)")
                return false
            }
        }

        if restartIfRunning {
            restartProxyIfRunning()
        }

        return true
    }

    // MARK: - Workarounds

    /// Applies a workaround to force the primary Google API URL in all auth files.
    /// This prevents fallback to the slow "sandbox" environment.
    /// Backs up original files before modification.
    func applyBaseURLWorkaround() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: authDir) else { return }

        for file in files where file.hasSuffix(".json") && file.starts(with: "antigravity-") {
            let path = (authDir as NSString).appendingPathComponent(file)
            let backupPath = path + ".bak"

            // Create backup if it doesn't exist
            if !fileManager.fileExists(atPath: backupPath) {
                try? fileManager.copyItem(atPath: path, toPath: backupPath)
            }

            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  var json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { continue }

            var metadata = json["metadata"] as? [String: Any] ?? [:]
            metadata["base_url"] = "https://daily-cloudcode-pa.googleapis.com"
            json["metadata"] = metadata

            if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                try? newData.write(to: URL(fileURLWithPath: path))
            }
        }

        restartProxyIfRunning()
    }

    /// Restores the original auth files from backup, effectively reverting the URL workaround.
    func removeBaseURLWorkaround() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: authDir) else { return }

        var restoredCount = 0

        for file in files where file.hasSuffix(".json.bak") {
            let backupPath = (authDir as NSString).appendingPathComponent(file)
            let originalPath = backupPath.replacingOccurrences(of: ".bak", with: "")

            // Restore from backup
            do {
                if fileManager.fileExists(atPath: originalPath) {
                    try fileManager.removeItem(atPath: originalPath)
                }
                try fileManager.moveItem(atPath: backupPath, toPath: originalPath)
                restoredCount += 1
            } catch {
                NSLog("[CLIProxyManager] Failed to restore backup for \(file): \(error)")
            }
        }

        // Fallback: If no backups found, try to just remove the key from current files
        if restoredCount == 0 {
            for file in files where file.hasSuffix(".json") && file.starts(with: "antigravity-") {
                let path = (authDir as NSString).appendingPathComponent(file)
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                      var json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { continue }

                if var metadata = json["metadata"] as? [String: Any] {
                    metadata.removeValue(forKey: "base_url")
                    json["metadata"] = metadata

                    if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                        try? newData.write(to: URL(fileURLWithPath: path))
                    }
                }
            }
        }

        restartProxyIfRunning()
    }

    private func ensureConfigExists() {
        guard !FileManager.default.fileExists(atPath: configPath) else { return }

        let defaultConfig = """
        host: "\(allowNetworkAccess ? "0.0.0.0" : "127.0.0.1")"
        port: \(proxyStatus.port)
        auth-dir: "\(authDir)"
        proxy-url: ""

        api-keys:
          - "edx-local-\(UUID().uuidString)"

        remote-management:
          allow-remote: false
          secret-key: "\(managementKey)"

        debug: false
        logging-to-file: false
        usage-statistics-enabled: true

        routing:
          strategy: "round-robin"

        quota-exceeded:
          switch-project: true
          switch-preview-model: true

        request-retry: 3
        max-retry-interval: 30
        """

        try? defaultConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    private struct LaunchConfiguration {
        let path: String
        let userPort: UInt16
        let cliProxyPort: UInt16
        let bridgeEnabled: Bool
    }

    private func prepareLaunchConfiguration() throws -> LaunchConfiguration {
        let content: String
        do {
            content = try String(contentsOfFile: configPath, encoding: .utf8)
        } catch {
            throw ProxyError.configurationError("Failed to read local config: \(error.localizedDescription)")
        }

        return launchConfiguration(from: content)
    }

    private func launchConfiguration(from content: String) -> LaunchConfiguration {
        let userPort = Self.extractTopLevelPort(from: content) ?? proxyStatus.port
        let launchKey = resolveManagementKey(from: content)

        managementKey = launchKey
        updateProxyStatus(running: proxyStatus.running, port: userPort)
        activeUserPort = userPort
        activeCLIProxyPort = userPort

        return LaunchConfiguration(
            path: configPath,
            userPort: userPort,
            cliProxyPort: userPort,
            bridgeEnabled: false
        )
    }

    @discardableResult
    func reconcileRunningStateWithSystem() async -> Bool {
        guard FileManager.default.fileExists(atPath: configPath),
              let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            updateProxyStatus(running: false)
            return false
        }

        let launchConfig = launchConfiguration(from: content)
        let isProcessRunning = await isCLIProxyProcessRunning(userPort: launchConfig.userPort, cliProxyPort: launchConfig.cliProxyPort)

        applyReconciledRunningState(isProcessRunning, userPort: launchConfig.userPort)
        return isProcessRunning
    }

    @discardableResult
    func reconcileRunningStateSnapshotWithSystem() -> Bool {
        guard FileManager.default.fileExists(atPath: configPath),
              let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            updateProxyStatus(running: false)
            return false
        }

        let launchConfig = launchConfiguration(from: content)
        let isProcessRunning = isCLIProxyProcessRunningSnapshot(
            userPort: launchConfig.userPort,
            cliProxyPort: launchConfig.cliProxyPort
        )
        applyReconciledRunningState(isProcessRunning, userPort: launchConfig.userPort)
        return isProcessRunning
    }

    private func applyReconciledRunningState(_ isRunning: Bool, userPort: UInt16) {
        updateProxyStatus(running: isRunning, port: userPort)
        managerState = isRunning ? .active : .idle

        if isRunning {
            startHealthMonitor()
        } else {
            stopHealthMonitor()
            process = nil
            activeUserPort = nil
            activeCLIProxyPort = nil
        }
    }

    private func isCLIProxyProcessRunning(userPort: UInt16, cliProxyPort: UInt16) async -> Bool {
        if let process, process.isRunning {
            return true
        }

        return await Task.detached(priority: .utility) {
            Self.hasCLIProxyProcess(userPort: userPort, cliProxyPort: cliProxyPort)
        }.value
    }

    private func isCLIProxyProcessRunningSnapshot(userPort: UInt16, cliProxyPort: UInt16) -> Bool {
        if let process, process.isRunning {
            return true
        }
        return Self.hasCLIProxyProcess(userPort: userPort, cliProxyPort: cliProxyPort)
    }

    nonisolated private static func hasCLIProxyProcess(userPort: UInt16, cliProxyPort: UInt16) -> Bool {
        if Self.portHasCLIProxyProcess(cliProxyPort) {
            return true
        }
        guard userPort != cliProxyPort else { return false }
        return Self.portHasCLIProxyProcess(userPort)
    }

    nonisolated private static func portHasCLIProxyProcess(_ port: UInt16) -> Bool {
        let lsofProcess = Process()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProcess.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "cn"]

        let pipe = Pipe()
        lsofProcess.standardOutput = pipe
        lsofProcess.standardError = FileHandle.nullDevice

        do {
            try lsofProcess.run()
            lsofProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return false
            }

            return output.components(separatedBy: .newlines).contains { line in
                guard line.hasPrefix("c") else { return false }
                let commandName = String(line.dropFirst()).lowercased()
                return cliProxyProcessNames.contains(commandName)
            }
        } catch {
            return false
        }
    }

    nonisolated private static func extractTopLevelPort(from content: String) -> UInt16? {
        let pattern = #"(?m)^port:\s*(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..<content.endIndex, in: content)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: content),
              let port = UInt16(String(content[range])),
              port > 0 else {
            return nil
        }
        return port
    }

    nonisolated private static func extractTopLevelHost(from content: String) -> String? {
        let pattern = #"(?m)^host:\s*([^\n]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..<content.endIndex, in: content)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        return Self.unquoteYAMLScalar(String(content[range]))
    }

    private func resolveManagementKey(from content: String) -> String {
        guard let configKey = extractManagementKey(from: content),
              isPlaintextManagementKey(configKey) else {
            return managementKey
        }

        if configKey != managementKey,
           !KeychainHelper.saveLocalManagementKey(configKey) {
            Log.keychain("Failed to persist local management key from config")
        }

        return configKey
    }

    private func extractManagementKey(from content: String) -> String? {
        var isInRemoteManagement = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "remote-management:" {
                isInRemoteManagement = true
                continue
            }

            guard isInRemoteManagement else { continue }

            if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                return nil
            }

            guard trimmed.hasPrefix("secret-key:") else { continue }
            let rawValue = String(trimmed.dropFirst("secret-key:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.unquoteYAMLScalar(rawValue)
        }

        return nil
    }

    private func isPlaintextManagementKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !trimmed.hasPrefix("$2a$")
            && !trimmed.hasPrefix("$2b$")
            && !trimmed.hasPrefix("$2y$")
    }

    nonisolated private static func unquoteYAMLScalar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              trimmed.first == "\"",
              trimmed.last == "\"" else {
            return trimmed
        }

        let inner = trimmed.dropFirst().dropLast()
        return inner
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private func quoteYAMLScalar(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    nonisolated private static func extractTopLevelString(_ key: String, from content: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "(?m)^\(escapedKey):\\s*([^\\n]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..<content.endIndex, in: content)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        return unquoteYAMLScalar(String(content[range]))
    }

    nonisolated private static func extractTopLevelBool(_ key: String, from content: String) -> Bool? {
        guard let value = extractTopLevelString(key, from: content)?.lowercased() else { return nil }
        if value == "true" { return true }
        if value == "false" { return false }
        return nil
    }

    nonisolated private static func extractTopLevelInt(_ key: String, from content: String) -> Int? {
        guard let value = extractTopLevelString(key, from: content) else { return nil }
        return Int(value)
    }

    nonisolated private static func extractNestedString(section: String, key: String, from content: String) -> String? {
        var isInSection = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "\(section):" {
                isInSection = true
                continue
            }

            guard isInSection else { continue }

            if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                return nil
            }

            guard trimmed.hasPrefix("\(key):") else { continue }
            let rawValue = String(trimmed.dropFirst("\(key):".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return unquoteYAMLScalar(rawValue)
        }

        return nil
    }

    nonisolated private static func extractNestedBool(section: String, key: String, from content: String) -> Bool? {
        guard let value = extractNestedString(section: section, key: key, from: content)?.lowercased() else { return nil }
        if value == "true" { return true }
        if value == "false" { return false }
        return nil
    }

    nonisolated private static func replaceOrAppendTopLevelValue(key: String, value: String, in content: String) -> String {
        let replacement = "\(key): \(value)"
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "(?m)^\(escapedKey):\\s*[^\\n]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Self.appendLine(replacement, to: content)
        }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        if regex.firstMatch(in: content, range: range) != nil {
            return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
        }

        return Self.appendLine(replacement, to: content)
    }

    nonisolated private static func replaceOrAppendNestedValue(section: String, key: String, value: String, in content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        let replacement = "  \(key): \(value)"

        if let sectionIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "\(section):" }) {
            var insertIndex = sectionIndex + 1

            while insertIndex < lines.count {
                let line = lines[insertIndex]
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                    break
                }

                if trimmed.hasPrefix("\(key):") {
                    let prefix = String(line.prefix { $0 == " " || $0 == "\t" })
                    lines[insertIndex] = "\(prefix)\(key): \(value)"
                    return lines.joined(separator: "\n")
                }

                insertIndex += 1
            }

            lines.insert(replacement, at: insertIndex)
            return lines.joined(separator: "\n")
        }

        return Self.appendLine("\(section):\n\(replacement)", to: content)
    }

    private func replaceOrAppendTopLevelPort(_ port: UInt16, in content: String) -> String {
        let replacement = "port: \(port)"
        let pattern = #"(?m)^port:\s*[^\n]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Self.appendLine(replacement, to: content)
        }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        if regex.firstMatch(in: content, range: range) != nil {
            return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
        }

        return Self.appendLine(replacement, to: content)
    }

    private func replaceOrAppendManagementKey(_ key: String, in content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        let replacement = "  secret-key: \(quoteYAMLScalar(key))"

        if let remoteIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "remote-management:" }) {
            var insertIndex = remoteIndex + 1

            while insertIndex < lines.count {
                let line = lines[insertIndex]
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                    break
                }

                if trimmed.hasPrefix("secret-key:") {
                    let prefix = String(line.prefix { $0 == " " || $0 == "\t" })
                    lines[insertIndex] = "\(prefix)secret-key: \(quoteYAMLScalar(key))"
                    return lines.joined(separator: "\n")
                }

                insertIndex += 1
            }

            lines.insert(replacement, at: insertIndex)
            return lines.joined(separator: "\n")
        }

        return Self.appendLine("remote-management:\n\(replacement)", to: content)
    }

    nonisolated private static func appendLine(_ line: String, to content: String) -> String {
        let separator = content.hasSuffix("\n") ? "" : "\n"
        return "\(content)\(separator)\(line)\n"
    }

    private func prepareAuthCommandConfig() throws -> String {
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw ProxyError.configurationError("Local config does not exist")
        }

        return configPath
    }

    private func syncSecretKeyInConfig() {
        guard FileManager.default.fileExists(atPath: configPath),
              var content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        
        if let range = content.range(of: #"secret-key:\s*\".*\""#, options: .regularExpression) {
            content.replaceSubrange(range, with: "secret-key: \"\(managementKey)\"")
            try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
        } else if let range = content.range(of: #"secret-key:\s*[^\n]+"#, options: .regularExpression) {
            content.replaceSubrange(range, with: "secret-key: \"\(managementKey)\"")
            try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
        }
    }
    
    /// Regenerates the management key with staged persistence and rollback on failure.
    /// - Throws: `ProxyError` if proxy restart fails
    func regenerateManagementKey() async throws {
        guard !isRegeneratingKey else {
            throw ProxyError.operationInProgress
        }
        
        isRegeneratingKey = true
        defer { isRegeneratingKey = false }
        
        let previousKey = managementKey
        let newKey = UUID().uuidString
        managementKey = newKey
        syncSecretKeyInConfig()
        
        guard proxyStatus.running else {
            if !KeychainHelper.saveLocalManagementKey(newKey) {
                Log.keychain("Failed to persist regenerated management key while stopped")
            }
            return
        }
        
        do {
            stop()
            try await Task.sleep(for: .milliseconds(500))
            try await start()
            if !KeychainHelper.saveLocalManagementKey(newKey) {
                Log.keychain("Failed to persist regenerated management key after restart")
            }
        } catch {
            managementKey = previousKey
            syncSecretKeyInConfig()
            try? await Task.sleep(for: .milliseconds(300))
            try? await start()
            throw error
        }
    }

    var isBinaryInstalled: Bool {
        isSourceInstalled(selectedBinarySource)
    }
    
    func downloadAndInstallBinary() async throws {
        lastError = nil

        do {
            let versionInfo: ProxyVersionInfo
            switch selectedBinarySource {
            case .plusLocal:
                guard let localInfo = plusLocalVersionInfo() else {
                    throw ProxyError.noCompatibleBinary
                }
                versionInfo = localInfo
            case .upstream:
                let releaseInfo = try await fetchLatestRelease(source: .upstream)
                let latestTag = releaseInfo.tagName.hasPrefix("v")
                    ? String(releaseInfo.tagName.dropFirst())
                    : releaseInfo.tagName
                let release = try await fetchGitHubRelease(tag: "v\(latestTag)", source: .upstream)
                guard let asset = findCompatibleAsset(from: release),
                      let upstreamInfo = ProxyVersionInfo(from: release, asset: asset, source: .upstream) else {
                    throw ProxyError.noCompatibleBinary
                }
                versionInfo = upstreamInfo
            }

            try await performManagedUpgrade(to: versionInfo)
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    private struct ReleaseInfo: Codable {
        let tagName: String
        let assets: [AssetInfo]
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }
    
    private struct AssetInfo: Codable {
        let name: String
        let browserDownloadUrl: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
        
        var downloadURL: String { browserDownloadUrl }
    }
    
    private struct CompatibleAsset {
        let name: String
        let downloadURL: String
    }
    
    private func fetchLatestRelease(source: ProxyBinarySource) async throws -> ReleaseInfo {
        guard let githubRepo = source.githubRepo else {
            throw ProxyError.networkError("Selected source does not provide online releases")
        }

        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw ProxyError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("Edx/1.0", forHTTPHeaderField: "User-Agent")

        let config = ProxyConfigurationService.createProxiedConfigurationStatic(timeout: 30)
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProxyError.networkError("Failed to fetch release info")
        }

        return try JSONDecoder().decode(ReleaseInfo.self, from: data)
    }
    
    private func findCompatibleAsset(in release: ReleaseInfo) -> CompatibleAsset? {
        #if arch(arm64)
        let targetPatterns = ["darwin_arm64", "darwin_aarch64"]
        #else
        let targetPatterns = ["darwin_amd64"]
        #endif
        let skipPatterns = ["windows", "linux", "checksum"]
        
        for asset in release.assets {
            let lowercaseName = asset.name.lowercased()
            
            let shouldSkip = skipPatterns.contains { lowercaseName.contains($0) }
            if shouldSkip { continue }
            
            if targetPatterns.contains(where: { lowercaseName.contains($0) }) {
                return CompatibleAsset(name: asset.name, downloadURL: asset.browserDownloadUrl)
            }
        }
        
        return nil
    }
    
    private func downloadAsset(url: String) async throws -> Data {
        guard let downloadURL = URL(string: url) else {
            throw ProxyError.networkError("Invalid download URL")
        }

        var request = URLRequest(url: downloadURL)
        request.addValue("Edx/1.0", forHTTPHeaderField: "User-Agent")

        let config = ProxyConfigurationService.createProxiedConfigurationStatic(timeout: 300) // 5 minutes timeout for large downloads
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProxyError.networkError("Failed to download binary")
        }

        return data
    }
    
    private func extractAndInstall(data: Data, assetName: String) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let downloadedFile = tempDir.appendingPathComponent(assetName)
        try data.write(to: downloadedFile)
        
        let binaryURL = URL(fileURLWithPath: binaryPath)
        
        if assetName.hasSuffix(".tar.gz") || assetName.hasSuffix(".tgz") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzf", downloadedFile.path, "-C", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            if let binary = try findBinaryInDirectory(tempDir) {
                if FileManager.default.fileExists(atPath: binaryPath) {
                    try FileManager.default.removeItem(atPath: binaryPath)
                }
                try FileManager.default.copyItem(at: binary, to: binaryURL)
            } else {
                throw ProxyError.extractionFailed
            }
            
        } else if assetName.hasSuffix(".zip") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", downloadedFile.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            if let binary = try findBinaryInDirectory(tempDir) {
                if FileManager.default.fileExists(atPath: binaryPath) {
                    try FileManager.default.removeItem(atPath: binaryPath)
                }
                try FileManager.default.copyItem(at: binary, to: binaryURL)
            } else {
                throw ProxyError.extractionFailed
            }
            
        } else {
            if FileManager.default.fileExists(atPath: binaryPath) {
                try FileManager.default.removeItem(atPath: binaryPath)
            }
            try FileManager.default.copyItem(at: downloadedFile, to: binaryURL)
        }
        
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryPath)
        
        // Ad-hoc sign the binary to allow execution on macOS
        let signProcess = Process()
        signProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signProcess.arguments = ["-f", "-s", "-", binaryPath]
        try? signProcess.run()
        signProcess.waitUntilExit()
    }
    
    private func findBinaryInDirectory(_ directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isExecutableKey, .isRegularFileKey])
        
        let binaryNames = ["CLIProxyAPI", "cli-proxy-api", "cli-proxy-api-plus", "claude-code-proxy", "proxy"]
        
        for name in binaryNames {
            if let found = contents.first(where: { $0.lastPathComponent.lowercased() == name.lowercased() }) {
                return found
            }
        }
        
        for item in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if let found = try findBinaryInDirectory(item) {
                        return found
                    }
                } else {
                    let resourceValues = try item.resourceValues(forKeys: [.isExecutableKey])
                    if resourceValues.isExecutable == true {
                        let name = item.lastPathComponent.lowercased()
                        if !name.hasSuffix(".sh") && !name.hasSuffix(".txt") && !name.hasSuffix(".md") {
                            return item
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    func start(resetCrashRecoveryState: Bool = true) async throws {
        guard isBinaryInstalled else {
            throw ProxyError.binaryNotFound
        }
        
        guard !proxyStatus.running else { return }

        if resetCrashRecoveryState {
            cancelCrashRestart()
            crashRestartAttempts = 0
        }
        
        isStarting = true
        lastError = nil
        
        defer { isStarting = false }
        
        let launchConfig = try prepareLaunchConfiguration()

        // Clean up any orphan processes from previous runs after resolving the config-owned ports.
        await cleanupOrphanProcesses()

        // Use effectiveBinaryPath to support versioned storage
        let activeBinaryPath = effectiveBinaryPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: activeBinaryPath)
        process.arguments = ["-config", launchConfig.path]
        process.currentDirectoryURL = URL(fileURLWithPath: activeBinaryPath).deletingLastPathComponent()
        
        // CRITICAL FIX: Drain stdout/stderr to prevent pipe buffer deadlock
        // macOS pipe buffer is ~64KB. If CLIProxyAPI writes more without being read,
        // the process blocks on write and becomes unresponsive (port open but no response).
        // Solution: Use readabilityHandler to continuously drain the buffers.
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Drain stdout buffer to prevent blocking
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            // Discard data to prevent memory accumulation
            // If debug logging needed: NSLog("[CLIProxyAPI] \(String(data: data, encoding: .utf8) ?? "")")
            _ = data.count
        }
        
        // Drain stderr buffer to prevent blocking
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            // Discard data - errors are typically reported via exit code
            _ = data.count
        }
        
        // Important: Don't inherit environment that might cause issues
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        process.environment = environment
        
        let bridgeEnabled = launchConfig.bridgeEnabled
        let userPort = launchConfig.userPort
        let cliProxyPort = launchConfig.cliProxyPort
        
        process.terminationHandler = { terminatedProcess in
            let status = terminatedProcess.terminationStatus
            let pid = terminatedProcess.processIdentifier
            
            // Clear readability handlers to release closures and prevent resource leaks
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            // Close file handles to release resources
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let wasExpected = self.expectedTerminationPIDs.remove(pid) != nil

                guard self.process?.processIdentifier == pid else {
                    return
                }

                // Stop ProxyBridge if CLIProxyAPI exits
                if bridgeEnabled {
                    self.proxyBridge.stop()
                }

                self.updateProxyStatus(running: false)
                self.process = nil
                self.activeUserPort = nil
                self.activeCLIProxyPort = nil

                if !wasExpected && !self.isStarting {
                    self.lastError = "Process exited with code: \(status)"
                    if status != 0 {
                        NotificationManager.shared.notifyProxyCrashed(exitCode: status)
                    }
                    self.scheduleCrashRestart(exitCode: status)
                }
            }
        }
        
        do {
            try process.run()
            self.process = process
            
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            guard process.isRunning else {
                throw ProxyError.startupFailed
            }
            
            // If bridge mode is enabled, start ProxyBridge
            if bridgeEnabled {
                proxyBridge.configure(listenPort: userPort, targetPort: cliProxyPort)
                proxyBridge.start()
                
                // Wait a bit for ProxyBridge to start
                try await Task.sleep(nanoseconds: 500_000_000)
                
                guard proxyBridge.isRunning else {
                    // ProxyBridge failed to start, stop CLIProxyAPI
                    markExpectedTermination(process)
                    process.terminate()
                    throw ProxyError.startupFailed
                }
                
                NSLog("[CLIProxyManager] Two-layer proxy started: clients → \(userPort) → \(cliProxyPort)")
            } else {
                NSLog("[CLIProxyManager] Direct proxy started on port \(userPort)")
            }
            
            updateProxyStatus(running: true, port: userPort)
            managerState = .active

            startHealthMonitor()
            
        } catch {
            lastError = error.localizedDescription
            activeUserPort = nil
            activeCLIProxyPort = nil
            throw error
        }
    }

    func stop() {
        terminateAuthProcess()
        stopHealthMonitor()
        cancelCrashRestart()
        
        // Stop ProxyBridge first if running
        if proxyBridge.isRunning {
            proxyBridge.stop()
        }
        
        // Run blocking operations in background to avoid freezing MainActor.
        //
        // Trade-off note: If start() is called immediately after stop(), there is a small
        // window where the detached task could kill the newly started process (since
        // killProcessOnPortSync kills by PORT, not PID). This is an acceptable trade-off
        // because UI responsiveness is more important than this rare edge case.
        // A 150ms buffer is added below to reduce (but not eliminate) this race window.
        let currentProcess = process
        let userPort = activeUserPort ?? proxyStatus.port
        let intPort = activeCLIProxyPort ?? internalPort
        let shouldCleanInternalPort = activeCLIProxyPort != nil && intPort != userPort
        markExpectedTermination(currentProcess)

        Task.detached(priority: .userInitiated) {
            // Force terminate the main proxy process
            if let proc = currentProcess, proc.isRunning {
                let pid = proc.processIdentifier
                proc.terminate()
                
                let deadline = Date().addingTimeInterval(2.0)
                while proc.isRunning && Date() < deadline {
                    usleep(100_000)  // 100ms, avoid Thread.sleep in async context
                }
                
                if proc.isRunning {
                    kill(pid, SIGKILL)
                }
            }
            
            // Kill processes on both ports
            Self.killProcessOnPortSync(userPort)
            if shouldCleanInternalPort {
                Self.killProcessOnPortSync(intPort)
            }
        }

        process = nil
        updateProxyStatus(running: false)
        if managerState == .active {
            managerState = .idle
        }
        activeUserPort = nil
        activeCLIProxyPort = nil
    }

    /// Stop the proxy and wait for process/port cleanup to complete.
    /// Used by recovery paths that immediately restart, so the detached cleanup in stop()
    /// cannot race with and kill the newly started process by port.
    func stopAndWait() async {
        terminateAuthProcess()
        stopHealthMonitor()
        cancelCrashRestart()

        if proxyBridge.isRunning {
            proxyBridge.stop()
        }

        let currentProcess = process
        let userPort = activeUserPort ?? proxyStatus.port
        let intPort = activeCLIProxyPort ?? internalPort
        let shouldCleanInternalPort = activeCLIProxyPort != nil && intPort != userPort
        markExpectedTermination(currentProcess)

        process = nil
        updateProxyStatus(running: false)
        if managerState == .active {
            managerState = .idle
        }
        activeUserPort = nil
        activeCLIProxyPort = nil

        await Task.detached(priority: .userInitiated) {
            if let proc = currentProcess, proc.isRunning {
                let pid = proc.processIdentifier
                proc.terminate()

                let deadline = Date().addingTimeInterval(2.0)
                while proc.isRunning && Date() < deadline {
                    usleep(100_000)
                }

                if proc.isRunning {
                    kill(pid, SIGKILL)
                }
            }

            Self.killProcessOnPortSync(userPort)
            if shouldCleanInternalPort {
                Self.killProcessOnPortSync(intPort)
            }
        }.value
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // MARK: - Health Monitoring
    // ════════════════════════════════════════════════════════════════════════
    
    private func startHealthMonitor() {
        stopHealthMonitor()
        healthCheckFailures = 0
        
        healthMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: (self?.healthCheckIntervalSeconds ?? 30) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                
                await self?.performHealthCheck()
            }
        }
    }
    
    private func stopHealthMonitor() {
        healthMonitorTask?.cancel()
        healthMonitorTask = nil
    }

    private func markExpectedTermination(_ process: Process?) {
        guard let process else { return }
        expectedTerminationPIDs.insert(process.processIdentifier)
    }

    private func cancelCrashRestart() {
        crashRestartTask?.cancel()
        crashRestartTask = nil
    }

    private func scheduleCrashRestart(exitCode: Int32) {
        guard crashRestartTask == nil else { return }

        switch managerState {
        case .testing, .promoting, .rollingBack:
            return
        case .idle, .active:
            break
        }

        guard crashRestartAttempts < maxCrashRestartAttempts else {
            NSLog("[CLIProxyManager] Max crash restart attempts reached after exit code \(exitCode)")
            return
        }

        crashRestartAttempts += 1
        let attempt = crashRestartAttempts
        let multiplier = UInt64(1 << max(0, attempt - 1))
        let delay = min(crashRestartBaseDelaySeconds * multiplier, maxCrashRestartDelaySeconds)

        NSLog("[CLIProxyManager] Scheduling proxy restart in \(delay)s after unexpected exit code \(exitCode) (attempt \(attempt)/\(maxCrashRestartAttempts))")

        crashRestartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }

            self.crashRestartTask = nil

            guard !self.proxyStatus.running else { return }

            switch self.managerState {
            case .testing, .promoting, .rollingBack:
                return
            case .idle, .active:
                break
            }

            do {
                try await self.start(resetCrashRecoveryState: false)
                NSLog("[CLIProxyManager] Crash auto-restart successful")
            } catch {
                self.lastError = "Auto-restart failed: \(error.localizedDescription)"
                NSLog("[CLIProxyManager] Crash auto-restart failed: \(error)")
                self.scheduleCrashRestart(exitCode: -1)
            }
        }
    }
    
    private func performHealthCheck() async {
        // Bail out if proxy is not running or manager is in upgrade flow
        guard proxyStatus.running else {
            healthCheckFailures = 0
            return
        }
        
        // Skip health check during managed upgrades to avoid racing with upgrade flow
        switch managerState {
        case .testing, .promoting, .rollingBack:
            NSLog("[CLIProxyManager] Skipping health check during \(managerState) state")
            return
        case .idle, .active:
            break
        }
        
        let isHealthy = await compatibilityChecker.isHealthy(
            port: activeCLIProxyPort ?? (useBridgeMode ? internalPort : proxyStatus.port),
            managementKey: managementKey
        )
        
        // Re-check state after await - proxy may have been stopped or upgrade may have started
        guard proxyStatus.running else {
            healthCheckFailures = 0
            return
        }
        
        switch managerState {
        case .testing, .promoting, .rollingBack:
            NSLog("[CLIProxyManager] Aborting health check action - manager entered \(managerState) state")
            return
        case .idle, .active:
            break
        }
        
        if isHealthy {
            healthCheckFailures = 0
            crashRestartAttempts = 0
        } else {
            healthCheckFailures += 1
            NSLog("[CLIProxyManager] Health check failed (\(healthCheckFailures)/\(maxHealthCheckFailures))")
            
            if healthCheckFailures >= maxHealthCheckFailures {
                NSLog("[CLIProxyManager] Max failures reached, auto-restarting proxy...")
                healthCheckFailures = 0
                
                stop()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                do {
                    try await start()
                    NSLog("[CLIProxyManager] Auto-restart successful")
                } catch {
                    NSLog("[CLIProxyManager] Auto-restart failed: \(error)")
                    NotificationManager.shared.notifyProxyCrashed(exitCode: -1)
                }
            }
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // MARK: - Process Cleanup
    // ════════════════════════════════════════════════════════════════════════
    
    /// Clean up any orphan proxy processes from previous runs.
    /// Executes blocking operations on background thread to avoid blocking MainActor.
    private func cleanupOrphanProcesses() async {
        let userPort = activeUserPort ?? proxyStatus.port
        let intPort = activeCLIProxyPort ?? internalPort
        let shouldCleanInternalPort = activeCLIProxyPort != nil && intPort != userPort
        
        // Execute blocking operations on background thread
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task.detached(priority: .userInitiated) {
                // Kill any process on the user-facing port
                Self.killProcessOnPortSync(userPort)
                
                // Only kill the internal port when the active launch config uses a separate port.
                if shouldCleanInternalPort {
                    Self.killProcessOnPortSync(intPort)
                    NSLog("[CLIProxyManager] Cleaned up orphan processes on ports \(userPort) and \(intPort)")
                } else {
                    NSLog("[CLIProxyManager] Cleaned up orphan processes on port \(userPort)")
                }
                
                // Small delay to ensure ports are released
                usleep(200_000)  // 200ms, avoid Thread.sleep in async context
                continuation.resume()
            }
        }
    }
    
    /// Synchronous port cleanup for use in detached tasks.
    /// This method is `nonisolated` to allow calling from background threads.
    /// IMPORTANT: Excludes own PID to prevent killing Edx itself when ProxyBridge is running.
    nonisolated private static func killProcessOnPortSync(_ port: UInt16) {
        let lsofProcess = Process()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProcess.arguments = ["-ti", "tcp:\(port)"]

        let pipe = Pipe()
        lsofProcess.standardOutput = pipe
        lsofProcess.standardError = FileHandle.nullDevice

        // Get own PID to avoid killing ourselves (ProxyBridge runs in our process)
        let ownPid = ProcessInfo.processInfo.processIdentifier

        do {
            try lsofProcess.run()
            lsofProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return }

            for pidString in output.components(separatedBy: .newlines) {
                if let pid = Int32(pidString.trimmingCharacters(in: .whitespaces)) {
                    // Never kill our own process - ProxyBridge uses NWListener in-process
                    if pid == ownPid {
                        NSLog("[CLIProxyManager] Skipping kill of own PID \(pid) on port \(port)")
                        continue
                    }
                    kill(pid, SIGKILL)
                }
            }
        } catch {
            // Silent failure - process may not exist
        }
    }
    
    func terminateAuthProcess() {
        guard let authProcess = authProcess, authProcess.isRunning else {
            return
        }
        authProcess.terminate()
        self.authProcess = nil
    }
    
    func toggle() async throws {
        if proxyStatus.running {
            stop()
        } else {
            try await start()
        }
    }
    
    func copyEndpointToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(proxyStatus.endpoint, forType: .string)
    }
    
    func revealInFinder() {
        let path = effectiveBinaryPath
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }
}

enum ProxyError: LocalizedError {
    case binaryNotFound
    case startupFailed
    case operationInProgress
    case networkError(String)
    case noCompatibleBinary
    case extractionFailed
    case downloadFailed
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            let rawSource = UserDefaults.standard.string(forKey: ProxyBinarySource.userDefaultsKey)
            let source = ProxyBinarySource(rawValue: rawSource ?? "") ?? .upstream
            return source.installHint
        case .startupFailed:
            return "Failed to start proxy server."
        case .operationInProgress:
            return "Another operation is already in progress. Please wait."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .noCompatibleBinary:
            return "No compatible binary found for your system."
        case .extractionFailed:
            return "Failed to extract binary from archive."
        case .downloadFailed:
            return "Failed to download binary."
        case .configurationError(let msg):
            return "Configuration error: \(msg)"
        }
    }
}

// MARK: - CLI Auth Commands

enum AuthCommand: Equatable {
    case copilotLogin
    case kiroGoogleLogin
    case kiroAWSLogin
    case kiroAWSAuthCode
    case kiroImport
    
    var arguments: [String] {
        switch self {
        case .copilotLogin:
            return ["-github-copilot-login"]
        case .kiroGoogleLogin:
            return ["-kiro-google-login"]
        case .kiroAWSLogin:
            return ["-kiro-aws-login"]
        case .kiroAWSAuthCode:
            return ["-kiro-aws-authcode"]
        case .kiroImport:
            return ["-kiro-import"]
        }
    }
    
    var displayName: String {
        switch self {
        case .copilotLogin:
            return "GitHub Device Code"
        case .kiroGoogleLogin:
            return "Google OAuth"
        case .kiroAWSLogin:
            return "AWS Builder ID (Device Code)"
        case .kiroAWSAuthCode:
            return "AWS Builder ID (Browser)"
        case .kiroImport:
            return "Import from Kiro IDE"
        }
    }
}

struct AuthCommandResult {
    let success: Bool
    let message: String
    let deviceCode: String?
}

extension CLIProxyManager {
    
    func runAuthCommand(_ command: AuthCommand) async -> AuthCommandResult {
        terminateAuthProcess()
        
        guard isBinaryInstalled else {
            return AuthCommandResult(success: false, message: "CLIProxyAPI binary not found", deviceCode: nil)
        }
        
        return await withCheckedContinuation { continuation in
            let configPath: String
            do {
                configPath = try prepareAuthCommandConfig()
            } catch {
                continuation.resume(returning: AuthCommandResult(
                    success: false,
                    message: "Failed to prepare config: \(error.localizedDescription)",
                    deviceCode: nil
                ))
                return
            }

            let newAuthProcess = Process()
            newAuthProcess.executableURL = URL(fileURLWithPath: effectiveBinaryPath)
            newAuthProcess.arguments = ["-config", configPath] + command.arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            newAuthProcess.standardOutput = outputPipe
            newAuthProcess.standardError = errorPipe
            
            var environment = ProcessInfo.processInfo.environment
            environment["TERM"] = "xterm-256color"
            newAuthProcess.environment = environment
            
            // Thread-safe state container for concurrent access
            final class AuthState: @unchecked Sendable {
                private let lock = NSLock()
                private var _capturedOutput = ""
                private var _hasResumed = false
                
                var capturedOutput: String {
                    get { lock.withLock { _capturedOutput } }
                    set { lock.withLock { _capturedOutput = newValue } }
                }
                
                func appendOutput(_ str: String) {
                    lock.withLock { _capturedOutput += str }
                }
                
                func tryResume() -> Bool {
                    lock.withLock {
                        if _hasResumed { return false }
                        _hasResumed = true
                        return true
                    }
                }
            }
            
            let state = AuthState()
            
            @Sendable func safeResume(_ result: AuthCommandResult) {
                guard state.tryResume() else { return }
                continuation.resume(returning: result)
            }
            
            if case .copilotLogin = command {
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                        state.appendOutput(str)
                    }
                }
            }
            
            newAuthProcess.terminationHandler = { [weak self] terminatedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil

                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    self.authProcess = nil
                }

                let status = terminatedProcess.terminationStatus
                if status == 0 {
                    safeResume(AuthCommandResult(
                        success: true,
                        message: "Authentication completed successfully.",
                        deviceCode: nil
                    ))
                }
            }
            
            do {
                try newAuthProcess.run()
                
                Task { @MainActor in
                    self.authProcess = newAuthProcess
                }
                
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) {
                    guard newAuthProcess.isRunning else { return }
                    
                    if case .copilotLogin = command {
                        if let code = self.extractDeviceCode(from: state.capturedOutput) {
                            DispatchQueue.main.async {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(code, forType: .string)
                            }
                            
                            safeResume(AuthCommandResult(
                                success: true,
                                message: "🌐 Browser opened for GitHub authentication.\n\n📋 Code copied to clipboard:\n\n\(code)\n\nJust paste it in the browser!",
                                deviceCode: code
                            ))
                        } else {
                            safeResume(AuthCommandResult(
                                success: true,
                                message: "🌐 Browser opened for GitHub authentication.\n\nCheck your browser for the device code.",
                                deviceCode: nil
                            ))
                        }
                    } else {
                        safeResume(AuthCommandResult(
                            success: true,
                            message: "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.",
                            deviceCode: nil
                        ))
                    }
                }
            } catch {
                safeResume(AuthCommandResult(
                    success: false,
                    message: "Failed to start auth process: \(error.localizedDescription)",
                    deviceCode: nil
                ))
            }
        }
    }
    
    private nonisolated func extractDeviceCode(from output: String) -> String? {
        if let codeRange = output.range(of: "enter the code: "),
           let endRange = output[codeRange.upperBound...].range(of: "\n") {
            return String(output[codeRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("enter the code:") {
                let parts = line.components(separatedBy: "enter the code:")
                if parts.count > 1 {
                    return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
}

// MARK: - Managed Proxy Upgrade

extension CLIProxyManager {
    var selectedBinarySource: ProxyBinarySource {
        get {
            let rawValue = UserDefaults.standard.string(forKey: ProxyBinarySource.userDefaultsKey)
            return ProxyBinarySource(rawValue: rawValue ?? "") ?? defaultBinarySource()
        }
        set {
            let previousSource = selectedBinarySource
            guard previousSource != newValue else { return }

            UserDefaults.standard.set(newValue.rawValue, forKey: ProxyBinarySource.userDefaultsKey)
            UserDefaults.standard.set(true, forKey: ProxyBinarySource.explicitSelectionDefaultsKey)
            upgradeAvailable = false
            availableUpgrade = nil
            lastError = nil

            if proxyStatus.running {
                restartProxyIfRunning()
            }
        }
    }

    var availableBinarySources: [ProxyBinarySource] {
        ProxyBinarySource.allCases
    }

    var shouldPromptForBinarySourceSelection: Bool {
        !UserDefaults.standard.bool(forKey: ProxyBinarySource.explicitSelectionDefaultsKey)
    }

    var selectedBinarySourceWarning: String? {
        selectedBinarySource.legacyAuthWarning
    }

    func isLegacyAuthWarningNeeded(for provider: AIProvider) -> Bool {
        guard selectedBinarySource == .upstream else { return false }
        return provider == .copilot || provider == .kiro
    }

    func sourceInstallHint(for source: ProxyBinarySource? = nil) -> String {
        (source ?? selectedBinarySource).installHint
    }

    func confirmBinarySourceSelection(_ source: ProxyBinarySource) {
        let previousSource = selectedBinarySource
        UserDefaults.standard.set(true, forKey: ProxyBinarySource.explicitSelectionDefaultsKey)
        if previousSource != source {
            selectedBinarySource = source
        } else {
            UserDefaults.standard.set(source.rawValue, forKey: ProxyBinarySource.userDefaultsKey)
        }
    }

    func isSourceInstalled(_ source: ProxyBinarySource) -> Bool {
        if storageManager.hasInstalledVersion(for: source) {
            return true
        }

        if source == .plusLocal {
            return FileManager.default.fileExists(atPath: binaryPath)
        }

        return false
    }
    
    /// The effective binary path - uses versioned storage if available, otherwise legacy path.
    var effectiveBinaryPath: String {
        if let path = storageManager.currentBinaryPath(for: selectedBinarySource) {
            return path
        }
        if selectedBinarySource == .plusLocal {
            return binaryPath
        }
        return storageManager.expectedBinaryPath(for: selectedBinarySource)
    }
    
    /// Check if versioned storage is being used.
    var isUsingVersionedStorage: Bool {
        storageManager.hasInstalledVersion(for: selectedBinarySource)
    }
    
    /// Get the currently installed version.
    var currentVersion: String? {
        storageManager.getCurrentVersion(for: selectedBinarySource)
    }
    
    /// List all installed versions.
    var installedVersions: [InstalledProxyVersion] {
        storageManager.listInstalledVersions(for: selectedBinarySource)
    }
    
    // MARK: - Upgrade Flow

    /// Check if an upgrade is available.
    /// Uses Atom feed with ETag caching for efficient polling.
    /// Falls back to GitHub API only when needed for download URLs.
    func checkForUpgrade() async {
        // Record when this check was performed
        lastProxyUpdateCheckDate = Date()

        guard selectedBinarySource == .upstream else {
            upgradeAvailable = false
            availableUpgrade = nil
            return
        }
        
        // Use AtomFeedUpdateService for efficient version checking
        let currentVer = currentVersion ?? installedProxyVersion
        let (latestVersion, isNewer) = await AtomFeedUpdateService.shared.checkForCLIProxyUpdate(source: selectedBinarySource, currentVersion: currentVer)

        guard isNewer, let latestTag = latestVersion else {
            upgradeAvailable = false
            availableUpgrade = nil
            return
        }

        // New version available - fetch release details from GitHub API for download URL
        do {
            let release = try await fetchGitHubRelease(tag: latestTag, source: selectedBinarySource)

            guard let asset = findCompatibleAsset(from: release) else {
                upgradeAvailable = false
                availableUpgrade = nil
                return
            }

            let versionInfo = ProxyVersionInfo(from: release, asset: asset, source: selectedBinarySource)
            guard let info = versionInfo else {
                upgradeAvailable = false
                availableUpgrade = nil
                return
            }

            upgradeAvailable = true
            availableUpgrade = info

            // Note: Notification is handled by AtomFeedUpdateService polling
            let version = latestTag.hasPrefix("v") ? String(latestTag.dropFirst()) : latestTag
            NSLog("[CLIProxyManager] Upgrade available: \(version)")
        } catch {
            NSLog("[CLIProxyManager] Failed to fetch release details: \(error.localizedDescription)")
            upgradeAvailable = false
            availableUpgrade = nil
        }
    }
    
    /// Stored version from UserDefaults (for legacy single-binary installs).
    /// Public accessor for the settings screen.
    var installedProxyVersion: String? {
        UserDefaults.standard.string(forKey: selectedBinarySource.installedVersionDefaultsKey)
    }
    
    /// Save installed version to UserDefaults.
    private func saveInstalledVersion(_ version: String, source: ProxyBinarySource) {
        UserDefaults.standard.set(version, forKey: source.installedVersionDefaultsKey)
    }
    
    // MARK: - Fetch All Releases (for Advanced Mode)
    
    func fetchAvailableVersions(limit: Int = 10) async throws -> [ProxyVersionInfo] {
        switch selectedBinarySource {
        case .plusLocal:
            return [plusLocalVersionInfo()].compactMap { $0 }
        case .upstream:
            return try await fetchAvailableUpstreamVersions(limit: limit)
        }
    }

    /// Fetch all available releases from GitHub.
    /// Used by Advanced Mode to allow users to select a specific version.
    private func fetchAvailableUpstreamVersions(limit: Int) async throws -> [ProxyVersionInfo] {
        guard let githubRepo = selectedBinarySource.githubRepo else {
            return []
        }

        let urlString = "https://api.github.com/repos/\(githubRepo)/releases?per_page=\(limit)"
        guard let url = URL(string: urlString) else {
            throw ProxyError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("Edx/1.0", forHTTPHeaderField: "User-Agent")

        let config = ProxyConfigurationService.createProxiedConfigurationStatic(timeout: 30)
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProxyError.networkError("Failed to fetch releases")
        }

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        return releases.compactMap { versionInfo(from: $0) }
    }
    
    /// Convert a GitHubRelease to ProxyVersionInfo for a compatible asset.
    func versionInfo(from release: GitHubRelease) -> ProxyVersionInfo? {
        guard let asset = findCompatibleAsset(from: release) else { return nil }
        return ProxyVersionInfo(from: release, asset: asset, source: selectedBinarySource)
    }
    
    /// Fetch GitHub release info for a specific tag.
    private func fetchGitHubRelease(tag: String, source: ProxyBinarySource) async throws -> GitHubRelease {
        guard let githubRepo = source.githubRepo else {
            throw ProxyError.networkError("Selected source does not provide online releases")
        }

        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/tags/\(tag)"
        guard let url = URL(string: urlString) else {
            throw ProxyError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("Edx/1.0", forHTTPHeaderField: "User-Agent")

        let config = ProxyConfigurationService.createProxiedConfigurationStatic(timeout: 30)
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProxyError.networkError("Failed to fetch release info")
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
    
    /// Find compatible asset from GitHub release.
    private func findCompatibleAsset(from release: GitHubRelease) -> GitHubAsset? {
        #if arch(arm64)
        let targetPatterns = ["darwin_arm64", "darwin_aarch64"]
        #else
        let targetPatterns = ["darwin_amd64"]
        #endif
        let skipPatterns = ["windows", "linux", "checksum"]
        
        for asset in release.assets {
            let lowercaseName = asset.name.lowercased()
            
            let shouldSkip = skipPatterns.contains { lowercaseName.contains($0) }
            if shouldSkip { continue }
            
            if targetPatterns.contains(where: { lowercaseName.contains($0) }) {
                return asset
            }
        }
        
        return nil
    }
    
    /// Perform a managed upgrade with dry-run validation.
    /// This is the main entry point for upgrades.
    /// 
    /// Flow:
    /// 1. Download and verify new version
    /// 2. Start dry-run on test port
    /// 3. Validate compatibility via /meta
    /// 4. If valid: promote to active; if not: rollback
    func performManagedUpgrade(to version: ProxyVersionInfo) async throws {
        guard managerState == .active || managerState == .idle else {
            throw ProxyUpgradeError.dryRunFailed("Cannot upgrade while in \(managerState) state")
        }

        guard version.source == selectedBinarySource else {
            throw ProxyUpgradeError.dryRunFailed("Selected source changed while preparing install")
        }
        
        upgradeError = nil
        
        // Step 1: Download and install to versioned storage
        let installed = try await downloadAndInstallVersion(version)

        // Step 2: Promote directly. Edx 只保留一份本地配置，不再为升级 dry-run 生成第二份 YAML 配置。
        let wasRunning = proxyStatus.running
        if wasRunning {
            stop()
        }

        try storageManager.setCurrentVersion(installed.version, source: version.source)
        activeVersion = installed.version

        if wasRunning {
            try await start()
        }

        managerState = proxyStatus.running ? .active : .idle

        // Cleanup old versions
        storageManager.cleanupOldVersions(source: version.source, keepLast: AppConstants.maxInstalledVersions)
        
        // Reset upgrade state - no longer available since we just installed it
        upgradeAvailable = false
        availableUpgrade = nil
        
        // Save the installed version
        saveInstalledVersion(installed.version, source: version.source)
        
        // Suppress any future upgrade notifications for this version
        // This prevents the bug where a notification is shown immediately after upgrading
        NotificationManager.shared.suppressUpgradeNotification(version: installed.version)
        
        NotificationManager.shared.notifyUpgradeSuccess(version: installed.version)
    }
    
    /// Download and install a specific version.
    private func downloadAndInstallVersion(_ versionInfo: ProxyVersionInfo) async throws -> InstalledProxyVersion {
        isDownloading = true
        downloadProgress = 0
        
        defer { isDownloading = false }
        
        // Determine download URL
        let binaryData: Data
        let assetName: String
        if let localFilePath = versionInfo.localFilePath {
            let fileURL = URL(fileURLWithPath: localFilePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw ProxyUpgradeError.downloadFailed("Local binary not found at \(localFilePath)")
            }
            binaryData = try Data(contentsOf: fileURL)
            assetName = fileURL.lastPathComponent
        } else {
            let downloadURL: String
            if let url = versionInfo.downloadURL {
                downloadURL = url
            } else {
                // Fall back to GitHub release
                let release = try await fetchLatestRelease(source: versionInfo.source)
                guard let asset = findCompatibleAsset(in: release) else {
                    throw ProxyUpgradeError.downloadFailed("No compatible binary found")
                }
                downloadURL = asset.downloadURL
            }
            
            downloadProgress = 0.1
            binaryData = try await downloadAsset(url: downloadURL)
            assetName = URL(string: downloadURL)?.lastPathComponent ?? "CLIProxyAPI"
        }
        
        downloadProgress = 0.6
        
        // Verify checksum - fail if no valid checksum is provided
        guard !versionInfo.sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProxyUpgradeError.downloadFailed("No valid SHA256 checksum provided for downloaded binary")
        }
        try ChecksumVerifier.verifyOrThrow(data: binaryData, expected: versionInfo.sha256)
        downloadProgress = 0.7
        
        // Install to versioned storage
        let installed = try await storageManager.installVersion(
            source: versionInfo.source,
            version: versionInfo.version,
            binaryData: binaryData,
            assetName: assetName
        )
        downloadProgress = 1.0
        
        return installed
    }
    
    /// Rollback to the previous version.
    func rollback() async throws {
        guard let previousVersion = findPreviousVersion() else {
            throw ProxyUpgradeError.rollbackFailed("No previous version to rollback to")
        }
        
        managerState = .rollingBack
        
        // Stop current proxy
        let wasRunning = proxyStatus.running
        if wasRunning {
            stop()
        }
        
        // Delete the problematic current version if different from previous
        if let current = currentVersion, current != previousVersion {
            try? storageManager.deleteVersion(current, source: selectedBinarySource)
        }
        
        // Set previous as current
        try storageManager.setCurrentVersion(previousVersion, source: selectedBinarySource)
        activeVersion = previousVersion
        
        // Restart if was running
        if wasRunning {
            try await start()
        }
        
        managerState = proxyStatus.running ? .active : .idle
        
        NotificationManager.shared.notifyRollback(toVersion: previousVersion)
    }
    
    // MARK: - Private Helpers

    /// Compare two semantic version strings.
    /// Returns true if `newer` is greater than `older`.
    /// Handles versions like "6.6.73-0" where the suffix after "-" is a build number.
    private func isNewerVersion(_ newer: String, than older: String) -> Bool {
        // Parse version string into (major, minor, patch, build) components
        // Format: "6.6.73-0" -> [6, 6, 73, 0]
        func parseVersion(_ version: String) -> [Int] {
            // First split by "-" to separate version from build number
            let dashParts = version.split(separator: "-")
            let mainVersion = String(dashParts.first ?? "")
            let buildNumber = dashParts.count > 1 ? Int(dashParts[1]) : nil
            
            // Split main version by "."
            var parts = mainVersion.split(separator: ".").compactMap { Int($0) }
            
            // Append build number if present
            if let build = buildNumber {
                parts.append(build)
            }
            
            return parts
        }
        
        let newerParts = parseVersion(newer)
        let olderParts = parseVersion(older)
        
        // Pad shorter array with zeros
        let maxLength = max(newerParts.count, olderParts.count)
        let paddedNewer = newerParts + Array(repeating: 0, count: maxLength - newerParts.count)
        let paddedOlder = olderParts + Array(repeating: 0, count: maxLength - olderParts.count)
        
        for (n, o) in zip(paddedNewer, paddedOlder) {
            if n > o { return true }
            if n < o { return false }
        }
        
        return false // Equal versions
    }
    
    private func plusLocalVersionInfo() -> ProxyVersionInfo? {
        guard let bundledBinaryPath = resolveBundledPlusBinaryPath() else {
            return nil
        }

        return ProxyVersionInfo(
            source: .plusLocal,
            version: ProxyBinarySource.plusLocalVersion,
            sha256: ProxyBinarySource.plusLocalSHA256,
            localFilePath: bundledBinaryPath,
            releaseNotes: "Fixed local CLIProxyAPIPlus binary for legacy compatibility."
        )
    }

    private func installLocalPlusBinary() async throws -> InstalledProxyVersion {
        guard let versionInfo = plusLocalVersionInfo() else {
            throw ProxyUpgradeError.downloadFailed("Local CLIProxyAPIPlus binary is unavailable")
        }
        return try await downloadAndInstallVersion(versionInfo)
    }

    private func findPreviousVersion() -> String? {
        let versions = installedVersions
        let current = currentVersion
        
        // Find the most recent version that isn't current
        return versions
            .filter { $0.version != current }
            .sorted { $0.installedAt > $1.installedAt }
            .first?.version
    }
    
    /// Migrate from legacy single-binary to versioned storage.
    func migrateToVersionedStorage() async throws {
        guard !isUsingVersionedStorage else { return }
        guard isBinaryInstalled else { return }
        
        // Read the existing binary
        let legacyBinaryURL = URL(fileURLWithPath: binaryPath)
        let binaryData = try Data(contentsOf: legacyBinaryURL)
        
        // Determine version (use "legacy" if unknown)
        let version = "legacy"
        
        // Install to versioned storage (skip checksum for legacy migration)
        _ = try await storageManager.installVersion(
            source: .plusLocal,
            version: version,
            binaryData: binaryData,
            assetName: "CLIProxyAPI"
        )
        
        // Set as current
        try storageManager.setCurrentVersion(version, source: .plusLocal)
        activeVersion = version
        
        // Optionally remove legacy binary
        try? FileManager.default.removeItem(atPath: binaryPath)
    }

    private func initializeSelectedBinarySourceIfNeeded() {
        if UserDefaults.standard.string(forKey: ProxyBinarySource.userDefaultsKey) != nil {
            return
        }

        let defaultSource = defaultBinarySource()
        UserDefaults.standard.set(defaultSource.rawValue, forKey: ProxyBinarySource.userDefaultsKey)
        UserDefaults.standard.set(defaultSource == .plusLocal, forKey: ProxyBinarySource.explicitSelectionDefaultsKey)
    }

    private func defaultBinarySource() -> ProxyBinarySource {
        if storageManager.hasAnyInstalledVersion || FileManager.default.fileExists(atPath: binaryPath) {
            return .plusLocal
        }
        return .upstream
    }

    private func migrateLegacyVersionedStorageIfNeeded() {
        let legacyRoot = URL(fileURLWithPath: binaryPath)
            .deletingLastPathComponent()
            .appendingPathComponent("proxy")
        let legacyCurrent = legacyRoot.appendingPathComponent("current")
        let plusRoot = URL(fileURLWithPath: binaryPath)
            .deletingLastPathComponent()
            .appendingPathComponent("proxy")
            .appendingPathComponent(ProxyBinarySource.plusLocal.storageDirectoryName)

        guard FileManager.default.fileExists(atPath: legacyCurrent.path) else { return }
        guard !FileManager.default.fileExists(atPath: plusRoot.path) else { return }

        do {
            try FileManager.default.createDirectory(at: plusRoot, withIntermediateDirectories: true)

            if let contents = try? FileManager.default.contentsOfDirectory(at: legacyRoot, includingPropertiesForKeys: nil) {
                for item in contents where item.lastPathComponent != ProxyBinarySource.plusLocal.storageDirectoryName &&
                    item.lastPathComponent != ProxyBinarySource.upstream.storageDirectoryName {
                    let destination = plusRoot.appendingPathComponent(item.lastPathComponent)
                    try FileManager.default.moveItem(at: item, to: destination)
                }
            }
        } catch {
            Log.proxy("Failed to migrate legacy proxy storage: \(error)")
        }
    }

    private func resolveBundledPlusBinaryPath() -> String? {
        let fileManager = FileManager.default
        let binaryName = ProxyBinarySource.plusLocalBinaryName
        let resourceSubdirectory = ProxyBinarySource.plusLocalResourceSubdirectory

        func firstExistingRegularFile(in candidates: [URL?]) -> String? {
            for candidate in candidates.compactMap({ $0 }) {
                guard fileManager.fileExists(atPath: candidate.path) else {
                    continue
                }

                let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if values?.isRegularFile == true,
                   values?.isSymbolicLink != true {
                    return candidate.path
                }
            }
            return nil
        }

        let bundleCandidates: [URL?] = [
            Bundle.main.url(forResource: binaryName, withExtension: nil, subdirectory: resourceSubdirectory),
            Bundle.main.resourceURL?
                .appendingPathComponent(resourceSubdirectory, isDirectory: true)
                .appendingPathComponent(binaryName, isDirectory: false),
            Bundle.main.url(forResource: binaryName, withExtension: nil),
            Bundle.main.resourceURL?
                .appendingPathComponent(binaryName, isDirectory: false),
        ]

        if let bundledPath = firstExistingRegularFile(in: bundleCandidates) {
            return bundledPath
        }

        let repoResourcesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
        let repoCandidates: [URL?] = [
            repoResourcesRoot
                .appendingPathComponent(resourceSubdirectory, isDirectory: true)
                .appendingPathComponent(binaryName, isDirectory: false),
            repoResourcesRoot
                .appendingPathComponent(binaryName, isDirectory: false),
        ]

        if let repoPath = firstExistingRegularFile(in: repoCandidates) {
            return repoPath
        }

        Log.proxy("Bundled CLIProxyAPIPlus binary not found in app resources or repo resources")
        return nil
    }
}
