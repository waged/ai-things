import SwiftUI

/// Top header: logo, project name, git branch, status indicator, new chat.
/// (Feedback + Settings live in the window's top-right toolbar.)
struct HeaderBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            LogoView(size: .regular)

            Divider().frame(height: 18).overlay(Theme.border)

            // Project name
            Label(model.currentProject?.name ?? "No project",
                  systemImage: "folder")
                .font(Theme.mono(12))
                .foregroundStyle(model.currentProject == nil ? Theme.textSecondary : Theme.textPrimary)

            // Git branch
            if let branch = model.currentBranch {
                Label(branch, systemImage: "arrow.branch")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.highlight)
            }

            Spacer()

            statusIndicator

            Button {
                model.newChat()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .help("New chat")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(model.statusText)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceElevated)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        if model.isStreaming { return Theme.warning }
        if model.isGitRepo { return Theme.success }
        return Theme.textSecondary
    }
}
