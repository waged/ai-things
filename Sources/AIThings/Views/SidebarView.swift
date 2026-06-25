import SwiftUI

/// Left sidebar: project, chats (with archive), git branch, tasks, recents.
struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showBranchCreator: Bool
    @State private var showSettings = false
    @State private var showArchived = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                projectSection
                chatsSection
                branchSection
                quickTasksSection
                recentsSection
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .background(Theme.surface)
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
    }

    // MARK: - Project

    private var projectSection: some View {
        sidebarSection("Project") {
            if let project = model.currentProject {
                Text(project.name)
                    .font(Theme.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(project.path)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else {
                Text("No project selected")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)
            }

            Button {
                model.openProjectPicker()
            } label: {
                Label(model.currentProject == nil ? "Open Project" : "Change Project",
                      systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
    }

    // MARK: - Chats

    private var chatsSection: some View {
        sidebarSection("Chats") {
            Button {
                model.newChat()
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)

            if model.activeSessions.isEmpty {
                Text("No chats yet")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(model.activeSessions) { chat in
                    chatRow(chat)
                }
            }

            if !model.archivedSessions.isEmpty {
                DisclosureGroup(isExpanded: $showArchived) {
                    ForEach(model.archivedSessions) { chat in
                        chatRow(chat, archived: true)
                    }
                } label: {
                    Text("Archived (\(model.archivedSessions.count))")
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .tint(Theme.highlight)
            }
        }
    }

    private func chatRow(_ chat: ChatSession, archived: Bool = false) -> some View {
        let isCurrent = chat.id == model.session.id
        return Button {
            model.selectSession(chat.id)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isCurrent ? "bubble.left.fill" : "bubble.left")
                    .font(.system(size: 10))
                Text(chat.title.isEmpty ? "New Chat" : chat.title)
                    .font(Theme.mono(11))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCurrent ? Theme.accent.opacity(0.22) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isCurrent ? Theme.textPrimary : Theme.textSecondary)
        .contextMenu {
            if archived {
                Button { model.unarchiveSession(chat.id) } label: { Label("Unarchive", systemImage: "tray.and.arrow.up") }
            } else {
                Button { model.archiveSession(chat.id) } label: { Label("Archive", systemImage: "archivebox") }
            }
            Button(role: .destructive) { model.deleteSession(chat.id) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Branch

    private var branchSection: some View {
        sidebarSection("Git Branch") {
            if let branch = model.currentBranch {
                Label(branch, systemImage: "arrow.branch")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.highlight)
                if model.hasUncommittedChanges {
                    Text("Uncommitted changes")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.warning)
                }
            } else {
                Text(model.isGitRepo ? "Detached HEAD" : "Not a git repository")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Button {
                showBranchCreator = true
            } label: {
                Label("New Branch", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .disabled(model.currentProject == nil)
        }
    }

    // MARK: - Quick tasks

    private var quickTasksSection: some View {
        sidebarSection("Tasks") {
            Button { model.startFeatureTask() } label: {
                Label("Feature Request", systemImage: "sparkles").frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).foregroundStyle(Theme.textPrimary)

            Button { model.startBugTask() } label: {
                Label("Bug Fix", systemImage: "ant").frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).foregroundStyle(Theme.textPrimary)

            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Recents

    private var recentsSection: some View {
        sidebarSection("Recent Projects") {
            if model.recentProjects.isEmpty {
                Text("None yet")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(model.recentProjects) { project in
                    Button {
                        model.selectProject(project)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text(project.name).lineLimit(1)
                            Spacer()
                        }
                        .font(Theme.mono(11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(project.path == model.currentProject?.path ? Theme.highlight : Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Theme.mono(10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}
