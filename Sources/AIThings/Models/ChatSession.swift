import Foundation

/// A conversation bound to a single project directory. Persisted by ChatStore.
struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var projectPath: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        projectPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.projectPath = projectPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    /// First non-empty user message, used to auto-name a chat.
    var derivedTitle: String {
        if let first = messages.first(where: { $0.role == .user && !$0.text.isEmpty }) {
            let line = first.text.split(separator: "\n").first.map(String.init) ?? first.text
            return String(line.prefix(48))
        }
        return title
    }

    /// Messages excluding pure status/system noise — used for the list subtitle.
    var lastMeaningfulText: String? {
        messages.last(where: { $0.role != .system && !$0.text.isEmpty })?.text
    }
}
