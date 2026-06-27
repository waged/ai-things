import SwiftUI
import AppKit
import NaturalLanguage

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
    /// Whether the current project has had its AI docs scaffolded.
    @Published var projectInitialized = false

    @Published var currentBranch: String?
    @Published var branches: [GitBranch] = []
    @Published var isGitRepo = false
    @Published var hasUncommittedChanges = false
    @Published var changedFiles: [GitFileChange] = []
    @Published var aheadCount = 0
    @Published var behindCount = 0
    @Published var hasUpstream = false

    /// When the user starts a Feature/Bug task, their next message auto-creates
    /// the matching branch (named from the text). Idle otherwise.
    enum TaskMode { case none, feature, bug }
    @Published var taskMode: TaskMode = .none

    @Published var pendingAttachments: [UserAttachment] = []
    @Published var draft: String = ""

    /// Sessions with a turn currently streaming. Chats run in parallel, each
    /// bound to its own chat, so output never leaks between them.
    @Published private(set) var streamingSessions: Set<UUID> = []
    /// True only when the chat currently on screen is one that's streaming.
    var isStreaming: Bool { streamingSessions.contains(session.id) }
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
    private let matcher = TopicMatcher()

    /// In-flight turns, keyed by the chat they belong to, so chats stream in
    /// parallel and cancelling one never touches another.
    private var streamTasks: [UUID: Task<Void, Never>] = [:]

    /// Where each in-flight turn is working (project + branch), so we can warn
    /// when two agents run on the SAME working tree. `turnGeneration` guards the
    /// cleanup so a cancelled turn never clears a newer one's entry.
    private var activeTurns: [UUID: (path: String?, branch: String?)] = [:]
    private var turnGeneration: [UUID: Int] = [:]

    /// Register a starting turn for `sid`; returns its generation token.
    private func beginTurn(_ sid: UUID) -> Int {
        let gen = (turnGeneration[sid] ?? 0) + 1
        turnGeneration[sid] = gen
        activeTurns[sid] = (currentProject?.path, currentBranch)
        return gen
    }

    private func endTurn(_ sid: UUID, gen: Int) {
        if turnGeneration[sid] == gen { activeTurns[sid] = nil }
    }

    /// Warn (in the chat) when another chat is already running an agent on the
    /// same project AND branch — different branches are independent, so no warning.
    private func warnIfConcurrentAgent(for sid: UUID) {
        guard let mine = activeTurns[sid] else { return }
        let busy = activeTurns.contains {
            $0.key != sid && $0.value.path == mine.path && $0.value.branch == mine.branch
        }
        guard busy else { return }
        let location = mine.branch.map { "branch “\($0)”" } ?? "this project"
        appendSystem("⚠︎ Another chat is already working in \(location). Running both agents on the same branch can cause conflicting edits — consider waiting for it to finish, or move one to a different branch.", to: sid)
    }

    /// A @Sendable callback that stores this turn's CLI session id onto chat `sid`.
    private func sessionCapture(for sid: UUID) -> @Sendable (String) -> Void {
        { [weak self] cid in Task { @MainActor in self?.storeClaudeSession(cid, for: sid) } }
    }

    // MARK: - Routing (Pillar 1)

    /// A suggestion (from the fast-model router on send) that the message
    /// belongs somewhere other than the current chat.
    enum RouteSuggestion: Equatable {
        case existing(chatId: UUID, title: String) // a different chat fits this better
        case newTopic                              // a different topic from this chat
    }
    @Published var routeHint: RouteSuggestion?
    /// True while the router is deciding (between hitting Send and dispatch).
    @Published var isRouting = false
    private var pendingMessage: (text: String, attachments: [UserAttachment])?
    private var routeTask: Task<Void, Never>?

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
        let active = saved.filter { !$0.isArchived }.sorted { $0.lastOpenedAt > $1.lastOpenedAt }

        // Restore the project the last-used chat belongs to (else the most
        // recently opened project), so a reopened chat isn't orphaned.
        let restorePath = active.first?.projectPath
        let restored = recentProjects.first(where: { $0.path == restorePath }) ?? recentProjects.first
        self.currentProject = restored

        if let chat = active.first(where: { $0.projectPath == restored?.path }) {
            self.sessions = saved
            self.session = chat
        } else {
            let fresh = ChatSession(projectPath: restored?.path)
            self.sessions = saved + [fresh]
            self.session = fresh
        }

        reloadProvider()
        if let url = currentProject?.url {
            projectInitialized = projectService.isInitializedForAI(at: url)
        }
        if session.messages.isEmpty {
            appendSystem("Welcome to AI-Things — a graphical front-end for Claude Code. Open a project and start chatting.")
        }
        if currentProject != nil { Task { await refreshGit() } }
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

    /// The active Claude Code provider, if that's the selected backend.
    private var claudeProvider: ClaudeCodeProvider? { aiService.provider as? ClaudeCodeProvider }

    /// The saved CLI session id for a chat (to resume its context), looked up
    /// per-turn so parallel chats never share `--resume` state.
    private func claudeSessionID(of sid: UUID) -> String? {
        session.id == sid ? session.claudeSessionID : sessions.first { $0.id == sid }?.claudeSessionID
    }

    /// Remember the CLI session id on the chat that owned this turn (which may no
    /// longer be the one on screen). Called via the request's `onSessionID`.
    private func storeClaudeSession(_ id: String, for sid: UUID) {
        if session.id == sid {
            session.claudeSessionID = id
        } else if let i = sessions.firstIndex(where: { $0.id == sid }) {
            sessions[i].claudeSessionID = id
        }
    }

    // MARK: - Project handling

    func openProjectPicker() {
        guard let project = projectService.pickDirectory() else { return }
        selectProject(project)
    }

    func selectProject(_ project: ProjectDirectory) {
        persist() // save the chat we're leaving
        currentProject = project
        projectService.remember(project)
        recentProjects = projectService.recents()
        reloadProvider()

        // Reopen the project's existing chats; land on the one last used here.
        let existing = sessions
            .filter { $0.projectPath == project.path && !$0.isArchived }
            .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        if let lastUsed = existing.first {
            activate(lastUsed)
            statusText = "Reopened \(existing.count) chat\(existing.count == 1 ? "" : "s")"
        } else if !session.messages.contains(where: { $0.role == .user }) {
            session.projectPath = project.path // reuse the empty welcome chat
            appendSystem("Opened project: \(project.path)")
        } else {
            startNewSession(projectPath: project.path, announce: false)
            appendSystem("Opened project: \(project.path)")
        }

        if let url = projectURL {
            projectInitialized = projectService.isInitializedForAI(at: url)
        }

        persist()
        Task { await refreshGit() }
    }

    /// One-click "Initialize for AI": scaffold CLAUDE.md + .aithings/*.html, then
    /// ask Claude to fill them based on the real codebase.
    func initializeProjectForAI() {
        guard let url = projectURL else {
            appendSystem("Open a project first.")
            return
        }
        let created = projectService.scaffoldAIDocs(at: url)
        projectInitialized = true
        appendSystem(created.isEmpty
            ? "AI docs already present — asking Claude to fill them in."
            : "Created \(created.joined(separator: ", ")). Asking Claude to fill them in…")

        runDocsTask(userLabel: "Initialize AI docs for this project.", prompt: """
        Initialize this project's AI docs from the actual codebase:
        - CLAUDE.md — overview, tech stack, build/run/test commands, architecture, conventions. Keep it concise (aim under ~150 lines).
        - .aithings/status.html — idea, current status, progress log, next up.
        - .aithings/architecture.html — modules, data flow, external services.
        - .aithings/features.html — done, in progress, planned.
        Inspect the real files first; don't invent features that don't exist. Edit the files directly.
        """)
    }

    /// Refresh the AI docs to reflect the current state (used once initialized).
    func updateProjectDocs() {
        guard let url = projectURL else {
            appendSystem("Open a project first.")
            return
        }
        projectService.scaffoldAIDocs(at: url) // create any that went missing
        projectInitialized = true
        appendSystem("Asking Claude to update the project's AI docs…")

        runDocsTask(userLabel: "Update AI docs to reflect the current state.", prompt: """
        Update this project's AI docs to reflect the CURRENT state — don't recreate from scratch:
        - CLAUDE.md — refresh overview, commands, architecture, and conventions if they changed.
        - .aithings/status.html — update current status and add a dated entry to the progress log; refresh "next up".
        - .aithings/architecture.html — reflect any structural changes.
        - .aithings/features.html — move items between done / in progress / planned as appropriate.
        Inspect the real files; only change what is outdated. Edit the files directly.
        """)
    }

    /// Shared driver for the docs init/update turns.
    private func runDocsTask(userLabel: String, prompt: String) {
        let sid = session.id
        let gen = beginTurn(sid)
        streamTasks[sid]?.cancel()
        streamTasks[sid] = Task {
            appendMessage(ChatMessage(role: .user, text: userLabel), to: sid)
            nameChatIfNeeded(sid, from: userLabel)
            warnIfConcurrentAgent(for: sid)
            let context = await currentContext()
            let request = AIRequest(
                systemPrompt: aiService.systemPrompt(improvement: improvement, context: context,
                                                     autoApply: settings.autoApplyTrustedChanges),
                history: messages(of: sid),
                userMessage: prompt,
                context: context,
                appendSystemPrompt: behaviorDirectives(),
                resumeSessionID: claudeSessionID(of: sid),
                onSessionID: sessionCapture(for: sid)
            )
            await streamAssistant(request, in: sid)
            endTurn(sid, gen: gen)
        }
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
        // Remember the branch the on-screen chat is working on, so switching back
        // to it later re-checks-out that branch.
        if belongsToCurrentProject(session) { session.branch = currentBranch }
        branches = await gitService.listBranches(at: url)
        hasUncommittedChanges = await gitService.hasUncommittedChanges(at: url)
        changedFiles = await gitService.changedFiles(at: url)
        let ab = await gitService.aheadBehind(at: url)
        aheadCount = ab.ahead
        behindCount = ab.behind
        hasUpstream = ab.hasUpstream
        statusText = "Connected"
    }

    // MARK: - Chat session management

    /// Chats for the current project, newest first (active / archived split).
    // Sidebar order is by creation time (newest first) so the list is stable —
    // merely opening a chat must never reorder it. (Reopen-the-last-used logic
    // still uses lastOpenedAt elsewhere.)
    var activeSessions: [ChatSession] {
        sessions.filter { !$0.isArchived && belongsToCurrentProject($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    var archivedSessions: [ChatSession] {
        sessions.filter { $0.isArchived && belongsToCurrentProject($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Make a chat the active one and mark it as just-opened, so reopening the
    /// project later lands back here (and it sorts to the top of the list).
    private func activate(_ chat: ChatSession) {
        var c = chat
        c.lastOpenedAt = Date()
        session = c
        if let i = sessions.firstIndex(where: { $0.id == c.id }) {
            sessions[i].lastOpenedAt = c.lastOpenedAt
        }
    }

    private func belongsToCurrentProject(_ s: ChatSession) -> Bool {
        s.projectPath == currentProject?.path
    }

    func newChat() {
        startNewSession(projectPath: currentProject?.path, announce: true)
    }

    /// Create a new chat seeded with another chat's transcript AND Claude context,
    /// so you can branch off an old conversation without losing its history.
    func forkSession(_ id: UUID) {
        guard let source = sessions.first(where: { $0.id == id }) else { return }
        persist()
        let copy = ChatSession(title: source.title,
                               messages: source.messages,
                               projectPath: source.projectPath,
                               claudeSessionID: source.claudeSessionID)
        sessions.insert(copy, at: 0)
        session = copy
        appendSystem("New chat continuing from “\(source.title)”. Claude keeps the earlier context.")
        chatStore.save(sessions)
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
        activate(target)
        checkoutChatBranchIfNeeded()
    }

    /// When switching to a chat that worked on another branch, check that branch
    /// out so the git bar reflects it. No-op if it's already current, gone, or
    /// the chat never ran on a branch.
    private func checkoutChatBranchIfNeeded() {
        guard isGitRepo, let target = session.branch, !target.isEmpty, target != currentBranch,
              branches.contains(where: { !$0.isRemote && $0.name == target }) else { return }
        switchBranch(target)
    }

    /// Other active chats in this project, ranked by topic similarity (for merge).
    func mergeTargets(for chat: ChatSession) -> [ChatSession] {
        let me = topicText(of: chat)
        return sessions
            .filter { $0.id != chat.id && !$0.isArchived && belongsToCurrentProject($0) }
            .map { ($0, matcher.similarity(me, topicText(of: $0))) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// Merge `sourceId` into `targetId`: append its messages to the target,
    /// keep the target (and its Claude session), then drop the source.
    func mergeSession(_ sourceId: UUID, into targetId: UUID) {
        guard sourceId != targetId,
              let si = sessions.firstIndex(where: { $0.id == sourceId }),
              let ti = sessions.firstIndex(where: { $0.id == targetId }) else { return }
        let source = sessions[si]
        sessions[ti].messages.append(contentsOf: source.messages)
        sessions[ti].updatedAt = Date()
        sessions[ti].title = sessions[ti].derivedTitle
        let merged = sessions[ti]
        sessions.removeAll { $0.id == sourceId }
        if session.id == sourceId || session.id == targetId {
            activate(merged)
        }
        chatStore.save(sessions)
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
            activate(next)
            chatStore.save(sessions)
        } else {
            startNewSession(projectPath: currentProject?.path, announce: false)
        }
    }

    /// Flush the working chat into the persisted list and schedule a save.
    private func persist() {
        session.updatedAt = Date()
        // Title is set once from the first message (see nameChatIfNeeded); don't
        // re-derive it here — that mis-targeted the active chat during parallel
        // turns and overwrote nicely-named titles.
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        // Drop stray chats that never got a real user message (except the current one).
        sessions.removeAll { $0.id != session.id && !$0.messages.contains { $0.role == .user } }
        chatStore.save(sessions)
    }

    // MARK: - Sending messages

    func send() {
        guard !isRouting else { return } // already deciding; ignore double-send
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty || !pendingAttachments.isEmpty else { return }

        // Routing only makes sense for real text when there's somewhere else it
        // could go: another chat to move to, or an established topic to leave.
        let others = sessions.filter {
            $0.id != session.id && !$0.isArchived && belongsToCurrentProject($0)
                && $0.messages.contains { $0.role == .user }
        }
        let currentHasTopic = session.messages.contains { $0.role == .user }
        guard !raw.isEmpty, currentHasTopic || !others.isEmpty,
              let claude = aiService.provider as? ClaudeCodeProvider, claude.hasResolvedCLI else {
            dispatchSend(raw, attachments: pendingAttachments)
            return
        }

        let attachments = pendingAttachments
        pendingMessage = (raw, attachments)
        isRouting = true
        let currentTopic = currentHasTopic ? topicText(of: session) : ""
        let candidateTopics = others.map { topicText(of: $0) }
        routeTask = Task {
            let result = await claude.classifyRoute(message: raw, currentTopic: currentTopic, others: candidateTopics)
            finishRouting(result, others: others)
        }
    }

    /// Apply the router's verdict: show a banner to confirm a move/new-chat, or
    /// just send in place for "keep" (and on any failure).
    private func finishRouting(_ result: (decision: String, chat: Int)?, others: [ChatSession]) {
        isRouting = false
        guard pendingMessage != nil else { return } // canceled/superseded
        switch result?.decision {
        case "move" where result.map({ others.indices.contains($0.chat) }) == true:
            let target = others[result!.chat]
            routeHint = .existing(chatId: target.id, title: target.title)
        case "new":
            routeHint = .newTopic
        default:
            dispatchSendPending()
        }
    }

    private func dispatchSend(_ raw: String, attachments: [UserAttachment]) {
        draft = ""
        pendingAttachments = []
        if !raw.isEmpty { inputHistory.append(raw) }
        session.lastOpenedAt = Date() // prompting marks this as the last-used chat
        let sid = session.id
        let gen = beginTurn(sid)
        streamTasks[sid]?.cancel() // replace only THIS chat's turn; other chats keep running
        streamTasks[sid] = Task {
            await runTurn(raw, attachments: attachments, in: sid)
            endTurn(sid, gen: gen)
        }
    }

    // MARK: - Route resolution (from the suggestion banner)

    /// Move the held message into the suggested existing chat.
    func routeMoveToTarget() {
        guard let pm = pendingMessage, case let .existing(chatId, _) = routeHint else { return }
        clearPendingRoute()
        selectSession(chatId)
        dispatchSend(pm.text, attachments: pm.attachments)
    }

    /// Send the held message in the current chat anyway.
    func routeKeepHere() {
        clearPendingRoute(send: true)
    }

    /// Send the held message into a fresh chat.
    func routeToNewChat() {
        guard let pm = pendingMessage else { clearPendingRoute(); return }
        clearPendingRoute()
        newChat()
        dispatchSend(pm.text, attachments: pm.attachments)
    }

    /// Send the message currently held by the router (no chat switch).
    private func dispatchSendPending() {
        guard let pm = pendingMessage else { return }
        pendingMessage = nil
        dispatchSend(pm.text, attachments: pm.attachments)
    }

    private func clearPendingRoute(send: Bool = false) {
        routeHint = nil
        guard let pm = pendingMessage else { return }
        pendingMessage = nil
        if send { dispatchSend(pm.text, attachments: pm.attachments) }
    }

    /// Representative text for a chat: title + its recent user messages.
    private func topicText(of chat: ChatSession) -> String {
        let userMsgs = chat.messages.filter { $0.role == .user }.suffix(5).map(\.text)
        return ([chat.title] + userMsgs).joined(separator: ". ")
    }

    @Published var isImproving = false
    /// Transient feedback shown after "Make clearer" runs.
    @Published var improveNote: String?
    private var draftBeforeImprove: String?
    var canUndoImprove: Bool { draftBeforeImprove != nil }

    /// Rewrite the current draft in place (for review) — does NOT send.
    /// Uses Claude for a real rewrite when available, with an instant local
    /// cleanup as fallback. Always reports back what it did.
    func improveDraft() {
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isImproving else { return }
        let original = draft

        if let claude = aiService.provider as? ClaudeCodeProvider {
            isImproving = true
            improveNote = nil
            Task {
                let improved = await claude.rewrite(raw)
                isImproving = false
                applyImprovement(improved ?? MessageImprovementService.heuristicRewrite(raw),
                                 original: original, aiUsed: improved != nil)
            }
        } else {
            applyImprovement(MessageImprovementService.heuristicRewrite(raw),
                             original: original, aiUsed: false)
        }
    }

    private func applyImprovement(_ text: String, original: String, aiUsed: Bool) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines)
            == original.trimmingCharacters(in: .whitespacesAndNewlines) {
            draftBeforeImprove = nil
            flashImproveNote("Already clear — no changes made.")
        } else {
            draft = text
            draftBeforeImprove = original
            flashImproveNote(aiUsed ? "✦ Rewritten with Claude — review, then send." : "Cleaned up — review, then send.")
        }
    }

    func undoImprove() {
        if let original = draftBeforeImprove { draft = original }
        draftBeforeImprove = nil
        improveNote = nil
    }

    private func flashImproveNote(_ message: String) {
        improveNote = message
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if improveNote == message { improveNote = nil }
        }
    }

    private func runTurn(_ raw: String, attachments: [UserAttachment], in sid: UUID) async {
        let messageText = raw
        appendMessage(ChatMessage(role: .user, text: messageText, attachments: attachments), to: sid)
        nameChatIfNeeded(sid, from: messageText)
        warnIfConcurrentAgent(for: sid)

        // Feature/Bug mode: when starting from the base branch, auto-create a
        // branch named from the user's text. (The mode itself stays on and keeps
        // framing the prompt until the user turns it off.)
        if taskMode != .none, isGitRepo, currentBranch == baseBranch {
            await autoCreateBranch(from: messageText, mode: taskMode)
        }

        // Build the AI prompt: replace each inline token with the attachment's
        // file path so the model sees exactly where each image/file belongs.
        let promptForAI = resolveAttachments(in: messageText, attachments: attachments)

        let context = await currentContext()
        let request = AIRequest(
            systemPrompt: aiService.systemPrompt(improvement: improvement, context: context,
                                                 autoApply: settings.autoApplyTrustedChanges),
            history: messages(of: sid),
            userMessage: promptForAI,
            context: context,
            appendSystemPrompt: behaviorDirectives(),
            resumeSessionID: claudeSessionID(of: sid),
            onSessionID: sessionCapture(for: sid)
        )
        await streamAssistant(request, in: sid)

        if settings.automationEnabled { await runPipeline(in: sid) }
    }

    // MARK: - Automation pipeline

    enum StepState: Equatable { case idle, running, done, failed }
    @Published var stepStatus: [AutomationStep.Kind: StepState] = [:]

    /// Run the enabled post-task steps in order, each as a Claude follow-up turn.
    private func runPipeline(in sid: UUID) async {
        let steps = settings.automationSteps.filter(\.enabled)
        guard !steps.isEmpty else { return }

        stepStatus = Dictionary(uniqueKeysWithValues: steps.map { ($0.kind, .idle) })
        for step in steps {
            if Task.isCancelled { break }
            stepStatus[step.kind] = .running
            appendSystem("▶︎ Automation — \(step.kind.title)", to: sid)

            if step.kind.isGating {
                // Gate: verify → fix → re-verify, up to maxAttempts. If it still
                // fails, stop the pipeline (don't commit/merge a broken change).
                let maxAttempts = 3
                var passed = false
                var attempt = 1
                while attempt <= maxAttempts {
                    if Task.isCancelled { break }
                    if attempt > 1 { appendSystem("↻ \(step.kind.title) — retry \(attempt)/\(maxAttempts)", to: sid) }
                    let reply = await runStep(step.kind, in: sid)
                    if !verdictFailed(reply) { passed = true; break }
                    attempt += 1
                }
                if passed {
                    stepStatus[step.kind] = .done
                } else {
                    stepStatus[step.kind] = .failed
                    appendMessage(ChatMessage(role: .system, kind: .errorOutput,
                        text: "⛔ Automation stopped: \(step.kind.title) didn't pass after \(maxAttempts) attempts. Remaining steps (incl. commit/merge) were skipped — fix it, then run again."), to: sid)
                    break
                }
            } else {
                await runStep(step.kind, in: sid)
                stepStatus[step.kind] = .done
            }
        }
        // Clear the status strip a few seconds after finishing.
        let snapshot = stepStatus
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if stepStatus == snapshot { stepStatus = [:] }
        }
    }

    @discardableResult
    private func runStep(_ kind: AutomationStep.Kind, in sid: UUID) async -> String {
        let context = await currentContext()
        let request = AIRequest(
            systemPrompt: aiService.systemPrompt(improvement: improvement, context: context,
                                                 autoApply: settings.autoApplyTrustedChanges),
            history: messages(of: sid),
            userMessage: stepPrompt(for: kind),
            context: context,
            appendSystemPrompt: behaviorDirectives(),
            resumeSessionID: claudeSessionID(of: sid),
            onSessionID: sessionCapture(for: sid)
        )
        await streamAssistant(request, in: sid)
        return messages(of: sid).last(where: { $0.role == .assistant })?.text ?? ""
    }

    /// A gating step reports failure by ending with the STATUS: FAIL marker.
    private func verdictFailed(_ reply: String) -> Bool {
        reply.uppercased().contains("STATUS: FAIL")
    }

    /// The effective base/target branch for merges: the user's setting, else
    /// the repo's detected main/master, else "main".
    var releaseBranch: String {
        let configured = settings.releaseBranch.trimmingCharacters(in: .whitespaces)
        return configured.isEmpty ? (baseBranch ?? "main") : configured
    }

    private func stepPrompt(for kind: AutomationStep.Kind) -> String {
        // Gating steps must fix what they find and self-report a verdict so the
        // pipeline can loop until it passes (or stop before commit/merge).
        let gate = "\n\nIf anything fails, FIX it in the code, then re-verify. Repeat until it passes. End your reply with a single final line: STATUS: PASS if everything passes, otherwise STATUS: FAIL followed by the remaining issues."

        switch kind {
        case .review:
            let rules = settings.reviewRules.trimmingCharacters(in: .whitespacesAndNewlines)
            var p = kind.prompt
            if !rules.isEmpty {
                p += "\n\nCheck the change against these project rules and fix any violations:\n\(rules)"
            }
            return p + gate
        case .test:
            let rules = settings.testRules.trimmingCharacters(in: .whitespacesAndNewlines)
            var p = kind.prompt
            if !rules.isEmpty {
                p += "\n\nFollow these testing rules when deciding what to add or change:\n\(rules)"
            }
            return p + gate
        case .bumpVersion:
            let part = settings.versionBump.rawValue
            return "A unit of work is complete. Using semantic versioning, bump the \(part.uppercased()) version component (major → x.0.0, minor → maj.x.0, patch → maj.min.x; reset lower components). Find where the version is defined (e.g. project.yml MARKETING_VERSION, package.json, Info.plist) and update it. State the old and new version in one line."
        case .mergeAndPush:
            let base = releaseBranch
            return """
            Commit any pending changes with a concise message. Then integrate the current branch into the `\(base)` branch and push `\(base)` to origin. If you are already on `\(base)`, just commit and push. Resolve trivial conflicts; if there are non-trivial conflicts, stop and report them. Report the final branch and the pushed commit.
            """
        default:
            return kind.prompt
        }
    }

    private func streamAssistant(_ request: AIRequest, in sid: UUID) async {
        streamingSessions.insert(sid)
        if sid == session.id { statusText = "Thinking…" }
        defer {
            streamingSessions.remove(sid)
            if sid == session.id { statusText = isGitRepo ? "Connected" : "Idle" }
            persist()
            Task { await refreshGit() } // reflect any edits/commits the AI made
        }

        var assistant = ChatMessage(role: .assistant, text: "")
        appendMessage(assistant, to: sid)
        let id = assistant.id

        do {
            for try await chunk in aiService.stream(request) {
                if Task.isCancelled { break }
                assistant.text += chunk
                updateMessage(id: id, text: assistant.text, in: sid)
            }
        } catch {
            appendMessage(ChatMessage(role: .assistant, kind: .errorOutput,
                                      text: "Error: \(error.localizedDescription)"), to: sid)
        }
    }

    /// Stop only the chat currently on screen — other chats keep working.
    func cancelStreaming() {
        let sid = session.id
        streamTasks[sid]?.cancel()
        streamingSessions.remove(sid)
        statusText = "Cancelled"
    }

    /// Called when the app is quitting: stop any running Claude/CLI work so no
    /// process is orphaned (and no usage keeps burning), and flush chats to disk
    /// synchronously so nothing is lost.
    func shutdown() {
        streamTasks.values.forEach { $0.cancel() } // cancel every chat's stream
        (aiService.provider as? ClaudeCodeProvider)?.terminateRunning() // and kill them directly, now
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        chatStore.saveNow(sessions)
    }

    /// Concise behavior directives derived from the composer toggles. Passed to
    /// the Claude Code CLI via --append-system-prompt.
    private func behaviorDirectives() -> String {
        var d: [String] = []

        // PRECISE dominates: put it first and make it a hard constraint so the
        // model doesn't fall back to its normal verbose style.
        if improvement.precise {
            d.append("""
            ### OUTPUT STYLE: PRECISE (HARD RULES — these override your default style)
            - Maximum 4 lines total in the reply. Prefer 1.
            - Each line ≤ 12 words. Telegraphic: drop articles/filler; grammar is optional.
            - NO preamble, NO "Here is/I'll/Let me", NO restating the request, NO summary of what you did, NO closing remarks, NO headings.
            - Output ONLY the essential answer: a value, a file path, a command, or a minimal code snippet.
            - If one word or one line answers it, stop there. Explain ONLY if explicitly asked.
            """)
        } else {
            d.append("Respond in short, scannable bullet points. Focus on the software task.")
            if improvement.directMode {
                d.append("Be concise; minimal prose; prioritize concrete code changes and commands.")
            }
        }

        if improvement.askQuestionsFirst {
            d.append("If the request is ambiguous, ask brief clarifying questions before editing files.")
        }
        switch taskMode {
        case .feature:
            d.append("This is a FEATURE request: add new functionality in small, isolated components.")
        case .bug:
            d.append("This is a BUG FIX: reproduce the issue, find the root cause, fix it, and cover it with a test.")
        case .none:
            break
        }
        // Keep the project's living docs current (the user relies on these).
        d.append("When you make meaningful changes, update CLAUDE.md (idea, status, conventions) and .aithings/status.html (status & progress log) to reflect them.")
        return d.joined(separator: "\n")
    }

    /// Replace inline attachment tokens with concrete file paths for the AI,
    /// appending any attachments that weren't referenced inline.
    private func resolveAttachments(in text: String, attachments: [UserAttachment]) -> String {
        guard !attachments.isEmpty else { return text }
        var prompt = text
        for att in attachments {
            let path = attachmentService.filePath(for: att)
            let replacement: String
            switch att.kind {
            case .image:
                replacement = path.map { "\n[Image \"\(att.name)\" — file at: \($0)]\n" } ?? "\n[Image \"\(att.name)\"]\n"
            default:
                replacement = path.map { "\n[File \"\(att.name)\" — \($0)]\n" } ?? "\n[File \"\(att.name)\"]\n"
            }
            if prompt.contains(att.inlineToken) {
                prompt = prompt.replacingOccurrences(of: att.inlineToken, with: replacement)
            } else {
                prompt += replacement
            }
        }
        return prompt
    }

    private func currentContext() async -> ProjectContext {
        var files: [String] = []
        if let url = projectURL {
            files = projectService.topLevelEntries(of: url).map { $0.lastPathComponent }
        }
        return ProjectContext(path: currentProject?.path, branch: currentBranch, topLevelFiles: files)
    }

    // MARK: - Quick task modes

    /// Toggle Feature / Bug framing from the composer. Tapping the active one
    /// turns it off. The mode frames every prompt while on, and (from the base
    /// branch) the first message auto-creates the branch.
    func toggleTaskMode(_ mode: TaskMode) {
        taskMode = (taskMode == mode) ? .none : mode
    }

    /// Create (and switch to) a branch named from the user's text. No-op outside a git repo.
    private func autoCreateBranch(from text: String, mode: TaskMode) async {
        guard isGitRepo, let url = projectURL else { return }
        let kind: BranchKind = (mode == .bug) ? .bugfix : .feature
        let name = Self.formatBranchName(kind: kind, name: Self.branchKeywords(from: text))
        guard !name.isEmpty else { return }
        let result = try? await gitService.createBranch(name, at: url)
        if result?.succeeded == true {
            appendSystem("Created branch \(name)")
        } else if let out = result?.combined, !out.isEmpty {
            appendSystem(out) // e.g. branch already exists
        }
        await refreshGit()
    }

    /// Words dropped from branch slugs — the kind prefix (feature/ bugfix/)
    /// already conveys these, so repeating them is noise.
    private static let branchStopwords: Set<String> = [
        "fix", "fixing", "fixed", "fixes", "bug", "bugs", "issue", "issues", "problem",
        "feature", "features", "add", "adding", "added", "implement", "implementing",
        "create", "creating", "make", "making", "build", "refactor", "refactoring",
        "update", "updating", "the", "a", "an", "to", "for", "of", "in", "on", "and",
        "please", "that", "this", "my", "our", "app", "with", "support"
    ]

    /// Extract the meaningful keywords from a message for a branch slug, using
    /// natural-language tagging: keep nouns / verbs / adjectives / numbers,
    /// lemmatize them, drop stopwords and the kind-implied words. Falls back to
    /// a simple split if tagging yields nothing.
    static func branchKeywords(from text: String, maxWords: Int = 4) -> String {
        let keepClasses: Set<NLTag> = [.noun, .verb, .adjective, .number, .otherWord]
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        let range = text.startIndex..<text.endIndex

        var words: [String] = []
        var seen = Set<String>()
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation, .omitOther]) { tag, tokenRange in
            guard let tag, keepClasses.contains(tag) else { return true }
            // Prefer the lemma (e.g. "saving" -> "save").
            let lemma = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            let word = (lemma ?? String(text[tokenRange])).lowercased()
            guard word.count > 1, !branchStopwords.contains(word), !seen.contains(word) else { return true }
            seen.insert(word)
            words.append(word)
            return words.count < maxWords
        }

        if words.isEmpty {
            // Fallback: stopword-filtered split.
            words = text.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 1 && !branchStopwords.contains($0) }
            if words.isEmpty {
                words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            }
            words = Array(words.prefix(maxWords))
        }
        return words.joined(separator: " ")
    }

    /// A short, readable chat title from the first message — the SAME keyword
    /// extraction used for branch names, just Title-Cased and without the
    /// `feature/` / `bugfix/` prefix. Falls back to the first line.
    static func niceChatTitle(from text: String) -> String {
        let words = branchKeywords(from: text, maxWords: 5)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        if !words.isEmpty { return words.joined(separator: " ") }
        let line = text.split(separator: "\n").first.map(String.init) ?? text
        return String(line.trimmingCharacters(in: .whitespaces).prefix(48))
    }

    private func chatTitle(of sid: UUID) -> String? {
        session.id == sid ? session.title : sessions.first { $0.id == sid }?.title
    }

    private func setChatTitle(_ title: String, for sid: UUID) {
        if session.id == sid {
            session.title = title
        } else if let i = sessions.firstIndex(where: { $0.id == sid }) {
            sessions[i].title = title
        }
    }

    /// Name a chat from its first user message, once. Sets an instant heuristic
    /// title immediately, then upgrades it to a concise AI topic title — so a new
    /// chat ALWAYS shows the topic it was asked about. Bound by id so a chat
    /// streaming in the background is still named correctly.
    private func nameChatIfNeeded(_ sid: UUID, from text: String) {
        guard let current = chatTitle(of: sid), current.isEmpty || current == "New Chat" else { return }
        let instant = Self.niceChatTitle(from: text)
        guard !instant.isEmpty else { return }
        setChatTitle(instant, for: sid)

        // Upgrade to a clean topic title from the fast model, if available.
        guard let claude = aiService.provider as? ClaudeCodeProvider, claude.hasResolvedCLI else { return }
        Task {
            guard let ai = await claude.suggestTitle(text), !ai.isEmpty else { return }
            // Don't clobber a manual rename — only replace our own instant title.
            if chatTitle(of: sid) == instant { setChatTitle(ai, for: sid) }
        }
    }

    // MARK: - Git actions

    /// The repo's base branch: `main` if it exists locally, else `master`, else nil.
    var baseBranch: String? {
        let locals = Set(branches.filter { !$0.isRemote && !$0.name.contains("/") }.map(\.name))
        if locals.contains("main") { return "main" }
        if locals.contains("master") { return "master" }
        return nil
    }

    /// Merge is offered only when on a non-base branch and a base exists.
    var canMergeToBase: Bool {
        guard isGitRepo, let base = baseBranch, let current = currentBranch else { return false }
        return current != base
    }

    /// Diff text for a changed file (or the file contents if it's untracked).
    func loadDiff(for file: GitFileChange) async -> String {
        guard let url = projectURL else { return "" }
        if file.isUntracked {
            let fileURL = url.appendingPathComponent(file.path)
            let body = projectService.readFile(at: fileURL) ?? "(unable to read file)"
            return "New file: \(file.path)\n\n" + body
        }
        let result = try? await gitService.diff(file: file.path, at: url)
        let text = result?.combined ?? ""
        return text.isEmpty ? "No textual diff (binary file or no changes vs HEAD)." : text
    }

    func mergeCurrentIntoBase() {
        guard let base = baseBranch, let current = currentBranch, current != base else { return }
        runGit("Merging \(current) → \(base)") { [gitService, projectURL] in
            try await gitService.merge(branch: current, into: base, at: projectURL)
        }
    }

    /// Local branches (excludes remote-tracking refs like `origin/main`).
    var localBranches: [GitBranch] {
        branches.filter { !$0.isRemote && !$0.name.hasPrefix("origin/") && !$0.name.hasPrefix("remotes/") }
    }

    func switchBranch(_ name: String) {
        guard name != currentBranch else { return }
        runGit("Switching to \(name)") { [gitService, projectURL] in
            try await gitService.checkout(branch: name, at: projectURL)
        }
    }

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

    /// Commit immediately with a message derived from the changed files — no prompt.
    func commitAuto() {
        guard hasUncommittedChanges else { appendSystem("Nothing to commit."); return }
        commit(message: autoCommitMessage())
    }

    /// A concise, sensible commit message built from the current changes.
    private func autoCommitMessage() -> String {
        let files = changedFiles
        guard !files.isEmpty else { return "Update project" }
        func verb(_ f: GitFileChange) -> String {
            switch f.badge {
            case "A", "U": return "Add"
            case "D":       return "Remove"
            default:        return "Update"
            }
        }
        let verbs = Set(files.map(verb))
        let lead = verbs.count == 1 ? (verbs.first ?? "Update") : "Update"
        let names = files.prefix(3).map(\.name)
        let more = files.count > 3 ? " +\(files.count - 3) more" : ""
        return "\(lead) \(names.joined(separator: ", "))\(more)"
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
        let items = attachmentService.attachmentsFromPasteboard()
        if !items.isEmpty {
            items.forEach { addAttachmentInline($0) }
        } else if let text = attachmentService.pasteboardText() {
            draft += (draft.isEmpty ? "" : "\n") + text
        }
    }

    /// Add pasted images/files (from the editor's ⌘V) and return their inline
    /// tokens so the editor can insert them at the caret. [] if clipboard is text.
    func pasteImagesReturningTokens() -> [String] {
        let items = attachmentService.attachmentsFromPasteboard()
        guard !items.isEmpty else { return [] }
        pendingAttachments.append(contentsOf: items)
        return items.map(\.inlineToken)
    }

    func attachImage() {
        if let attachment = attachmentService.pickImage() { addAttachmentInline(attachment) }
    }

    func attachFile() {
        if let attachment = attachmentService.pickFile() { addAttachmentInline(attachment) }
    }

    func referenceProjectFiles() {
        guard let url = projectURL else {
            appendSystem("Open a project first to reference its files.")
            return
        }
        let names = projectService.topLevelEntries(of: url).prefix(10).map { $0.lastPathComponent }
        for name in names {
            addAttachmentInline(UserAttachment(kind: .filePath, name: name,
                                               path: url.appendingPathComponent(name).path))
        }
    }

    func handleDrop(urls: [URL]) {
        for url in urls { addAttachmentInline(attachmentService.attachment(for: url)) }
    }

    /// Append an attachment and drop its inline token into the draft, so it's
    /// referenced at a clear point in the message rather than as a loose chip.
    private func addAttachmentInline(_ attachment: UserAttachment) {
        pendingAttachments.append(attachment)
        let needsSpace = !(draft.isEmpty || draft.hasSuffix(" ") || draft.hasSuffix("\n"))
        draft += (needsSpace ? " " : "") + attachment.inlineToken + " "
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

    // MARK: Session-bound writes (used by the streaming turn, which must keep
    // writing to the chat it started in even if the user opens another one).

    /// The live messages of `sid` — the on-screen working copy if it's active,
    /// otherwise its persisted copy in `sessions`.
    private func messages(of sid: UUID) -> [ChatMessage] {
        session.id == sid ? session.messages : (sessions.first { $0.id == sid }?.messages ?? [])
    }

    private func appendSystem(_ text: String, to sid: UUID) {
        appendMessage(ChatMessage(role: .system, kind: .system, text: text), to: sid)
    }

    private func appendMessage(_ message: ChatMessage, to sid: UUID) {
        if session.id == sid {
            session.messages.append(message)
        } else if let i = sessions.firstIndex(where: { $0.id == sid }) {
            sessions[i].messages.append(message)
        }
    }

    private func updateMessage(id: UUID, text: String, in sid: UUID) {
        if session.id == sid {
            if let mi = session.messages.firstIndex(where: { $0.id == id }) {
                session.messages[mi].text = text
            }
        } else if let si = sessions.firstIndex(where: { $0.id == sid }),
                  let mi = sessions[si].messages.firstIndex(where: { $0.id == id }) {
            sessions[si].messages[mi].text = text
        }
    }

    private func updatePlanStatus(messageID: UUID, status: AssistantPlan.Status) {
        guard let index = session.messages.firstIndex(where: { $0.id == messageID }) else { return }
        session.messages[index].plan?.status = status
    }

    /// Turn a kind + free text into a formatted git branch name.
    /// e.g. (.feature, "Login Screen") -> "feature/login-screen"
    static func formatBranchName(kind: BranchKind, name: String, maxLength: Int = 40) -> String {
        let parts = name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        // Build the slug word-by-word, stopping at a word boundary near the cap.
        var slug = ""
        for part in parts {
            let candidate = slug.isEmpty ? part : slug + "-" + part
            if candidate.count > maxLength { break }
            slug = candidate
        }
        return slug.isEmpty ? "" : kind.prefix + slug
    }
}
