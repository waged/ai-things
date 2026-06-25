import Foundation

/// A project folder the user has opened. Persisted in the recents list.
struct ProjectDirectory: Identifiable, Codable, Hashable {
    var id: String { path }
    let path: String
    var lastOpened: Date

    /// Security-scoped bookmark so access survives relaunch (used when sandboxed).
    var bookmark: Data?

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    init(path: String, lastOpened: Date = Date(), bookmark: Data? = nil) {
        self.path = path
        self.lastOpened = lastOpened
        self.bookmark = bookmark
    }
}
