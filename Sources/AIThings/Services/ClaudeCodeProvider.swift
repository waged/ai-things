import Foundation

/// Real AI backend: wraps the `claude` CLI (Claude Code) running headlessly in
/// the selected project directory. This makes AI-Things a graphical front-end
/// for `claude --dangerously-skip-permissions`, with streamed, organized output.
///
/// - Uses `claude -p --output-format stream-json --verbose` and parses each
///   JSON line into readable text + tool-activity lines.
/// - Keeps conversation context across turns via `--resume <session_id>`.
/// - Runs the binary directly (no shell) with an arguments array, so the user
///   message needs no shell quoting.
final class ClaudeCodeProvider: AIProvider {
    let displayName = "Claude Code (CLI)"

    /// Model alias/id passed to `--model` (empty = the CLI's configured default).
    var model: String
    /// Pass `--dangerously-skip-permissions` so edits apply without prompts.
    var skipPermissions: Bool

    /// Captured from the CLI so follow-up messages continue the same session.
    private var sessionID: String?

    init(model: String = "", skipPermissions: Bool = true) {
        self.model = model
        self.skipPermissions = skipPermissions
    }

    /// Forget the current conversation (e.g. when the project changes).
    func resetSession() { sessionID = nil }

    var hasResolvedCLI: Bool { Self.resolved != nil || resolveCLI() != nil }

    // MARK: - Streaming

    func streamMessage(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let cwd = request.context.path, !cwd.isEmpty else {
                continuation.yield("• Open a project first — Claude needs a working directory.\n")
                continuation.finish()
                return
            }
            guard let cli = resolveCLI() else {
                continuation.yield("""
                • Claude CLI not found.
                • Install Claude Code (https://claude.com/claude-code), make sure `claude` is on your PATH, then reopen this app.
                """)
                continuation.finish()
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cli.binary)

            var args = ["-p", "--output-format", "stream-json", "--verbose"]
            if skipPermissions { args.append("--dangerously-skip-permissions") }
            if !model.isEmpty { args += ["--model", model] }
            if let sessionID { args += ["--resume", sessionID] }
            if !request.appendSystemPrompt.isEmpty {
                args += ["--append-system-prompt", request.appendSystemPrompt]
            }
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)

            // Inherit the environment but use the login-shell PATH so claude can
            // find node/git and its own helpers when launched from Finder.
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = cli.path
            process.environment = environment

            let stdinPipe = Pipe()
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = outPipe
            process.standardError = errPipe

            var stdoutBuffer = Data()
            var stderrText = ""

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                stdoutBuffer.append(data)
                while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
                    let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newline)
                    stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newline)
                    if let text = self.render(lineData) { continuation.yield(text) }
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let s = String(data: data, encoding: .utf8) { stderrText += s }
            }

            process.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if !stdoutBuffer.isEmpty, let text = self.render(stdoutBuffer) {
                    continuation.yield(text)
                }
                if proc.terminationStatus != 0 {
                    let trimmed = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        continuation.yield("\n⚠︎ \(trimmed)\n")
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning { process.terminate() }
            }

            do {
                try process.run()
                // Feed the prompt over stdin — avoids any shell-quoting concerns.
                if let data = request.userMessage.data(using: .utf8) {
                    stdinPipe.fileHandleForWriting.write(data)
                }
                try? stdinPipe.fileHandleForWriting.close()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    // MARK: - stream-json rendering

    /// Turn one JSON line into a displayable string, or nil to skip it.
    private func render(_ lineData: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let type = object["type"] as? String else { return nil }

        switch type {
        case "system":
            // Capture the session id from the init event for later --resume.
            if object["subtype"] as? String == "init", let sid = object["session_id"] as? String {
                sessionID = sid
            }
            return nil

        case "assistant":
            return renderAssistant(object)

        case "result":
            if let sid = object["session_id"] as? String { sessionID = sid }
            if (object["is_error"] as? Bool) == true {
                let detail = (object["result"] as? String) ?? "request failed"
                return "\n⚠︎ \(detail)\n"
            }
            return nil

        default:
            // user (tool results), rate_limit_event, thinking_tokens, etc.
            return nil
        }
    }

    private func renderAssistant(_ object: [String: Any]) -> String? {
        guard let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }

        var pieces: [String] = []
        for block in content {
            switch block["type"] as? String {
            case "text":
                if let text = block["text"] as? String, !text.isEmpty { pieces.append(text) }
            case "tool_use":
                pieces.append(toolLine(block))
            default:
                break // skip "thinking" and others for a clean transcript
            }
        }
        let joined = pieces.joined(separator: "\n")
        return joined.isEmpty ? nil : joined + "\n"
    }

    /// Format a tool_use block as a single, scannable activity line.
    private func toolLine(_ block: [String: Any]) -> String {
        let name = (block["name"] as? String) ?? "tool"
        let input = (block["input"] as? [String: Any]) ?? [:]
        let detail: String

        switch name {
        case "Read", "Edit", "Write", "NotebookEdit":
            detail = (input["file_path"] as? String).map(shortPath) ?? ""
        case "Bash":
            detail = (input["command"] as? String).map { truncate($0, 80) } ?? ""
        case "Grep":
            detail = (input["pattern"] as? String) ?? ""
        case "Glob":
            detail = (input["pattern"] as? String) ?? ""
        case "Task":
            detail = (input["description"] as? String) ?? ""
        default:
            detail = ""
        }
        return detail.isEmpty ? "\n⚙︎ \(name)" : "\n⚙︎ \(name) · \(detail)"
    }

    private func shortPath(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private func truncate(_ s: String, _ max: Int) -> String {
        let oneLine = s.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count <= max ? oneLine : String(oneLine.prefix(max)) + "…"
    }

    // MARK: - CLI resolution

    private struct CLI { let binary: String; let path: String }
    private static var resolved: CLI?

    /// Resolve the `claude` binary and the login-shell PATH once, then cache.
    private func resolveCLI() -> CLI? {
        if let resolved = Self.resolved { return resolved }

        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-lc", "echo \"$PATH\"; command -v claude"]
        let out = Pipe()
        probe.standardOutput = out
        probe.standardError = Pipe()
        do { try probe.run() } catch { return nil }
        probe.waitUntilExit()

        let data = out.fileHandleForReading.readDataToEndOfFile()
        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 2 else { return nil }

        let path = lines[0]
        let binary = lines[1]
        guard !binary.isEmpty, FileManager.default.isExecutableFile(atPath: binary) else { return nil }

        let cli = CLI(binary: binary, path: path)
        Self.resolved = cli
        return cli
    }
}
