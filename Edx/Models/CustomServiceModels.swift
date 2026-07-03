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
        self.updateStatus = try container.decodeIfPresent(CustomServiceUpdateStatus.self, forKey: .updateStatus)
    }

    /// The first token of the command, i.e. the executable name or path.
    var executableToken: String {
        CommandTokenizer.tokenize(command).first ?? ""
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
    }
}

// MARK: - Runtime State

/// Transient release check state used by the UI while a check is in flight.
struct CustomServiceUpdateCheckState: Sendable, Equatable {
    var isChecking: Bool = false
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
