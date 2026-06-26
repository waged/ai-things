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
    /// Conservative cleanup that preserves meaning, line breaks, proper nouns
    /// and code — it tidies rather than rewrites. Leading filler phrases are
    /// removed, whitespace is normalized, casing/punctuation lightly fixed.
    static func heuristicRewrite(_ text: String) -> String {
        // Filler phrases removed only at the start of a line (case-insensitive).
        let leadFillers = [
            "i was wondering if you could ", "i would like you to ", "i would like to ",
            "could you please ", "can you please ", "could you ", "can you ",
            "i want you to ", "i want to ", "i need you to ", "i need to ",
            "please ", "kindly ", "i was hoping you could ", "would you mind "
        ]

        let lines = text.components(separatedBy: "\n").map { rawLine -> String in
            // Collapse runs of spaces/tabs; trim ends.
            var line = rawLine
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !line.isEmpty else { return "" }

            // Strip a leading filler phrase if present.
            for filler in leadFillers where line.lowercased().hasPrefix(filler) {
                line = String(line.dropFirst(filler.count))
                break
            }
            guard !line.isEmpty else { return "" }

            // Standalone "i" -> "I".
            line = line.replacingOccurrences(of: #"\bi\b"#, with: "I", options: .regularExpression)

            // Capitalize the first letter without touching the rest.
            line = line.prefix(1).uppercased() + line.dropFirst()
            return line
        }

        var result = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return text }

        // Ensure a single-line instruction ends with punctuation.
        if !result.contains("\n") {
            let last = result.last!
            if !".?!:".contains(last) { result += "." }
        }
        return result
    }
}
