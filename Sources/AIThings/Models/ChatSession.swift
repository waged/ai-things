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
    /// The Claude Code CLI session id, so reopening this chat resumes its context.
    var claudeSessionID: String?
    /// When this chat was last made active / prompted in — used to reopen the
    /// genuinely last-used chat (independent of `updatedAt`, which other actions bump).
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        projectPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        claudeSessionID: String? = nil,
        lastOpenedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.projectPath = projectPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.claudeSessionID = claudeSessionID
        self.lastOpenedAt = lastOpenedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, messages, projectPath, createdAt, updatedAt, isArchived, claudeSessionID, lastOpenedAt
    }

    // Tolerant decoding so adding fields never wipes saved chats.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? "New Chat"
        messages = (try? c.decode([ChatMessage].self, forKey: .messages)) ?? []
        projectPath = try? c.decode(String.self, forKey: .projectPath)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? createdAt
        isArchived = (try? c.decode(Bool.self, forKey: .isArchived)) ?? false
        claudeSessionID = try? c.decode(String.self, forKey: .claudeSessionID)
        lastOpenedAt = (try? c.decode(Date.self, forKey: .lastOpenedAt)) ?? updatedAt
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
