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
                    ForEach(model.session.messages) { message in
                        ChatMessageView(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled) // Cmd+C copies selected text
            }
            .background(Theme.background)
            .onChange(of: model.session.messages.last?.text) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: model.session.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = model.session.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
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
