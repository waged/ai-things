import SwiftUI

/// Scrollable terminal-style conversation history. Auto-scrolls to the latest line.
struct TerminalChatView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
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
                        // A single, stable bottom anchor. Always scrolling here keeps
                        // the auto-scroll from jumping around.
                        Color.clear.frame(height: 1).id(bottomID)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled) // Cmd+C copies selected text
                }
                .background(Theme.background)
                // Per-token growth: keep the view pinned to the bottom WITHOUT
                // animating (animating each token is what produced the jitter).
                .onChange(of: model.session.messages.last?.text) { _, _ in
                    scrollToBottom(proxy, animated: false)
                }
                // Structural changes (new message) animate once.
                .onChange(of: model.session.messages.count) { _, _ in
                    scrollToBottom(proxy, animated: true)
                }
                // Switching chats changes the whole content height; jump to the
                // latest line so the new chat isn't scrolled into empty space.
                .onChange(of: model.session.id) { _, _ in
                    DispatchQueue.main.async { scrollToBottom(proxy, animated: false) }
                }
                .onAppear { DispatchQueue.main.async { scrollToBottom(proxy, animated: false) } }
            }

            // Lesson card pinned BELOW the scroll while the agent works — always
            // visible during long commands, and never jumps with the transcript.
            if model.isStreaming {
                LoadingGermanView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .overlay(alignment: .top) { Divider().overlay(Theme.border) }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isStreaming)
    }

    private let bottomID = "chat-bottom"

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
