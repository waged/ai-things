import SwiftUI

/// Left sidebar: project, chats (with archive), git branch, tasks, recents.
struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false
    @State private var showArchived = false
    @State private var showBranchPicker = false
    @State private var diffFile: GitFileChange?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                projectSection
                if model.currentProject != nil { aiSetupSection }
                chatsSection
                branchSection
                moreSection
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

    // MARK: - AI setup

    private var aiSetupSection: some View {
        sidebarSection("AI Setup") {
            if model.projectInitialized {
                Label("Initialized for AI", systemImage: "checkmark.seal.fill")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.success)
                Button { model.updateProjectDocs() } label: {
                    Label("Update AI docs", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .disabled(model.isStreaming)
                Text("Refreshes CLAUDE.md & the status / architecture / features docs from the current code.")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button { model.initializeProjectForAI() } label: {
                    Label("Initialize for AI", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Theme.accent)
                .disabled(model.isStreaming)
                Text("Creates CLAUDE.md + status / architecture / features docs and fills them from your code.")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textSecondary)
            }
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
            Button { model.forkSession(chat.id) } label: {
                Label("New Chat from History", systemImage: "arrow.branch")
            }
            let targets = model.mergeTargets(for: chat)
            if !targets.isEmpty {
                Menu {
                    ForEach(targets.prefix(6)) { target in
                        Button(target.title.isEmpty ? "Untitled" : target.title) {
                            model.mergeSession(chat.id, into: target.id)
                        }
                    }
                } label: {
                    Label("Merge into…", systemImage: "arrow.triangle.merge")
                }
            }
            Divider()
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
                    Text("Uncommitted changes (\(model.changedFiles.count))")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.warning)
                    ForEach(model.changedFiles) { file in
                        changedFileRow(file)
                    }
                }
            } else {
                Text(model.isGitRepo ? "Detached HEAD" : "Not a git repository")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)
            }

            if model.isGitRepo {
                Button { showBranchPicker.toggle() } label: {
                    Label("Switch branch", systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .popover(isPresented: $showBranchPicker, arrowEdge: .trailing) {
                    BranchSwitcherView().environmentObject(model)
                }
            }
        }
        .sheet(item: $diffFile) { file in
            DiffViewerView(file: file).environmentObject(model)
        }
    }

    private func changedFileRow(_ file: GitFileChange) -> some View {
        Button {
            diffFile = file
        } label: {
            HStack(spacing: 7) {
                Text(file.badge)
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundStyle(statusColor(file))
                    .frame(width: 14, height: 14)
                    .background(statusColor(file).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(file.name)
                    .font(Theme.mono(10.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .help(file.path)
    }

    private func statusColor(_ file: GitFileChange) -> Color {
        switch file.badge {
        case "A", "U": return Theme.success
        case "D":      return Theme.danger
        case "R":      return Theme.highlight
        default:        return Theme.warning
        }
    }

    // MARK: - More

    private var moreSection: some View {
        sidebarSection("More") {
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
