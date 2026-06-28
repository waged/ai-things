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

    /// Every live CLI process, so they can all be killed on app quit. A chat's
    /// session id is NOT stored here — it travels with each request — so multiple
    /// chats can stream in parallel without sharing state.
    private let processLock = NSLock()
    private var runningProcesses: [Process] = []

    private func track(_ process: Process) {
        processLock.lock(); runningProcesses.append(process); processLock.unlock()
    }
    private func untrack(_ process: Process) {
        processLock.lock(); runningProcesses.removeAll { $0 === process }; processLock.unlock()
    }

    /// Terminate every running `claude` process immediately (called on app quit).
    func terminateRunning() {
        processLock.lock(); let procs = runningProcesses; runningProcesses.removeAll(); processLock.unlock()
        procs.forEach { $0.terminate() }
    }

    init(model: String = "", skipPermissions: Bool = true) {
        self.model = model
        self.skipPermissions = skipPermissions
    }

    /// One-shot text rewrite using a fast model — no project context, no
    /// session, no tools. Returns nil on failure so the caller can fall back.
    func rewrite(_ text: String) async -> String? {
        guard let cli = resolveCLI() else { return nil }
        let prompt = """
        Your job: improve a PROMPT that will be sent to a coding agent to carry out a software task. Rewrite the user's text into one clear, precise instruction the agent can act on.

        Rules:
        - Keep it an imperative instruction (a task to perform). NEVER turn it into a question. NEVER answer, explain, or perform it.
        - Preserve the original intent and scope exactly — do not add, drop, or invent requirements or assumptions.
        - Keep all technical details verbatim: file paths, code, identifiers, and inline tokens like [[img:abc12345]].
        - Make it specific and unambiguous; remove filler and vague wording. No greetings, preamble, commentary, or surrounding quotes.
        - Output ONLY the rewritten instruction text, nothing else.

        User text:
        \(text)
        """
        let raw: String? = await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cli.binary)
            process.arguments = ["-p", prompt, "--output-format", "text", "--model", "haiku"]
            // Run these helper calls in a neutral temp dir (not the app's inherited
            // cwd, which can be "/" or home) so the CLI doesn't scan into
            // TCC-protected folders (~/Pictures, ~/Music) and trigger Photos /
            // Apple Music permission prompts on send.
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = cli.path
            process.environment = env
            let out = Pipe()
            process.standardOutput = out
            process.standardError = Pipe()
            process.terminationHandler = { proc in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let result = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (proc.terminationStatus == 0 && !result.isEmpty) ? result : nil)
            }
            do { try process.run() } catch { continuation.resume(returning: nil) }
        }
        return raw.map(Self.sanitizeRewrite)
    }

    /// Route a new message to the right chat using a fast model. Returns the
    /// decision ("keep" | "move" | "new") and, for "move", the index into
    /// `others`. Returns nil on failure so the caller can just send in place.
    /// No project context, no session, no tools.
    func classifyRoute(message: String, currentTopic: String, others: [String]) async -> (decision: String, chat: Int)? {
        guard let cli = resolveCLI() else { return nil }
        let list = others.isEmpty ? "(none)"
            : others.enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
        let prompt = """
        You route a NEW MESSAGE to the right chat thread in a coding assistant. Decide whether it belongs in the CURRENT chat, in one of the OTHER chats, or in a brand-new chat.

        Rules:
        - Prefer "keep". Only choose otherwise when the topic clearly differs.
        - "move": exactly one OTHER chat is a clearly better fit (same feature/area of the codebase).
        - "new": the message is a different topic/feature from the CURRENT chat AND none of the others fit.
        - Judge by topic/feature/intent, not by surface wording. Follow-ups, fixes, and refinements of the current work are "keep".

        Output ONLY one line of JSON, nothing else:
        {"decision":"keep|move|new","chat":<OTHER index, or -1>}

        CURRENT chat topic:
        \(currentTopic.isEmpty ? "(empty / brand-new chat)" : currentTopic)

        OTHER chats:
        \(list)

        NEW MESSAGE:
        \(message)
        """
        let raw: String? = await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cli.binary)
            process.arguments = ["-p", prompt, "--output-format", "text", "--model", "haiku"]
            // Run these helper calls in a neutral temp dir (not the app's inherited
            // cwd, which can be "/" or home) so the CLI doesn't scan into
            // TCC-protected folders (~/Pictures, ~/Music) and trigger Photos /
            // Apple Music permission prompts on send.
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = cli.path
            process.environment = env
            let out = Pipe()
            process.standardOutput = out
            process.standardError = Pipe()
            process.terminationHandler = { proc in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let result = String(decoding: data, as: UTF8.self)
                continuation.resume(returning: proc.terminationStatus == 0 ? result : nil)
            }
            do { try process.run() } catch { continuation.resume(returning: nil) }
        }
        return raw.flatMap(Self.parseRoute)
    }

    /// A short, human chat title summarizing the user's request, via a fast
    /// model. Returns nil on failure so the caller can keep its heuristic title.
    func suggestTitle(_ text: String) async -> String? {
        guard let cli = resolveCLI() else { return nil }
        let prompt = """
        Write a SHORT title for a chat, summarizing the topic of the user's request below.
        Rules: 2–6 words. Title Case. No quotes, no trailing punctuation, no preamble or explanation. Output ONLY the title.

        Request:
        \(text)
        """
        let raw: String? = await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cli.binary)
            process.arguments = ["-p", prompt, "--output-format", "text", "--model", "haiku"]
            // Run these helper calls in a neutral temp dir (not the app's inherited
            // cwd, which can be "/" or home) so the CLI doesn't scan into
            // TCC-protected folders (~/Pictures, ~/Music) and trigger Photos /
            // Apple Music permission prompts on send.
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = cli.path
            process.environment = env
            let out = Pipe()
            process.standardOutput = out
            process.standardError = Pipe()
            process.terminationHandler = { proc in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let result = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (proc.terminationStatus == 0 && !result.isEmpty) ? result : nil)
            }
            do { try process.run() } catch { continuation.resume(returning: nil) }
        }
        return raw.map(Self.sanitizeTitle)
    }

    /// Keep just a clean one-line title (first line, no quotes, length-capped).
    private static func sanitizeTitle(_ text: String) -> String {
        var s = (text.split(separator: "\n").first.map(String.init) ?? text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count >= 2, let f = s.first, let l = s.last,
           (f == "\"" && l == "\"") || (f == "'" && l == "'") || (f == "“" && l == "”") {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while let last = s.last, ".,:;!?".contains(last) { s = String(s.dropLast()) }
        return String(s.prefix(60))
    }

    /// Pull `{"decision":...,"chat":...}` out of the model's reply.
    private static func parseRoute(_ text: String) -> (decision: String, chat: Int)? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
              start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let decision = obj["decision"] as? String else { return nil }
        let chat = (obj["chat"] as? Int) ?? Int(obj["chat"] as? String ?? "") ?? -1
        let valid = ["keep", "move", "new"]
        return valid.contains(decision) ? (decision, chat) : nil
    }

    /// Strip wrappers Haiku sometimes adds despite instructions (surrounding
    /// quotes, a "Rewritten:"-style lead-in).
    private static func sanitizeRewrite(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadIns = ["rewritten prompt:", "rewritten instruction:", "rewritten:", "here is the rewritten prompt:", "here's the rewritten prompt:", "prompt:"]
        for lead in leadIns where s.lowercased().hasPrefix(lead) {
            s = String(s.dropFirst(lead.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        if s.count >= 2, let f = s.first, let l = s.last,
           (f == "\"" && l == "\"") || (f == "'" && l == "'") || (f == "“" && l == "”") {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

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
            if let resume = request.resumeSessionID { args += ["--resume", resume] }
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

            let onSessionID = request.onSessionID
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                stdoutBuffer.append(data)
                while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
                    let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newline)
                    stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newline)
                    if let text = self.render(lineData, onSessionID: onSessionID) { continuation.yield(text) }
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let s = String(data: data, encoding: .utf8) { stderrText += s }
            }

            process.terminationHandler = { proc in
                self.untrack(proc)
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if !stdoutBuffer.isEmpty, let text = self.render(stdoutBuffer, onSessionID: onSessionID) {
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
                self.track(process)
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
    /// `onSessionID` reports this turn's CLI session id back to the caller.
    private func render(_ lineData: Data, onSessionID: (@Sendable (String) -> Void)?) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let type = object["type"] as? String else { return nil }

        switch type {
        case "system":
            // Capture the session id from the init event for later --resume.
            if object["subtype"] as? String == "init", let sid = object["session_id"] as? String {
                onSessionID?(sid)
            }
            return nil

        case "assistant":
            return renderAssistant(object)

        case "result":
            if let sid = object["session_id"] as? String { onSessionID?(sid) }
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

    /// Run a command in a login + interactive shell so BOTH `.zprofile` and
    /// `.zshrc` apply. A GUI app launched from Finder/Xcode starts with a
    /// minimal PATH, so a plain `zsh -lc` (login only) misses PATH entries
    /// that users add in `.zshrc` — which is where `~/.local/bin` often lives.
    private func shellLines(_ command: String) -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-ilc", command]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return [] }
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Resolve the `claude` binary and a usable PATH once, then cache.
    private func resolveCLI() -> CLI? {
        if let resolved = Self.resolved { return resolved }
        let home = NSHomeDirectory()
        let fm = FileManager.default

        // 1) Check well-known install locations directly — works regardless of PATH.
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.bun/bin/claude",
            "/usr/bin/claude",
        ]
        var binary = candidates.first { fm.isExecutableFile(atPath: $0) }

        // 2) Fall back to the login+interactive shell's own resolution.
        if binary == nil {
            binary = shellLines("command -v claude").last.flatMap {
                fm.isExecutableFile(atPath: $0) ? $0 : nil
            }
        }
        guard let bin = binary else { return nil }

        // Build a PATH from the login shell, then guarantee the essentials.
        var dirs = (shellLines("echo \"$PATH\"").first ?? "")
            .split(separator: ":").map(String.init)
        let essentials = [
            (bin as NSString).deletingLastPathComponent,
            "\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        for dir in essentials where !dir.isEmpty && !dirs.contains(dir) { dirs.append(dir) }

        let cli = CLI(binary: bin, path: dirs.joined(separator: ":"))
        Self.resolved = cli
        return cli
    }
}
