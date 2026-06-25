import Foundation

/// Wraps git porcelain commands for the selected project directory.
/// All methods are async and run off the main thread via TerminalCommandService.
final class GitService {
    private let commands: TerminalCommandService

    init(commands: TerminalCommandService) {
        self.commands = commands
    }

    /// True if the directory is inside a git work tree.
    func isRepository(at dir: URL?) async -> Bool {
        guard let result = try? await commands.run("git rev-parse --is-inside-work-tree", in: dir) else {
            return false
        }
        return result.succeeded && result.standardOutput.contains("true")
    }

    /// The current branch name, or nil if not in a repo / detached.
    func currentBranch(at dir: URL?) async -> String? {
        guard let result = try? await commands.run("git rev-parse --abbrev-ref HEAD", in: dir),
              result.succeeded else { return nil }
        let name = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// All local + remote branches, flagged with current/remote.
    func listBranches(at dir: URL?) async -> [GitBranch] {
        guard let result = try? await commands.run(
            "git branch -a --format='%(HEAD)|%(refname:short)'", in: dir
        ), result.succeeded else { return [] }

        return result.standardOutput
            .split(separator: "\n")
            .compactMap { line -> GitBranch? in
                let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                let isCurrent = parts[0].trimmingCharacters(in: .whitespaces) == "*"
                let name = parts[1].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                return GitBranch(name: name, isCurrent: isCurrent, isRemote: name.hasPrefix("remotes/"))
            }
    }

    /// Create and check out a new branch.
    func createBranch(_ name: String, at dir: URL?) async throws -> CommandResult {
        try await commands.run("git checkout -b \(name.shellQuoted)", in: dir)
    }

    /// Short status (porcelain) output.
    func status(at dir: URL?) async throws -> CommandResult {
        try await commands.run("git status --short --branch", in: dir)
    }

    /// True if there are staged or unstaged changes.
    func hasUncommittedChanges(at dir: URL?) async -> Bool {
        guard let result = try? await commands.run("git status --porcelain", in: dir) else { return false }
        return !result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func diff(at dir: URL?) async throws -> CommandResult {
        try await commands.run("git --no-pager diff", in: dir)
    }

    func pull(at dir: URL?) async throws -> CommandResult {
        try await commands.run("git pull --ff-only", in: dir)
    }

    func push(at dir: URL?) async throws -> CommandResult {
        // Sets upstream automatically for new branches.
        try await commands.run("git push -u origin HEAD", in: dir)
    }

    func commit(message: String, at dir: URL?) async throws -> CommandResult {
        try await commands.run("git add -A && git commit -m \(message.shellQuoted)", in: dir)
    }

    /// Destructive: discards all uncommitted changes.
    func discardChanges(at dir: URL?) async throws -> CommandResult {
        try await commands.run("git reset --hard && git clean -fd", in: dir)
    }
}

extension String {
    /// Single-quote a string for safe use as one shell argument.
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
