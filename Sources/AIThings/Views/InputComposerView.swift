import SwiftUI
import UniformTypeIdentifiers

/// Bottom composer: toggles, multiline input, attachment row, action buttons.
/// Handles paste, drag-and-drop, history recall, and keyboard shortcuts.
struct InputComposerView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var inputFocused: Bool
    @State private var isDropTarget = false
    @State private var historyIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            togglesRow

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
        .onChange(of: model.focusComposerRequested) { _, _ in inputFocused = true }
    }

    // MARK: - Toggles

    private var togglesRow: some View {
        HStack(spacing: 14) {
            toggle("Make message clearer", isOn: $model.improvement.makeClearer, symbol: "wand.and.stars")
            toggle("Ask questions first", isOn: $model.improvement.askQuestionsFirst, symbol: "questionmark.circle")
            toggle("Direct mode", isOn: $model.improvement.directMode, symbol: "bolt")
            Spacer()
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>, symbol: String) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
                .font(Theme.mono(10.5))
        }
        .toggleStyle(.button)
        .controlSize(.small)
        .tint(Theme.accent)
        .help(title)
    }

    // MARK: - Input field

    private var inputField: some View {
        TextEditor(text: $model.draft)
            .font(Theme.mono(13))
            .foregroundStyle(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 56, maxHeight: 140)
            .padding(8)
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isDropTarget ? Theme.accent : Theme.border,
                            lineWidth: isDropTarget ? 2 : 1)
            )
            .focused($inputFocused)
            .onKeyPress(phases: .down, action: handleKeyPress)
            .onDrop(of: [.fileURL], isTargeted: $isDropTarget, perform: handleDrop)
            .overlay(alignment: .topLeading) {
                if model.draft.isEmpty {
                    Text("Describe a task…  (⌘↩ to send, drag files/images here)")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
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
        inputFocused = true
    }

    /// ⌘↩ send · Esc cancel/clear · ↑/↓ recall previous inputs (when empty).
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .return where press.modifiers.contains(.command):
            send()
            return .handled

        case .escape:
            if model.isStreaming { model.cancelStreaming() } else { model.draft = "" }
            return .handled

        case .upArrow where model.draft.isEmpty || historyIndex != nil:
            recallHistory(offset: -1)
            return .handled

        case .downArrow where historyIndex != nil:
            recallHistory(offset: 1)
            return .handled

        default:
            return .ignored
        }
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
