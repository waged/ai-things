import SwiftUI
import AppKit

/// Central, @MainActor view model. Owns app state and coordinates the services.
/// All blocking work (shell, git, AI) runs in async tasks; only the resulting
/// state mutations happen on the main actor.
@MainActor
final class AppModel: ObservableObject {

    // MARK: - Published state

    @Published var settings: AppSettings { didSet { settingsService.save(settings) } }
    @Published var improvement = MessageImprovementSettings()

    /// The chat currently shown. Working copy; flushed into `sessions` by persist().
    @Published var session = ChatSession()
    /// Every saved chat across all projects (persisted to disk).
    @Published var sessions: [ChatSession] = []

    @Published var currentProject: ProjectDirectory?
    @Published var recentProjects: [ProjectDirectory] = []

    @Published var currentBranch: String?
    @Published var branches: [GitBranch] = []
    @Published var isGitRepo = false
    @Published var hasUncommittedChanges = false

    @Published var pendingAttachments: [UserAttachment] = []
    @Published var draft: String = ""

    @Published var isStreaming = false
    @Published var statusText = "Idle"

    /// Flipped to request the composer take focus (observed by the view).
    @Published var focusComposerRequested = false

    /// Recent user inputs for arrow-up/down recall in the composer.
    @Published private(set) var inputHistory: [String] = []

    // MARK: - Services

    private let settingsService = SettingsService()
    private let projectService = ProjectDirectoryService()
    private let attachmentService = AttachmentService()
    private let commandService = TerminalCommandService()
    private let chatStore = ChatStore()
    private let gitService: GitService
    private let aiService: AIService
    private let improver: MessageImprovementService

    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        let loaded = SettingsService().load()
        self.settings = loaded
        self.improvement = loaded.defaultImprovement
        self.gitService = GitService(commands: commandService)
        self.aiService = AIService(provider: MockAIProvider())
        self.improver = MessageImprovementService()
        self.recentProjects = projectService.recents()

        let saved = chatStore.load()
        let active = saved.filter { !$0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }
        if let latest = active.first {
            self.sessions = saved
            self.session = latest
        } else {
            let fresh = ChatSession()
            self.sessions = saved + [fresh]
            self.session = fresh
        }

