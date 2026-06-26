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

    /// Check out an existing branch.
    func checkout(branch: String, at dir: URL?) async throws -> CommandResult {
        try await commands.run("git checkout \(branch.shellQuoted)", in: dir)
    }

    /// Merge `branch` into `base` (checks out base first; leaves you on base).
    func merge(branch: String, into base: String, at dir: URL?) async throws -> CommandResult {
        try await commands.run(
            "git checkout \(base.shellQuoted) && git merge --no-edit \(branch.shellQuoted)",
            in: dir
        )
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

    /// Files with uncommitted changes (staged, unstaged, and untracked).
    func changedFiles(at dir: URL?) async -> [GitFileChange] {
        guard let result = try? await commands.run("git status --porcelain", in: dir),
              result.succeeded else { return [] }
        return result.standardOutput.split(separator: "\n").compactMap { line in
            guard line.count >= 4 else { return nil }
            let code = String(line.prefix(2))
            var path = String(line.dropFirst(3))
            if let range = path.range(of: " -> ") { path = String(path[range.upperBound...]) } // renames
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) // quoted paths
            return GitFileChange(status: code, path: path)
        }
    }

    /// Diff for a single file vs HEAD (covers staged + unstaged).
    func diff(file: String, at dir: URL?) async throws -> CommandResult {
        try await commands.run("git --no-pager diff HEAD -- \(file.shellQuoted)", in: dir)
    }

    /// Commits ahead of / behind the upstream branch. `hasUpstream` is false
    /// when the branch has no tracking remote (so Push/Pull aren't meaningful yet).
    func aheadBehind(at dir: URL?) async -> (ahead: Int, behind: Int, hasUpstream: Bool) {
        guard let result = try? await commands.run(
            "git rev-list --left-right --count @{upstream}...HEAD", in: dir
        ), result.succeeded else {
            return (0, 0, false)
        }
        // Output is "<behind>\t<ahead>".
        let numbers = result.standardOutput
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .compactMap { Int($0) }
        guard numbers.count == 2 else { return (0, 0, false) }
        return (ahead: numbers[1], behind: numbers[0], hasUpstream: true)
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
