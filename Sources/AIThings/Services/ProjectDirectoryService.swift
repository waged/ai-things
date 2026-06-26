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

    /// True if the directory contains any visible entries (i.e. a real project).
    func hasFiles(at dir: URL) -> Bool {
        !topLevelEntries(of: dir, limit: 1).isEmpty
    }

    private var marker: String { ".aithings/.initialized" }

    /// Whether the AI docs have already been scaffolded for this project.
    func isInitializedForAI(at dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(marker).path)
            || FileManager.default.fileExists(atPath: dir.appendingPathComponent("CLAUDE.md").path)
    }

    /// Scaffold the AI docs: `CLAUDE.md` (Markdown — the file Claude Code loads
    /// automatically as memory) plus rich HTML docs under `.aithings/`
    /// (status, architecture, features). Only creates missing files; never
    /// overwrites the user's content. Returns the names of files created.
    @discardableResult
    func scaffoldAIDocs(at dir: URL) -> [String] {
        var created: [String] = []
        let fm = FileManager.default
        let name = dir.lastPathComponent

        func writeIfMissing(_ relative: String, _ contents: String) {
            let url = dir.appendingPathComponent(relative)
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard !fm.fileExists(atPath: url.path) else { return }
            if (try? contents.write(to: url, atomically: true, encoding: .utf8)) != nil {
                created.append(relative)
            }
        }

        writeIfMissing("CLAUDE.md", Self.claudeTemplate(project: name))
        writeIfMissing(".aithings/status.html", Self.htmlDoc(project: name, title: "Status", body: Self.statusBody))
        writeIfMissing(".aithings/architecture.html", Self.htmlDoc(project: name, title: "Architecture", body: Self.architectureBody))
        writeIfMissing(".aithings/features.html", Self.htmlDoc(project: name, title: "Features", body: Self.featuresBody))

        // Marker so the init button only shows until it's been run.
        let markerURL = dir.appendingPathComponent(marker)
        try? fm.createDirectory(at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data().write(to: markerURL)
        return created
    }

    // MARK: - Templates

    private static func claudeTemplate(project: String) -> String {
        """
        # \(project)

        Project memory for Claude Code. Keep this file accurate and concise — it
        is loaded automatically at the start of every session.

        ## Overview
        _One or two sentences: what this project is and who it's for._

        ## Tech stack
        - Language / framework:
        - Key dependencies:

        ## Commands
        - Build:
        - Run:
        - Test:
        - Lint / format:

        ## Architecture
        _High-level structure: main modules and how they fit together._

        ## Conventions
        - Code style:
        - Branch / commit conventions:

        ## Living docs (keep these updated as the project evolves)
        - `.aithings/status.html` — current status & progress log
        - `.aithings/architecture.html` — components & data flow
        - `.aithings/features.html` — planned / in-progress / done features

        > When you make meaningful changes, update this file and the `.aithings/*`
        > HTML docs to reflect them.
        """
    }

    /// Shared HTML shell (brand-styled) for the `.aithings` docs.
    private static func htmlDoc(project: String, title: String, body: String) -> String {
        """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(project) — \(title)</title>
        <style>
          :root{color-scheme:dark}
          body{font:15px/1.55 -apple-system,system-ui,sans-serif;background:#0b1620;color:#e9f0f7;margin:0;padding:40px;max-width:820px}
          header{display:flex;align-items:center;gap:12px;margin-bottom:8px}
          .mark{width:34px;height:34px;border:3px solid #6bb0f0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#6bb0f0;font-size:12px}
          h1{font-weight:800;margin:0}
          h2{color:#6bb0f0;margin-top:1.8em}
          .muted{color:#8597a9}
          .card{background:#111e2b;border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:14px 20px;margin:12px 0}
          code{background:#16273a;padding:2px 6px;border-radius:5px}
          ul{padding-left:1.2em}
        </style></head><body>
          <header><div class="mark">AI</div><h1>\(project) — \(title)</h1></header>
          <p class="muted">Maintained by AI-Things · Claude Code keeps this current.</p>
        \(body)
        </body></html>
        """
    }

    private static let statusBody = """
          <div class="card"><h2>Idea</h2><p class="muted">What this project is and who it's for.</p></div>
          <div class="card"><h2>Current status</h2><p class="muted">Where things stand right now.</p></div>
          <div class="card"><h2>Progress log</h2><ul class="muted"><li>Initialized for AI.</li></ul></div>
          <div class="card"><h2>Next up</h2><ul class="muted"><li>…</li></ul></div>
        """

    private static let architectureBody = """
          <div class="card"><h2>Modules</h2><p class="muted">Main components and their responsibilities.</p></div>
          <div class="card"><h2>Data flow</h2><p class="muted">How data moves through the system.</p></div>
          <div class="card"><h2>External services</h2><p class="muted">APIs, databases, integrations.</p></div>
        """

    private static let featuresBody = """
          <div class="card"><h2>Done</h2><ul class="muted"><li>…</li></ul></div>
          <div class="card"><h2>In progress</h2><ul class="muted"><li>…</li></ul></div>
          <div class="card"><h2>Planned</h2><ul class="muted"><li>…</li></ul></div>
        """
}
