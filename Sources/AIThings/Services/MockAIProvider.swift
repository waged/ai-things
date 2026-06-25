import Foundation

/// Offline provider used for the prototype. Produces realistic, bullet-style
/// responses and, when the request looks like an edit, a sample change plan.
/// No network, no API key.
final class MockAIProvider: AIProvider {
    let displayName = "Mock (offline)"
    private let chunkDelay: Double

    init(chunkDelay: Double = 0.012) {
        self.chunkDelay = chunkDelay
    }

    func streamMessage(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        let reply = Self.reply(for: request)
        let delay = chunkDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                // Stream word-by-word to mimic token streaming.
                for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
                    if Task.isCancelled { break }
                    continuation.yield(String(word) + " ")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in streamMessage(request) { text += chunk }
        return AIResponse(text: text.trimmingCharacters(in: .whitespaces),
                          plan: Self.plan(for: request))
    }

    // MARK: - Canned reasoning

    private static func reply(for request: AIRequest) -> String {
        let msg = request.userMessage.lowercased()
        let branch = request.context.branch ?? "main"

        if msg.contains("?") || msg.count < 12 {
            return """
            I need a little more detail before I touch any files:
            • Which part of the project should this affect?
            • Do you want new files or edits to existing ones?
            • Any constraints (framework, style, tests)?
            """
        }

        if msg.contains("bug") || msg.contains("crash") || msg.contains("fix") {
            return """
            Bug-fix mode. Here is how I'll approach it:
            • Reproduce the issue and read the relevant files
            • Identify the root cause (not just the symptom)
            • Propose a minimal fix on branch `\(branch)`
            • Add or update a test to lock the behavior
            A plan with the affected files is attached below for your approval.
            """
        }

        if msg.contains("feature") || msg.contains("add") || msg.contains("build") || msg.contains("implement") {
            return """
            Feature mode. Proposed steps:
            • Confirm scope and acceptance criteria
            • Add the new view/model/service in small components
            • Wire it into the existing flow
            • Keep changes isolated on a feature branch
            A change plan is attached below for your approval.
            """
        }

        return """
        Here's my read of the task:
        • Working inside `\(request.context.path ?? "the project")` on `\(branch)`
        • I'll inspect only the files needed for this change
        • Then I'll show a plan before editing anything
        Tell me to proceed and I'll generate the change plan.
        """
    }

    /// Attach a sample plan for edit-like requests so the approval flow is demoable.
    private static func plan(for request: AIRequest) -> AssistantPlan? {
        let msg = request.userMessage.lowercased()
        let editLike = ["add", "build", "implement", "fix", "create", "refactor", "change", "update"]
        guard editLike.contains(where: { msg.contains($0) }) else { return nil }

        let isBug = msg.contains("bug") || msg.contains("fix") || msg.contains("crash")
        return AssistantPlan(
            title: isBug ? "Fix reported issue" : "Implement requested change",
            summary: isBug
                ? "Minimal fix targeting the root cause, with a regression test."
                : "Add the requested functionality in small, isolated components.",
            steps: [
                "Read the affected files",
                isBug ? "Patch the root cause" : "Add new component(s)",
                "Wire into existing flow",
                "Verify build / tests"
            ],
            fileChanges: [
                FileChange(path: "Sources/Example/Feature.swift",
                           changeType: .create,
                           summary: "New component implementing the request",
                           diff: "+ struct Feature: View { /* ... */ }"),
                FileChange(path: "Sources/Example/RootView.swift",
                           changeType: .modify,
                           summary: "Wire the new component into the root view",
                           diff: "  VStack {\n+   Feature()\n  }")
            ]
        )
    }
}
