import Foundation

/// Rewrites a user message to be short, direct, and clear while keeping the
/// original meaning. For the prototype this uses a fast local heuristic; the
/// same surface can be backed by an AIProvider later.
final class MessageImprovementService {
    private let provider: AIProvider?

    init(provider: AIProvider? = nil) {
        self.provider = provider
    }

    /// Produce an improved version of `text`. Returns the original on failure.
    func improve(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        // If a provider is configured, ask it to rewrite (kept simple here).
        if let provider {
            let request = AIRequest(
                systemPrompt: Self.rewriteInstruction,
                history: [],
                userMessage: trimmed,
                context: ProjectContext(path: nil, branch: nil, topLevelFiles: [])
            )
            if let response = try? await provider.sendMessage(request),
               !response.text.isEmpty {
                return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return Self.heuristicRewrite(trimmed)
    }

    static let rewriteInstruction = """
    Rewrite the user's message to be short, direct, and clear.
    Keep the original meaning. Focus on the software task.
    Remove filler words. Turn vague requests into clear action points.
    Only ask a clarifying question if the request is genuinely ambiguous.
    Reply with the rewritten message only.
    """

    /// Lightweight, dependency-free cleanup used when no provider is set.
    static func heuristicRewrite(_ text: String) -> String {
        let fillers = [
            "i was wondering if you could", "i would like you to", "could you please",
            "can you please", "i want to", "i need to", "please", "kindly",
            "if possible", "just", "really", "basically", "actually", "maybe",
            "i think", "sort of", "kind of", "you know", "for me"
        ]
        var working = text
        // Collapse whitespace and newlines.
        working = working
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let lowered = working.lowercased()
        var stripped = lowered
        for filler in fillers {
            stripped = stripped.replacingOccurrences(of: filler + " ", with: "")
        }
        stripped = stripped.trimmingCharacters(in: .whitespaces)
        guard !stripped.isEmpty else { return working }

        // Capitalize first letter; ensure it reads as an instruction.
        var result = stripped.prefix(1).uppercased() + stripped.dropFirst()
        if !result.hasSuffix(".") && !result.hasSuffix("?") {
            result += "."
        }
        return result
    }
}
