import Foundation
import os
import KeyVoiceCore

public enum CLITool: String, Sendable, CaseIterable {
    case claude
    case codex
    case gemini
}

/// Uses an installed, already-authenticated AI CLI to clean a transcript.
/// Process work is dispatched off the calling actor and always resolves to a value or nil.
public final class CLICleaner: Cleaner {
    private let tool: CLITool
    private let log = Logger(subsystem: "com.keyvoice.app", category: "cleanup")

    private static let timeout: TimeInterval = 15

    public init(tool: CLITool) {
        self.tool = tool
    }

    public func clean(_ text: String, app: AppContext) async -> String? {
        guard let binPath = Self.binaryPath(for: tool) else {
            log.error("CLI cleanup skipped: \(self.tool.rawValue, privacy: .public) not found")
            return nil
        }

        let userContent = CleanupPrompt.userContent(text: text, app: app)
        let prompt = CleanupPrompt.system
            + "\n\n" + userContent
            + "\n\nReturn ONLY the cleaned text, nothing else."
        let arguments: [String]
        switch tool {
        case .claude, .gemini:
            arguments = ["-p", prompt]
        case .codex:
            arguments = ["exec", prompt]
        }

        // One attempt, plus one retry on a transient failure.
        if let cleaned = await run(binPath: binPath, arguments: arguments) {
            return cleaned
        }
        return await run(binPath: binPath, arguments: arguments)
    }

    /// Returns supported tools whose executables are present in the configured search path.
    public static func detectTools() -> [CLITool] {
        CLITool.allCases.filter { binaryPath(for: $0) != nil }
    }

    private func run(binPath: String, arguments: [String]) async -> String? {
        let toolName = tool.rawValue
        let log = log

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                process.executableURL = URL(fileURLWithPath: binPath)
                process.arguments = arguments
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = outputPipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    log.error("CLI cleanup failed (\(toolName, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }

                let deadline = Date().addingTimeInterval(Self.timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }

                guard !process.isRunning else {
                    process.terminate()
                    log.error("CLI cleanup failed (\(toolName, privacy: .public)): timed out")
                    continuation.resume(returning: nil)
                    return
                }

                guard process.terminationStatus == 0 else {
                    log.error("CLI cleanup failed (\(toolName, privacy: .public)): exit \(process.terminationStatus, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }

                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                guard let raw = String(data: data, encoding: .utf8) else {
                    log.error("CLI cleanup failed (\(toolName, privacy: .public)): stdout was not UTF-8")
                    continuation.resume(returning: nil)
                    return
                }

                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    log.error("CLI cleanup failed (\(toolName, privacy: .public)): empty output")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: trimmed)
            }
        }
    }

    private static func binaryPath(for tool: CLITool) -> String? {
        let fixedDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/.local/bin",
            "/usr/bin",
        ]
        let pathDirectories = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init) ?? []

        for directory in fixedDirectories + pathDirectories {
            let candidate = URL(fileURLWithPath: directory)
                .appendingPathComponent(tool.rawValue)
                .path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
