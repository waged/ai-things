import Foundation

/// A single planned change to a file, shown to the user before anything is written.
struct FileChange: Identifiable, Codable, Equatable {
    enum ChangeType: String, Codable {
        case create
        case modify
        case delete
    }

    let id: UUID
    var path: String
    var changeType: ChangeType
    /// Human-readable summary of what changes in this file.
    var summary: String
    /// Optional unified-diff preview.
    var diff: String?

    init(
        id: UUID = UUID(),
        path: String,
        changeType: ChangeType,
        summary: String,
        diff: String? = nil
    ) {
        self.id = id
        self.path = path
        self.changeType = changeType
        self.summary = summary
        self.diff = diff
    }

    var symbol: String {
        switch changeType {
        case .create: return "plus.circle"
        case .modify: return "pencil.circle"
        case .delete: return "minus.circle"
        }
    }
}
