import Foundation

/// A change plan produced by the assistant. The user must approve it
/// before any file is written (unless auto-apply is enabled in settings).
struct AssistantPlan: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case proposed
        case approved
        case rejected
        case applied
    }

    let id: UUID
    var title: String
    var summary: String
    var steps: [String]
    var fileChanges: [FileChange]
    var status: Status

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        steps: [String] = [],
        fileChanges: [FileChange] = [],
        status: Status = .proposed
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.steps = steps
        self.fileChanges = fileChanges
        self.status = status
    }
}
