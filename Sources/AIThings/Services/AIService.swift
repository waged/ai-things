import Foundation

// MARK: - Provider abstraction

/// Context about the project the assistant is working inside.
struct ProjectContext {
    var path: String?
    var branch: String?
    var topLevelFiles: [String]
}

/// One turn sent to a provider.
struct AIRequest {
    var systemPrompt: String
    var history: [ChatMessage]
    var userMessage: String
    var context: ProjectContext
    /// Concise behavior directives (from the composer toggles), appended to the
    /// backend's own system prompt. Used by the Claude Code provider.
    var appendSystemPrompt: String = ""
    /// The chat's existing CLI session id to resume (nil = start fresh). Carried
    /// per-request so parallel chats never share `--resume` state.
    var resumeSessionID: String? = nil
    /// Called (possibly off the main thread) with the CLI session id for THIS
    /// turn, so the caller can store it on the correct chat.
    var onSessionID: (@Sendable (String) -> Void)? = nil
}

/// A provider's reply. `plan` is set when the assistant proposes file changes.
struct AIResponse {
    var text: String
    var plan: AssistantPlan?
}

/// Replaceable AI backend. Implement this to plug in Claude, OpenAI, a local
/// model, or a custom server. Only the streaming method is required; a default
/// `sendMessage` is derived from it.
protocol AIProvider {
    var displayName: String { get }
    func sendMessage(_ request: AIRequest) async throws -> AIResponse
    func streamMessage(_ request: AIRequest) -> AsyncThrowingStream<String, Error>
}

extension AIProvider {
    /// Default non-streaming path: collect the stream into one response.
    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in streamMessage(request) { text += chunk }
        return AIResponse(text: text, plan: nil)
    }
}

// MARK: - Facade

/// Owns the active provider and builds requests with the right system prompt.
/// Swap providers at runtime by calling `setProvider`.
final class AIService {
    private(set) var provider: AIProvider

    init(provider: AIProvider = MockAIProvider()) {
        self.provider = provider
    }

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
    }

    /// Build the system prompt from the active toggles and project context.
    func systemPrompt(
        improvement: MessageImprovementSettings,
        context: ProjectContext,
        autoApply: Bool
    ) -> String {
        var lines: [String] = [
            "You are an AI coding assistant working inside a macOS terminal app.",
            "You operate inside the user's selected project directory.",
            "Always respond with short bullet points, not long paragraphs.",
            "Focus on the software task."
        ]
        if let path = context.path { lines.append("Project: \(path)") }
        if let branch = context.branch { lines.append("Git branch: \(branch)") }
        if !context.topLevelFiles.isEmpty {
            lines.append("Top-level files: " + context.topLevelFiles.prefix(20).joined(separator: ", "))
        }
        if improvement.askQuestionsFirst {
            lines.append("If the request is unclear, ask clarifying questions BEFORE changing files. If it is clear, proceed.")
        }
        if improvement.directMode {
            lines.append("Direct mode: avoid explanations, respond with concise points focused on code changes and project actions.")
        }
        lines.append(autoApply
            ? "Auto-apply is ON for trusted changes; still summarize what changed."
            : "Never modify files without first showing a plan and the affected files for approval.")
        return lines.joined(separator: "\n")
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        provider.streamMessage(request)
    }

    func send(_ request: AIRequest) async throws -> AIResponse {
        try await provider.sendMessage(request)
    }
}
