import SwiftUI
import UniformTypeIdentifiers

/// Bottom composer: toggles, multiline input, attachment row, action buttons.
/// Handles paste, drag-and-drop, history recall, and keyboard shortcuts.
struct InputComposerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isDropTarget = false
    @State private var historyIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            togglesRow

            if let route = model.pendingRoute {
                routeBanner(route)
            }

            if !model.pendingAttachments.isEmpty {
                AttachmentPreviewView(attachments: model.pendingAttachments) { attachment in
                    model.removeAttachment(attachment)
                }
            }

            inputField
            actionsRow
        }
        .padding(12)
        .background(Theme.surface)
    }

    // MARK: - Route suggestion

    private func routeBanner(_ route: AppModel.RouteSuggestion) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.highlight)
            Text("This looks related to ")
                .foregroundStyle(Theme.textSecondary)
            + Text("“\(route.title)”").foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            Button("Move there") { model.routeMoveToTarget() }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(Theme.accent)
            Button("Keep here") { model.routeKeepHere() }
                .buttonStyle(.bordered).controlSize(.small)
            Button("New chat") { model.routeToNewChat() }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .font(Theme.mono(11))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Theme.accent.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Toggles

    private var togglesRow: some View {
        HStack(spacing: 10) {
            // One-shot: tidy the draft in place for review (does not send).
            Button { model.improveDraft() } label: {
                Label("Make clearer", systemImage: "wand.and.stars")
                    .font(Theme.mono(10.5))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Theme.accent)
            .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Clean up the draft (trim filler, fix spacing) — review before sending")

            toggle("Ask questions first", isOn: $model.improvement.askQuestionsFirst, symbol: "questionmark.circle")
            toggle("Direct mode", isOn: $model.improvement.directMode, symbol: "bolt")

            Divider().frame(height: 16).overlay(Theme.border)

            modeToggle("Feature", mode: .feature, symbol: "sparkles")
            modeToggle("Bug Fix", mode: .bug, symbol: "ant")

            Spacer()

            // Far-right: ultra-concise answers to save tokens.
            toggle("Precise", isOn: $model.improvement.precise, symbol: "scissors")
        }
    }

    /// Feature / Bug mode buttons — frame the prompt and (from the base branch)
    /// auto-create the matching branch from the message text.
    private func modeToggle(_ title: String, mode: AppModel.TaskMode, symbol: String) -> some View {
        Toggle(isOn: Binding(
            get: { model.taskMode == mode },
            set: { _ in model.toggleTaskMode(mode) }
        )) {
            Label(title, systemImage: symbol)
        }
        .toggleStyle(VividToggleStyle())
        .help(mode == .bug ? "Frame this as a bug fix" : "Frame this as a new feature")
    }

    private func toggle(_ title: String, isOn: Binding<Bool>, symbol: String) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
        }
        .toggleStyle(VividToggleStyle())
        .help(title)
    }

    // MARK: - Input field

    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            CodeTextEditor(
                text: $model.draft,
                focusToggle: model.focusComposerRequested,
                onSubmit: { send() },
                onEscape: { if model.isStreaming { model.cancelStreaming() } else { model.draft = "" } },
                onArrowUp: {
                    guard model.draft.isEmpty || historyIndex != nil else { return false }
                    recallHistory(offset: -1); return true
                },
                onArrowDown: {
                    guard historyIndex != nil else { return false }
                    recallHistory(offset: 1); return true
                },
                onPasteImages: { model.pasteImagesReturningTokens() }
            )
            .frame(minHeight: 60, maxHeight: 150)

            if model.draft.isEmpty {
                Text("Describe a task…  (⌘↩ to send · paste/drag images)")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.textSecondary.opacity(0.55))
                    .padding(.leading, 42) // clear the line-number gutter
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 2)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(isDropTarget ? Theme.accent : Theme.border,
                        lineWidth: isDropTarget ? 2 : 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTarget, perform: handleDrop)
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: 8) {
            iconButton("photo", help: "Attach image") { model.attachImage() }
            iconButton("doc", help: "Attach file") { model.attachFile() }
            iconButton("folder.badge.questionmark", help: "Reference project files") { model.referenceProjectFiles() }
            iconButton("doc.on.clipboard", help: "Paste text or image") { model.pasteFromClipboard() }

            Spacer()

            Button("Clear") { model.draft = ""; model.pendingAttachments = [] }
                .buttonStyle(.bordered)
                .controlSize(.small)

            if model.isStreaming {
                Button("Stop") { model.cancelStreaming() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Theme.danger)
            }

            Button {
                send()
            } label: {
                Label("Send", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Theme.accent)
            .disabled(model.isStreaming)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .foregroundStyle(Theme.textSecondary)
        .help(help)
    }

    // MARK: - Behavior

    private func send() {
        historyIndex = nil
        model.send()
    }

    private func recallHistory(offset: Int) {
        let history = model.inputHistory
        guard !history.isEmpty else { return }
        let next: Int
        if let current = historyIndex {
            next = max(0, min(history.count - 1, current + offset))
        } else {
            next = history.count - 1
        }
        historyIndex = next
        model.draft = history[next]
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            model.handleDrop(urls: urls)
        }
        return true
    }
}
