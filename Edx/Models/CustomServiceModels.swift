//
//  CustomServiceModels.swift
//  Edx
//
//  Models for user-defined long-running services (e.g. `headroom proxy ...`).
//  These are managed processes that the user can start/stop, optionally surface
//  in the menu bar, and inspect logs for.
//

import Foundation

// MARK: - Custom Service

/// A user-defined long-running service launched from a command line.
///
/// Example command: `headroom proxy --port 8787 --anthropic-api-url "http://127.0.0.1:8317"`
struct CustomService: Codable, Identifiable, Sendable, Hashable {
    var id: UUID
    /// Display name shown in the UI and menu bar.
    var name: String
    /// Full command line, including the executable and all arguments.
    var command: String
    /// Optional working directory the process is launched from.
    var workingDirectory: String?
    /// Extra environment variables merged onto the inherited environment.
    var environment: [String: String]
    /// Whether the service is shown in the menu bar quick panel.
    var showInMenuBar: Bool
    /// Whether the service is started automatically when the app launches.
    var autoStart: Bool
    /// Optional GitHub repository slug (`owner/repo`) used for release checks.
    var githubRepository: String?
    /// The currently installed version of this service, used to decide whether
    /// a fetched release is actually newer. When empty, any release is treated
    /// as "available" (unknown baseline).
    var currentVersion: String?
    /// A release version the user chose to skip. Updates matching it are hidden.
    var ignoredVersion: String?
    /// Optional command used to detect the currently installed version.
    /// When empty, `<executable> --version` is used as a default.
    var versionCommand: String?
    /// Optional command used to update the tool (e.g. `brew upgrade mytool`).
    var updateCommand: String?
    /// Latest release information discovered for this service.
    var updateStatus: CustomServiceUpdateStatus?

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        showInMenuBar: Bool = true,
        autoStart: Bool = false,
        githubRepository: String? = nil,
        currentVersion: String? = nil,
        ignoredVersion: String? = nil,
        versionCommand: String? = nil,
        updateCommand: String? = nil,
        updateStatus: CustomServiceUpdateStatus? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.showInMenuBar = showInMenuBar
        self.autoStart = autoStart
        self.githubRepository = githubRepository
        self.currentVersion = currentVersion
        self.ignoredVersion = ignoredVersion
        self.versionCommand = versionCommand
        self.updateCommand = updateCommand
        self.updateStatus = updateStatus
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case command
        case workingDirectory = "working_directory"
        case environment
        case showInMenuBar = "show_in_menu_bar"
        case autoStart = "auto_start"
        case githubRepository = "github_repository"
        case currentVersion = "current_version"
        case ignoredVersion = "ignored_version"
        case versionCommand = "version_command"
        case updateCommand = "update_command"
        case updateStatus = "update_status"
    }

    // Provide defaults for fields that may be missing in older persisted data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.command = try container.decodeIfPresent(String.self, forKey: .command) ?? ""
        self.workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        self.environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        self.showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        self.autoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
        self.githubRepository = try container.decodeIfPresent(String.self, forKey: .githubRepository)
        self.currentVersion = try container.decodeIfPresent(String.self, forKey: .currentVersion)
        self.ignoredVersion = try container.decodeIfPresent(String.self, forKey: .ignoredVersion)
        self.versionCommand = try container.decodeIfPresent(String.self, forKey: .versionCommand)
        self.updateCommand = try container.decodeIfPresent(String.self, forKey: .updateCommand)
        self.updateStatus = try container.decodeIfPresent(CustomServiceUpdateStatus.self, forKey: .updateStatus)
    }

    /// The first token of the command, i.e. the executable name or path.
    var executableToken: String {
        CommandTokenizer.tokenize(command).first ?? ""
    }

    /// Trimmed current version, or nil when the user hasn't provided one.
    var normalizedCurrentVersion: String? {
        guard let currentVersion else { return nil }
        let trimmed = currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The command used to detect the installed version. Falls back to
    /// `<executable> --version` when the user hasn't set one.
    var effectiveVersionCommand: String? {
        if let versionCommand {
            let trimmed = versionCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let executable = executableToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executable.isEmpty else { return nil }
        return "\(executable) --version"
    }

    /// Trimmed update command, or nil when not configured.
    var normalizedUpdateCommand: String? {
        guard let updateCommand else { return nil }
        let trimmed = updateCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Whether a fetched release is genuinely newer than the installed version
    /// and hasn't been explicitly ignored by the user.
    var isUpdateAvailable: Bool {
        guard let status = updateStatus, status.hasRelease else { return false }
        let latest = status.latestVersion

        // Respect an explicitly skipped version.
        if let ignored = ignoredVersion,
           SemanticVersion.compare(latest, ignored) == .orderedSame {
            return false
        }

        // Without a known baseline, surface any release as available.
        guard let current = normalizedCurrentVersion else { return true }

        return SemanticVersion.compare(latest, current) == .orderedDescending
    }
}

// MARK: - Semantic Version

/// Lightweight semantic-version parser/comparator tolerant of common tag
/// formats (`v1.2.3`, `1.2`, `2024.01`, pre-release suffixes like `-beta.1`).
///
/// Comparison rules:
/// - Numeric release identifiers are compared field by field.
/// - A version with a pre-release suffix is lower than the same version without.
/// - When neither side parses into numeric fields, we fall back to a
///   case-insensitive string comparison so unequal tags are still distinguished.
struct SemanticVersion: Sendable, Equatable {
    let release: [Int]
    let preRelease: [String]

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = parse(lhs)
        let right = parse(rhs)

        // Neither parsed into numbers: compare the raw strings.
        if left == nil && right == nil {
            let l = normalizedString(lhs)
            let r = normalizedString(rhs)
            if l == r { return .orderedSame }
            return l < r ? .orderedAscending : .orderedDescending
        }

        guard let left else { return .orderedAscending }
        guard let right else { return .orderedDescending }

        // Compare numeric release fields, treating missing fields as 0.
        let fieldCount = max(left.release.count, right.release.count)
        for index in 0..<fieldCount {
            let l = index < left.release.count ? left.release[index] : 0
            let r = index < right.release.count ? right.release[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }

        // Equal release numbers: a version WITH a pre-release is lower.
        switch (left.preRelease.isEmpty, right.preRelease.isEmpty) {
        case (true, true): return .orderedSame
        case (true, false): return .orderedDescending
        case (false, true): return .orderedAscending
        case (false, false):
            return comparePreRelease(left.preRelease, right.preRelease)
        }
    }

    private static func comparePreRelease(_ lhs: [String], _ rhs: [String]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            if index >= lhs.count { return .orderedAscending }
            if index >= rhs.count { return .orderedDescending }
            let l = lhs[index]
            let r = rhs[index]
            if l == r { continue }
            if let li = Int(l), let ri = Int(r) {
                return li < ri ? .orderedAscending : .orderedDescending
            }
            return l < r ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }

    private static func normalizedString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func parse(_ raw: String) -> SemanticVersion? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Strip a leading "v" / "V" prefix.
        if let first = text.first, first == "v" || first == "V" {
            text.removeFirst()
        }

        // Date-based versions: YYYY-MM-DD, YYYY.MM.DD, YYYY/MM/DD, YYYYMMDD.
        if let dateVersion = parseDate(text) {
            return dateVersion
        }

        // Drop build metadata (`+...`).
        if let plusIndex = text.firstIndex(of: "+") {
            text = String(text[..<plusIndex])
        }

        // Split release core from pre-release suffix.
        let corePart: Substring
        let preReleasePart: Substring?
        if let dashIndex = text.firstIndex(of: "-") {
            corePart = text[..<dashIndex]
            preReleasePart = text[text.index(after: dashIndex)...]
        } else {
            corePart = Substring(text)
            preReleasePart = nil
        }

        let releaseFields = corePart
            .split(separator: ".")
            .map { Int($0) }

        // Require the release core to be fully numeric to count as parsed.
        guard !releaseFields.isEmpty, releaseFields.allSatisfy({ $0 != nil }) else {
            return nil
        }

        let preRelease = preReleasePart?
            .split(separator: ".")
            .map(String.init) ?? []

        return SemanticVersion(release: releaseFields.map { $0! }, preRelease: preRelease)
    }

    /// Parse a date-style version into [year, month, day] release fields.
    private static func parseDate(_ text: String) -> SemanticVersion? {
        // YYYY-MM-DD, YYYY.MM.DD, YYYY/MM/DD
        if let match = text.range(
            of: #"^(\d{4})[-./](\d{1,2})[-./](\d{1,2})$"#,
            options: .regularExpression
        ), match.lowerBound == text.startIndex {
            let parts = text.split(whereSeparator: { $0 == "-" || $0 == "." || $0 == "/" })
            let fields = parts.compactMap { Int($0) }
            if fields.count == 3 {
                return SemanticVersion(release: fields, preRelease: [])
            }
        }

        // Compact YYYYMMDD.
        if text.range(of: #"^\d{8}$"#, options: .regularExpression) != nil,
           let year = Int(text.prefix(4)),
           let month = Int(text.dropFirst(4).prefix(2)),
           let day = Int(text.dropFirst(6).prefix(2)) {
            return SemanticVersion(release: [year, month, day], preRelease: [])
        }

        return nil
    }
}

// MARK: - Version Extractor

/// Pulls a version string out of arbitrary `--version` command output.
///
/// Handles the common shapes:
/// - `mytool version 1.4.2`
/// - `v1.4.2`
/// - `1.4.2-beta.3`
/// - `2024-01-15` / `2024.01.15`
nonisolated enum VersionExtractor {
    /// The first version-looking token found in the text, or nil.
    static func extract(from output: String) -> String? {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Ordered patterns: prefer semver-with-prerelease, then dates, then plain.
        let patterns = [
            #"[vV]?\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.]+)?"#,   // 1.2.3 / v1.2.3 / 1.2.3-beta.1
            #"\d{4}[-./]\d{1,2}[-./]\d{1,2}"#,               // 2024-01-15
            #"[vV]?\d+\.\d+"#,                               // 1.2
            #"\b\d{8}\b"#                                    // 20240115
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        return nil
    }
}

// MARK: - Update Status

/// Latest GitHub release check result for a custom service.
struct CustomServiceUpdateStatus: Codable, Sendable, Hashable {
    var repository: String
    var latestVersion: String
    var latestReleaseTitle: String
    var latestReleaseURL: String
    var latestPublishedAt: Date?
    var lastCheckedAt: Date
    var errorMessage: String?
    /// HTTP ETag from the last successful fetch, used for conditional requests
    /// so unchanged responses return 304 (which does not count against the
    /// GitHub rate limit).
    var etag: String?

    var hasRelease: Bool {
        !latestVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !latestReleaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case repository
        case latestVersion = "latest_version"
        case latestReleaseTitle = "latest_release_title"
        case latestReleaseURL = "latest_release_url"
        case latestPublishedAt = "latest_published_at"
        case lastCheckedAt = "last_checked_at"
        case errorMessage = "error_message"
        case etag
    }
}

// MARK: - Runtime State

/// Transient release check state used by the UI while a check is in flight.
struct CustomServiceUpdateCheckState: Sendable, Equatable {
    var isChecking: Bool = false
    var isUpdating: Bool = false
    var requestID: Int = 0
    var message: String?
}

/// Lifecycle state of a managed custom service process.
enum CustomServiceStatus: Sendable, Equatable {
    case stopped
    case starting
    case running
    case stopping
    /// Process exited unexpectedly (non-zero or external termination).
    case failed(String)

    var isActive: Bool {
        switch self {
        case .running, .starting, .stopping:
            return true
        case .stopped, .failed:
            return false
        }
    }
}

/// Lightweight runtime snapshot for a custom service.
struct CustomServiceRuntime: Sendable {
    var status: CustomServiceStatus = .stopped
    var pid: Int32?
    var startedAt: Date?
    var lastExitCode: Int32?
    var lastError: String?
}

// MARK: - Log Line

/// A single captured line of service output.
struct CustomServiceLogLine: Identifiable, Sendable, Hashable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let isError: Bool
}

// MARK: - Command Tokenizer

/// Splits a command line into tokens, honoring single/double quotes and
/// backslash escaping (similar to a POSIX shell, minus expansion).
enum CommandTokenizer {
    static func tokenize(_ command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var hasCurrent = false
        var quote: Character? = nil
        var escaped = false

        for char in command {
            if escaped {
                current.append(char)
                hasCurrent = true
                escaped = false
                continue
            }

            if char == "\\" && quote != "'" {
                escaped = true
                hasCurrent = true
                continue
            }

            if let activeQuote = quote {
                if char == activeQuote {
                    quote = nil
                } else {
                    current.append(char)
                }
                hasCurrent = true
                continue
            }

            if char == "\"" || char == "'" {
                quote = char
                hasCurrent = true
                continue
            }

            if char == " " || char == "\t" || char == "\n" {
                if hasCurrent {
                    tokens.append(current)
                    current = ""
                    hasCurrent = false
                }
                continue
            }

            current.append(char)
            hasCurrent = true
        }

        if hasCurrent {
            tokens.append(current)
        }

        return tokens
    }
}
