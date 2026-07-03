//
//  CustomServiceCommandRunner.swift
//  Edx
//
//  Runs short-lived helper commands for custom services (version detection,
//  update commands) via a login shell so PATH and shell setup are respected.
//

import Foundation

/// Result of running a short helper command.
struct CommandResult: Sendable {
    let exitCode: Int32
    /// Combined stdout + stderr, trimmed.
    let output: String
    /// True when the command was killed because it exceeded the timeout.
    let timedOut: Bool
}

nonisolated enum CustomServiceCommandRunner {

    /// Run a command line via the user's login shell, capturing combined
    /// stdout/stderr. Blocks the calling thread, so invoke it from a detached
    /// task — never on the main actor.
    ///
    /// - Parameters:
    ///   - commandLine: full shell command (e.g. `mytool --version`).
    ///   - workingDirectory: optional cwd (tilde expanded).
    ///   - environment: extra environment variables merged onto the inherited env.
    ///   - timeout: seconds before the process is terminated.
    static func run(
        commandLine: String,
        workingDirectory: String?,
        environment: [String: String],
        timeout: TimeInterval
    ) -> CommandResult {
        let trimmed = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CommandResult(exitCode: -1, output: "", timedOut: false)
        }

        let fileManager = FileManager.default
        let shellPath = loginShellPath(fileManager: fileManager)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-l", "-c", trimmed]

        // Running via a login shell (`-l`) sets up PATH from the user's shell
        // profile, so we only need to merge the service's extra environment.
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env

        if let workingDirectory,
           !workingDirectory.trimmingCharacters(in: .whitespaces).isEmpty {
            process.currentDirectoryURL = URL(
                fileURLWithPath: (workingDirectory as NSString).expandingTildeInPath
            )
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Drain the pipe on a background queue to avoid deadlock when output
        // exceeds the pipe buffer.
        let collected = OutputCollector()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let data = fh.availableData
            if !data.isEmpty {
                collected.append(data)
            }
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            return CommandResult(exitCode: -1, output: error.localizedDescription, timedOut: false)
        }

        // Enforce the timeout with a watchdog.
        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                timedOut = true
                // Give it a brief moment, then hard kill if still alive.
                Thread.sleep(forTimeInterval: 0.2)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        process.waitUntilExit()

        handle.readabilityHandler = nil
        // Read any remaining buffered data.
        let remaining = handle.availableData
        if !remaining.isEmpty {
            collected.append(remaining)
        }
        try? handle.close()

        let output = String(data: collected.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return CommandResult(exitCode: process.terminationStatus, output: output, timedOut: timedOut)
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

/// Thread-safe accumulator for piped process output.
private nonisolated final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ chunk: Data) {
        lock.lock()
        buffer.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
