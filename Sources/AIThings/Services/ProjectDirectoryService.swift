import Foundation
import AppKit

/// Manages choosing a project directory, remembering recents, and lightweight,
/// on-demand reads of project files. Never loads the whole project into memory.
final class ProjectDirectoryService {
    private let defaults: UserDefaults
    private let recentsKey = "project.recents.v1"
    private let maxRecents = 8

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Picking

    /// Show the native directory picker. Returns the chosen directory or nil.
    @MainActor
    func pickDirectory() -> ProjectDirectory? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Project"
        panel.message = "Choose a software project directory"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let bookmark = try? url.bookmarkData(options: .withSecurityScope)
        let project = ProjectDirectory(path: url.path, bookmark: bookmark)
        remember(project)
        return project
    }

    // MARK: - Recents

    func recents() -> [ProjectDirectory] {
        guard let data = defaults.data(forKey: recentsKey),
              let list = try? JSONDecoder().decode([ProjectDirectory].self, from: data) else {
            return []
        }
        return list.sorted { $0.lastOpened > $1.lastOpened }
    }

    func remember(_ project: ProjectDirectory) {
        var list = recents().filter { $0.path != project.path }
        var updated = project
        updated.lastOpened = Date()
        list.insert(updated, at: 0)
        if list.count > maxRecents { list = Array(list.prefix(maxRecents)) }
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: recentsKey)
        }
    }

    func clearRecents() {
        defaults.removeObject(forKey: recentsKey)
    }

    // MARK: - On-demand reads

    /// Shallow listing of the directory (one level), skipping noisy folders.
    func topLevelEntries(of dir: URL, limit: Int = 200) -> [URL] {
        let skip: Set<String> = [".git", ".build", "node_modules", "DerivedData", ".DS_Store"]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents
            .filter { !skip.contains($0.lastPathComponent) }
            .prefix(limit)
            .map { $0 }
    }

    /// Read a single file's text, capped to avoid loading huge files into memory.
    func readFile(at url: URL, maxBytes: Int = 200_000) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: maxBytes)) ?? Data()
        return String(data: data, encoding: .utf8)
    }
}
