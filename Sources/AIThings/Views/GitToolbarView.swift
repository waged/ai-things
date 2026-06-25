import SwiftUI

/// Horizontal git workflow toolbar. Destructive actions route through a
/// confirmation dialog when `confirmDestructiveActions` is enabled.
struct GitToolbarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showBranchCreator: Bool

    @State private var pendingConfirm: GitAction?
    @State private var showCommitSheet = false
    @State private var commitMessage = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(GitAction.allCases) { action in
                    button(for: action)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Theme.surface)
        .disabled(model.currentProject == nil)
        .confirmationDialog(
            pendingConfirm?.label ?? "",
            isPresented: confirmBinding,
            titleVisibility: .visible
        ) {
            Button(pendingConfirm?.label ?? "Confirm", role: .destructive) {
                if let action = pendingConfirm { perform(action) }
                pendingConfirm = nil
            }
            Button("Cancel", role: .cancel) { pendingConfirm = nil }
        } message: {
            Text("This is a destructive action and cannot be undone.")
        }
        .sheet(isPresented: $showCommitSheet) {
            commitSheet
        }
    }

    private func button(for action: GitAction) -> some View {
        Button {
            handle(action)
        } label: {
            Label(action.label, systemImage: action.symbol)
                .font(Theme.mono(11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(action.isDestructive ? Theme.danger : Theme.accent)
        .help(action.label)
    }

    // MARK: - Routing

    private func handle(_ action: GitAction) {
        if action.isDestructive && model.settings.confirmDestructiveActions {
            pendingConfirm = action
        } else {
            perform(action)
        }
    }

    private func perform(_ action: GitAction) {
        switch action {
        case .newBranch:        showBranchCreator = true
        case .feature:          model.startFeatureTask()
        case .bugFix:           model.startBugTask()
        case .commit:           showCommitSheet = true
        case .push:             model.push()
        case .pull:             model.pull()
        case .showChanges:      model.showChanges()
        case .discardChanges:   model.discardChanges()
        case .openInFinder:     model.openInFinder()
        case .openInXcode:      model.openInXcode()
        case .openTerminalHere: model.openTerminalHere()
        }
    }

    private var confirmBinding: Binding<Bool> {
        Binding(get: { pendingConfirm != nil }, set: { if !$0 { pendingConfirm = nil } })
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
                .disabled(commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(Theme.background)
    }
}
