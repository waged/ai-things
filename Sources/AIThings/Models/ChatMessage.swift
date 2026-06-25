import Foundation

/// Who authored a message in the conversation.
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

/// The visual / semantic kind of a message, used by the terminal renderer.
enum MessageKind: String, Codable {
    case normal          // regular chat text (may contain ``` code fences)
    case commandOutput   // captured stdout from a shell command
    case errorOutput     // captured stderr / non-zero exit
    case plan            // an assistant change plan awaiting approval
    case system          // status / informational lines
}

/// A single line in the terminal-style conversation.
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: MessageRole
    var kind: MessageKind
    var text: String
    var attachments: [UserAttachment]
    var plan: AssistantPlan?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        kind: MessageKind = .normal,
        text: String,
        attachments: [UserAttachment] = [],
        plan: AssistantPlan? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.kind = kind
        self.text = text
        self.attachments = attachments
        self.plan = plan
        self.timestamp = timestamp
    }
}
