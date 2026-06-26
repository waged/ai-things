import SwiftUI

/// Scrollable terminal-style conversation history. Auto-scrolls to the latest line.
struct TerminalChatView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.session.messages.isEmpty {
                        emptyState
                    }
                    // Hide the placeholder bubble for an as-yet-empty reply.
                    ForEach(model.session.messages.filter { !($0.role == .assistant && $0.text.isEmpty) }) { message in
                        ChatMessageView(message: message)
                            .id(message.id)
                    }
                    // Show the lesson card only while *waiting* for the reply — not
                    // pinned below a streaming answer (that made it jump on every token).
                    if showLoading {
                        LoadingGermanView()
                            .id(loadingID)
                            .padding(.top, 4)
                            .padding(.bottom, 10)
                    }
                    // A single, stable bottom anchor. Always scrolling here (instead
                    // of switching between the last message and the card) keeps the
                    // auto-scroll from jumping around.
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled) // Cmd+C copies selected text
            }
            .background(Theme.background)
            // Per-token growth: keep the view pinned to the bottom WITHOUT animating
            // (animating each token is what produced the jitter).
            .onChange(of: model.session.messages.last?.text) { _, _ in
                scrollToBottom(proxy, animated: false)
            }
            // Structural changes (new message, card appears/disappears) animate once.
            .onChange(of: model.session.messages.count) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: showLoading) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
        }
    }

    private let loadingID = "loading-german"
    private let bottomID = "chat-bottom"

    /// Only while streaming AND no partial answer has arrived yet (last message is
    /// the just-sent user line or an empty assistant placeholder).
    private var showLoading: Bool {
        guard model.isStreaming else { return false }
        guard let last = model.session.messages.last else { return true }
        return last.role != .assistant || last.text.isEmpty
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(bottomID, anchor: .bottom) }
        } else {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("things-connect.net AI — terminal assistant")
                .font(Theme.mono(13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("• Open a project from the sidebar")
            Text("• Type a task below, or use the Feature / Bug buttons")
            Text("• ⌘↩ to send · ⌘K clear · ⌘L focus input · Esc cancel")
        }
        .font(Theme.mono(12))
        .foregroundStyle(Theme.textSecondary)
        .padding(.vertical, 8)
    }
}
