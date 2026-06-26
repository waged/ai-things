import SwiftUI

/// Compact, contextual Git bar. Primary actions appear only when they're
/// actionable (changes to commit, commits to push/pull); everything else lives
/// in an overflow menu. The goal is to stay out of the way.
struct GitToolbarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showBranchCreator: Bool

    @State private var pendingDiscard = false
    @State private var pendingMerge = false
    @State private var showCommitSheet = false
    @State private var commitMessage = ""

    var body: some View {
        HStack(spacing: 8) {
            if model.currentProject == nil {
                hint("Open a project to enable Git tools")
                Spacer()
            } else if !model.isGitRepo {
                hint("Not a git repository")
                Spacer()
                overflowMenu
            } else {
                branchChip
                contextualActions
                Spacer()
                overflowMenu
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.surface)
        .confirmationDialog("Discard all uncommitted changes?",
                            isPresented: $pendingDiscard, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) { model.discardChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently discards uncommitted changes and cannot be undone.")
        }
        .confirmationDialog(mergeTitle, isPresented: $pendingMerge, titleVisibility: .visible) {
            Button("Merge", role: .none) { model.mergeCurrentIntoBase() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Checks out \(model.baseBranch ?? "the base branch") and merges the current branch into it.")
        }
        .sheet(isPresented: $showCommitSheet) { commitSheet }
    }

    // MARK: - Pieces

    private func hint(_ text: String) -> some View {
        Text(text).font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
    }

    private var mergeTitle: String {
        "Merge \(model.currentBranch ?? "branch") into \(model.baseBranch ?? "base")?"
    }

    private var branchChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.branch")
            Text(model.currentBranch ?? "—").lineLimit(1)
        }
        .font(Theme.mono(11, weight: .medium))
        .foregroundStyle(Theme.highlight)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Theme.surfaceElevated)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var contextualActions: some View {
        if model.hasUncommittedChanges {
            pill("Commit", "checkmark.seal") { model.commitAuto() }
        }
        if model.hasUpstream {
            if model.aheadCount > 0 {
                pill("Push \(model.aheadCount)", "arrow.up.circle") { model.push() }
            }
            if model.behindCount > 0 {
                pill("Pull \(model.behindCount)", "arrow.down.circle") { model.pull() }
            }
        } else {
            // No tracking branch yet — offer to publish it.
            pill("Publish branch", "arrow.up.circle") { model.push() }
        }
        if model.canMergeToBase, let base = model.baseBranch {
            pill("Merge → \(base)", "arrow.triangle.merge") { pendingMerge = true }
        }
        if isClean {
            Text("✓ up to date").font(Theme.mono(10)).foregroundStyle(Theme.textSecondary)
        }
    }

    private var isClean: Bool {
        !model.hasUncommittedChanges && model.hasUpstream
            && model.aheadCount == 0 && model.behindCount == 0
    }

    private func pill(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(Theme.mono(11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Theme.accent)
    }

    private var overflowMenu: some View {
        Menu {
            Button { showBranchCreator = true } label: { Label("New Branch…", systemImage: "arrow.branch") }
            if model.isGitRepo {
                Button { model.showChanges() } label: { Label("Show Changes", systemImage: "doc.text.magnifyingglass") }
                if model.hasUncommittedChanges {
                    Button { model.commitAuto() } label: { Label("Commit (auto message)", systemImage: "checkmark.seal") }
                    Button { showCommitSheet = true } label: { Label("Commit with message…", systemImage: "pencil") }
                    Button(role: .destructive) {
                        if model.settings.confirmDestructiveActions { pendingDiscard = true } else { model.discardChanges() }
                    } label: { Label("Discard Changes", systemImage: "trash") }
                }
                Divider()
                Button { model.pull() } label: { Label("Pull", systemImage: "arrow.down.circle") }
                Button { model.push() } label: { Label("Push", systemImage: "arrow.up.circle") }
                Divider()
            }
            Button { model.openInFinder() } label: { Label("Open in Finder", systemImage: "folder") }
            Button { model.openInXcode() } label: { Label("Open in Xcode", systemImage: "hammer") }
            Button { model.openTerminalHere() } label: { Label("Open Terminal Here", systemImage: "terminal") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(Theme.textSecondary)
        .help("More Git actions")
    }

    // MARK: - Commit sheet

    private var commitSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commit Changes")
                .font(Theme.mono(14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            TextField("Commit message", text: $commitMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Spacer()
                Button("Cancel") { showCommitSheet = false }
                Button("Commit") {
                    model.commit(message: commitMessage)
                    commitMessage = ""
                    showCommitSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(Theme.background)
    }
}
