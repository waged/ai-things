import SwiftUI

/// Standalone project picker: open a new directory or jump to a recent one.
/// Shown as a welcome panel; also reusable from menus.
struct ProjectPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var embedded = false

    var body: some View {
        VStack(spacing: 18) {
            LogoView(size: .regular)

            Text("Open a project to start")
                .font(Theme.mono(13))
                .foregroundStyle(Theme.textSecondary)

            Button {
                model.openProjectPicker()
                if !embedded { dismiss() }
            } label: {
                Label("Choose Directory…", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)

            if !model.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECENT")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(model.recentProjects) { project in
                        Button {
                            model.selectProject(project)
                            if !embedded { dismiss() }
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name).font(Theme.mono(12, weight: .semibold))
                                    Text(project.path)
                                        .font(Theme.mono(9))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .terminalCard()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: embedded ? nil : 420)
        .background(Theme.background)
    }
}
