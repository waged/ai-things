import Foundation

/// Persists all chat sessions to disk as JSON in Application Support, so chats
/// survive relaunch and can be organized / archived per project.
///
/// One file holds every session; the UI filters by `projectPath`. Writes are
/// debounced so streaming a reply doesn't hammer the disk.
final class ChatStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "net.things-connect.aithings.chatstore", qos: .utility)
    private var pendingWork: DispatchWorkItem?

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AIThings", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("sessions.json")
    }

    func load() -> [ChatSession] {
        guard let data = try? Data(contentsOf: fileURL),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return []
        }
        return sessions
    }

    /// Save with a short debounce; the latest snapshot wins.
    func save(_ sessions: [ChatSession]) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [fileURL] in
            guard let data = try? JSONEncoder().encode(sessions) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Force an immediate, synchronous write (e.g. on quit) — blocks until the
    /// file is on disk so nothing is lost when the app exits.
    func saveNow(_ sessions: [ChatSession]) {
        pendingWork?.cancel()
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