        reloadProvider()
        if session.messages.isEmpty {
            appendSystem("Welcome to AI-Things — a graphical front-end for Claude Code. Open a project and start chatting.")
        }
    }

    var projectURL: URL? { currentProject?.url }

    // MARK: - AI provider

    /// (Re)build the active provider from settings. Creating a fresh Claude Code
    /// provider also starts a new CLI session.
    func reloadProvider() {
        switch settings.providerKind {
        case .claudeCode:
            aiService.setProvider(ClaudeCodeProvider(model: settings.modelName,
                                                     skipPermissions: settings.skipPermissions))
        case .mock:
            aiService.setProvider(MockAIProvider(chunkDelay: settings.mockStreamDelay))
        default:
            aiService.setProvider(MockAIProvider(chunkDelay: settings.mockStreamDelay))
            appendSystem("\(settings.providerKind.label) isn't wired up yet — using the offline mock. Switch to “Claude Code (CLI)” for real results.")
        }
    }

    // MARK: - Project handling

    func openProjectPicker() {
        guard let project = projectService.pickDirectory() else { return }
        selectProject(project)
    }

    func selectProject(_ project: ProjectDirectory) {
        currentProject = project
        projectService.remember(project)
        recentProjects = projectService.recents()
        reloadProvider() // fresh Claude session scoped to this project

        if session.messages.contains(where: { $0.role == .user }) {
            // Current chat already has real content — start a clean one for the project.
            startNewSession(projectPath: project.path, announce: false)
        } else {
            session.projectPath = project.path
        }
        appendSystem("Opened project: \(project.path)")
        persist()
        Task { await refreshGit() }
    }

    func refreshGit() async {
        guard let url = projectURL else { return }
        isGitRepo = await gitService.isRepository(at: url)
        guard isGitRepo else {
            currentBranch = nil
            branches = []
            statusText = "Not a git repository"
            return
        }
        currentBranch = await gitService.currentBranch(at: url)
        branches = await gitService.listBranches(at: url)
        hasUncommittedChanges = await gitService.hasUncommittedChanges(at: url)
        statusText = "Connected"
    }

    // MARK: - Chat session management

    /// Chats for the current project, newest first (active / archived split).
    var activeSessions: [ChatSession] {
        sessions.filter { !$0.isArchived && belongsToCurrentProject($0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    var archivedSessions: [ChatSession] {
        sessions.filter { $0.isArchived && belongsToCurrentProject($0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func belongsToCurrentProject(_ s: ChatSession) -> Bool {
        s.projectPath == currentProject?.path
    }

    func newChat() {
        startNewSession(projectPath: currentProject?.path, announce: true)
    }

    private func startNewSession(projectPath: String?, announce: Bool) {
        persist()
        let fresh = ChatSession(projectPath: projectPath)
        sessions.insert(fresh, at: 0)
        session = fresh
        if announce {
            appendSystem(currentProject == nil
                ? "New chat. Open a project to begin."
                : "New chat in \(currentProject?.name ?? "project").")
        }
        chatStore.save(sessions)
    }

    func selectSession(_ id: UUID) {
        guard id != session.id, let target = sessions.first(where: { $0.id == id }) else { return }
        persist()
        session = target
    }

    /// Empty the current chat but keep it in the list.
    func clearHistory() {
        session.messages.removeAll()
        appendSystem("Chat cleared.")
        persist()
    }

    func archiveSession(_ id: UUID) {
        setArchived(id, true)
        if id == session.id { switchToAnotherOrNew() }
    }

    func unarchiveSession(_ id: UUID) {
        setArchived(id, false)
        selectSession(id)
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if id == session.id { switchToAnotherOrNew() } else { chatStore.save(sessions) }
    }

    private func setArchived(_ id: UUID, _ value: Bool) {
        if session.id == id { session.isArchived = value }
        if let i = sessions.firstIndex(where: { $0.id == id }) { sessions[i].isArchived = value }
        chatStore.save(sessions)
    }

    private func switchToAnotherOrNew() {
        if let next = sessions.first(where: { $0.id != session.id && !$0.isArchived && belongsToCurrentProject($0) }) {
            session = next
            chatStore.save(sessions)
        } else {
            startNewSession(projectPath: currentProject?.path, announce: false)
        }
    }

    /// Flush the working chat into the persisted list and schedule a save.
    private func persist() {
        session.updatedAt = Date()
        session.title = session.derivedTitle
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        chatStore.save(sessions)
    }

    // MARK: - Sending messages

    func send() {
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty || !pendingAttachments.isEmpty else { return }

        let attachments = pendingAttachments
        draft = ""
        pendingAttachments = []
        if !raw.isEmpty { inputHistory.append(raw) }

        streamTask = Task { await runTurn(raw, attachments: attachments) }
    }

    private func runTurn(_ raw: String, attachments: [UserAttachment]) async {
        var messageText = raw

        // Optionally rewrite the user message to be clearer first.
        if improvement.makeClearer && !raw.isEmpty {
            statusText = "Improving message…"
            let improved = await improver.improve(raw)
            if improved != raw { appendSystem("Improved message → \(improved)") }
            messageText = improved
        }

        appendMessage(ChatMessage(role: .user, text: messageText, attachments: attachments))

        let context = await currentContext()
        let request = AIRequest(
            systemPrompt: aiService.systemPrompt(improvement: improvement, context: context,
                                                 autoApply: settings.autoApplyTrustedChanges),
            history: session.messages,
            userMessage: messageText,
            context: context,
            appendSystemPrompt: behaviorDirectives()
        )
        await streamAssistant(request)
    }

    private func streamAssistant(_ request: AIRequest) async {
        isStreaming = true
        statusText = "Thinking…"
        defer {
            isStreaming = false
            statusText = isGitRepo ? "Connected" : "Idle"
            persist()
            Task { await refreshGit() } // reflect any edits/commits the AI made
        }

        var assistant = ChatMessage(role: .assistant, text: "")
        appendMessage(assistant)
        let id = assistant.id

        do {
            for try await chunk in aiService.stream(request) {
                if Task.isCancelled { break }
                assistant.text += chunk
                updateMessage(id: id, text: assistant.text)
            }
        } catch {
            appendMessage(ChatMessage(role: .assistant, kind: .errorOutput,
                                      text: "Error: \(error.localizedDescription)"))
        }
    }

    func cancelStreaming() {
        streamTask?.cancel()
        isStreaming = false
        statusText = "Cancelled"
    }

    /// Concise behavior directives derived from the composer toggles. Passed to
    /// the Claude Code CLI via --append-system-prompt.
    private func behaviorDirectives() -> String {
        var d = ["Respond in short, scannable bullet points.", "Focus on the software task."]
        if improvement.directMode {
            d.append("Be concise; minimal prose; prioritize concrete code changes and commands.")
        }
        if improvement.askQuestionsFirst {
            d.append("If the request is ambiguous, ask brief clarifying questions before editing files.")
        }
        return d.joined(separator: " ")
    }

    private func currentContext() async -> ProjectContext {
        var files: [String] = []
        if let url = projectURL {
            files = projectService.topLevelEntries(of: url).map { $0.lastPathComponent }
        }
        return ProjectContext(path: currentProject?.path, branch: currentBranch, topLevelFiles: files)
    }

    // MARK: - Quick task modes

    func startFeatureTask() {
        improvement.askQuestionsFirst = true
        appendSystem("Feature mode. Describe the feature you want to build. I'll suggest a feature branch.")
        focusComposerRequested.toggle()
    }

    func startBugTask() {
        improvement.askQuestionsFirst = true
        appendSystem("Bug-fix mode. Describe the bug to fix. I'll suggest a bugfix branch and focus on reproducing it.")
        focusComposerRequested.toggle()
    }

    // MARK: - Git actions

    func createBranch(kind: BranchKind, name: String) {
        let formatted = Self.formatBranchName(kind: kind, name: name)
        guard !formatted.isEmpty else { return }
        runGit("Creating branch \(formatted)") { [gitService, projectURL] in
            try await gitService.createBranch(formatted, at: projectURL)
        }
    }

    func commit(message: String) {
        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        runGit("Committing") { [gitService, projectURL] in
            try await gitService.commit(message: msg, at: projectURL)
        }
    }

    func push()  { runGit("Pushing")  { [gitService, projectURL] in try await gitService.push(at: projectURL) } }
    func pull()  { runGit("Pulling")  { [gitService, projectURL] in try await gitService.pull(at: projectURL) } }

    func showChanges() {
        runGit("Showing changes") { [gitService, projectURL] in try await gitService.status(at: projectURL) }
    }

    func discardChanges() {
        runGit("Discarding changes") { [gitService, projectURL] in try await gitService.discardChanges(at: projectURL) }
    }

    func openInFinder() {
        guard let url = projectURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openInXcode() {
        guard let url = projectURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        if let xcode = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
            NSWorkspace.shared.open([url], withApplicationAt: xcode, configuration: config)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func openTerminalHere() {
        guard let url = projectURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        if let term = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.open([url], withApplicationAt: term, configuration: config)
        }
    }

    /// Run a git operation, capture output into the chat, refresh state.
    private func runGit(_ label: String, _ operation: @escaping () async throws -> CommandResult) {
        Task {
            statusText = label + "…"
            appendSystem("$ \(label)")
            do {
                let result = try await operation()
                let text = result.combined.isEmpty ? "(done)" : result.combined
                appendMessage(ChatMessage(role: .system,
                                          kind: result.succeeded ? .commandOutput : .errorOutput,
                                          text: text))
            } catch {
                appendMessage(ChatMessage(role: .system, kind: .errorOutput, text: error.localizedDescription))
            }
            persist()
            await refreshGit()
        }
    }

    // MARK: - Attachments

    func pasteFromClipboard() {
        let images = attachmentService.attachmentsFromPasteboard()
        if !images.isEmpty {
            pendingAttachments.append(contentsOf: images)
        } else if let text = attachmentService.pasteboardText() {
            draft += (draft.isEmpty ? "" : "\n") + text
        }
    }

    func attachImage() {
        if let attachment = attachmentService.pickImage() { pendingAttachments.append(attachment) }
    }

    func attachFile() {
        if let attachment = attachmentService.pickFile() { pendingAttachments.append(attachment) }
    }

    func referenceProjectFiles() {
        guard let url = projectURL else {
            appendSystem("Open a project first to reference its files.")
            return
        }
        let names = projectService.topLevelEntries(of: url).prefix(10).map { $0.lastPathComponent }
        for name in names {
            pendingAttachments.append(UserAttachment(kind: .filePath, name: name,
                                                     path: url.appendingPathComponent(name).path))
        }
    }

    func handleDrop(urls: [URL]) {
        for url in urls { pendingAttachments.append(attachmentService.attachment(for: url)) }
    }

    func removeAttachment(_ attachment: UserAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    // MARK: - Plan approval (used by the mock provider)

    func approvePlan(messageID: UUID) {
        updatePlanStatus(messageID: messageID, status: .applied)
        appendSystem("Plan approved (mock).")
        persist()
    }

    func rejectPlan(messageID: UUID) {
        updatePlanStatus(messageID: messageID, status: .rejected)
        appendSystem("Plan rejected. No files changed.")
        persist()
    }

    // MARK: - Helpers

    private func appendSystem(_ text: String) {
        appendMessage(ChatMessage(role: .system, kind: .system, text: text))
    }

    private func appendMessage(_ message: ChatMessage) {
        session.messages.append(message)
    }

    private func updateMessage(id: UUID, text: String) {
        guard let index = session.messages.firstIndex(where: { $0.id == id }) else { return }
        session.messages[index].text = text
    }

    private func updatePlanStatus(messageID: UUID, status: AssistantPlan.Status) {
        guard let index = session.messages.firstIndex(where: { $0.id == messageID }) else { return }
        session.messages[index].plan?.status = status
    }

    /// Turn a kind + free text into a formatted git branch name.
    /// e.g. (.feature, "Login Screen") -> "feature/login-screen"
    static func formatBranchName(kind: BranchKind, name: String) -> String {
        let slug = name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return slug.isEmpty ? "" : kind.prefix + slug
    }
}
