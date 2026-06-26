import Foundation

/// One entry from `git status --porcelain`: a changed file and its status.
struct GitFileChange: Identifiable, Hashable {
    var id: String { path }
    /// Raw two-character XY status (e.g. " M", "??", "A ", "D ", "MM").
    let status: String
    let path: String

    var name: String { (path as NSString).lastPathComponent }
    var isUntracked: Bool { status.contains("?") }

    /// Single-letter badge: U(ntracked), M, A, D, R…
    var badge: String {
        if isUntracked { return "U" }
        let trimmed = status.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "•" : String(trimmed.prefix(1))
    }
}
