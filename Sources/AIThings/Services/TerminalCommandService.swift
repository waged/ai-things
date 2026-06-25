import Foundation

/// Result of a finished shell command.
struct CommandResult {
    var standardOutput: String
    var standardError: String
    var exitCode: Int32

    var succeeded: Bool { exitCode == 0 }
    /// Combined, trimmed output convenient for display.
    var combined: String {
        let out = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return [out, err].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

/// A streamed line of output while a command is still running.
struct CommandOutputLine {
    enum Stream { case stdout, stderr }
    var stream: Stream
    var text: String
}

enum TerminalCommandError: LocalizedError {
    case noWorkingDirectory
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .noWorkingDirectory: return "No project directory is selected."
        case .launchFailed(let m): return "Failed to launch command: \(m)"
        }
    }
}

/// Runs shell commands inside the selected project directory, off the main thread.
///
/// - Captures stdout, stderr and the exit code.
/// - Supports cancellation via Swift Concurrency (the process is terminated
///   when the surrounding Task is cancelled).
/// - Supports line-streaming via `stream(...)` for long-running commands.
final class TerminalCommandService {

    /// Run a command to completion and return the captured result.
    /// Executed through `/bin/zsh -lc` so the user's PATH and git config apply.
    func run(
        _ command: String,
        in directory: URL?,
        environment: [String: String]? = nil
    ) async throws -> CommandResult {
        guard let directory else { throw TerminalCommandError.noWorkingDirectory }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.currentDirectoryURL = directory
                if let environment { process.environment = environment }

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                process.terminationHandler = { proc in
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let result = CommandResult(
                        standardOutput: String(decoding: outData, as: UTF8.self),
                        standardError: String(decoding: errData, as: UTF8.self),
                        exitCode: proc.terminationStatus
                    )
                    continuation.resume(returning: result)
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: TerminalCommandError.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            // Best-effort: nothing to do here directly; see stream() for live termination.
        }
    }

    /// Stream output line-by-line for long-running commands.
    /// The returned stream finishes when the process exits; cancelling the
    /// consuming task terminates the process.
    func stream(
        _ command: String,
        in directory: URL?
    ) -> AsyncThrowingStream<CommandOutputLine, Error> {
        AsyncThrowingStream { continuation in
            guard let directory else {
                continuation.finish(throwing: TerminalCommandError.noWorkingDirectory)
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            process.currentDirectoryURL = directory

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                continuation.yield(CommandOutputLine(stream: .stdout, text: String(decoding: data, as: UTF8.self)))
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                continuation.yield(CommandOutputLine(stream: .stderr, text: String(decoding: data, as: UTF8.self)))
            }

            process.terminationHandler = { _ in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning { process.terminate() }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: TerminalCommandError.launchFailed(error.localizedDescription))
            }
        }
    }
}
