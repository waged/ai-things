import SwiftUI

/// Renders one conversation line in terminal style, parsing ``` code fences
/// into copyable code blocks and showing attachments / plans.
struct ChatMessageView: View {
    @EnvironmentObject private var model: AppModel
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(prompt)
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(promptColor)
                    .frame(width: 28, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        switch segment {
                        case .text(let value):
                            Text(value)
                                .font(Theme.mono(12.5))
                                .foregroundStyle(textColor)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        case .code(let code, let language):
                            CodeBlockView(code: code, language: language)
                        }
                    }

                    if !message.attachments.isEmpty {
                        AttachmentPreviewView(attachments: message.attachments, onRemove: nil)
                    }

                    if let plan = message.plan {
                        planView(plan)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plan

    @ViewBuilder
    private func planView(_ plan: AssistantPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(plan.title, systemImage: "list.bullet.clipboard")
                .font(Theme.mono(12, weight: .semibold))
                .foregroundStyle(Theme.highlight)
            Text(plan.summary)
                .font(Theme.mono(11.5))
                .foregroundStyle(Theme.textSecondary)

            ForEach(plan.fileChanges) { change in
                HStack(spacing: 6) {
                    Image(systemName: change.symbol)
                        .foregroundStyle(color(for: change.changeType))
                    Text(change.path).font(Theme.mono(11)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(change.changeType.rawValue)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            switch plan.status {
            case .proposed:
                HStack {
                    Button("Approve & Apply") { model.approvePlan(messageID: message.id) }
                        .buttonStyle(.borderedProminent)
                    Button("Reject") { model.rejectPlan(messageID: message.id) }
                        .buttonStyle(.bordered)
                }
                .controlSize(.small)
            case .approved, .applied:
                Label("Applied", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    .font(Theme.mono(11))
            case .rejected:
                Label("Rejected", systemImage: "xmark.circle.fill").foregroundStyle(Theme.danger)
                    .font(Theme.mono(11))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .terminalCard()
    }

    private func color(for type: FileChange.ChangeType) -> Color {
        switch type {
        case .create: return Theme.success
        case .modify: return Theme.warning
        case .delete: return Theme.danger
        }
    }

    // MARK: - Prompt styling

    private var prompt: String {
        switch message.role {
        case .user:      return "›"
        case .assistant: return "✦"
        case .system:    return "•"
        }
    }

    private var promptColor: Color {
        switch message.role {
        case .user:      return Theme.user
        case .assistant: return Theme.highlight
        case .system:    return Theme.textSecondary
        }
    }

    private var textColor: Color {
        switch message.kind {
        case .errorOutput:   return Theme.danger
        case .commandOutput: return Theme.textSecondary
        case .system:        return Theme.textSecondary
        default:             return Theme.textPrimary
        }
    }

    // MARK: - Content parsing

    private enum Segment {
        case text(String)
        case code(String, String?)
    }

    /// Split message text on ``` fences into text / code segments.
    private var segments: [Segment] {
        let parts = message.text.components(separatedBy: "```")
        guard parts.count > 1 else {
            return message.text.isEmpty ? [] : [.text(message.text)]
        }
        var result: [Segment] = []
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(.text(trimmed)) }
            } else {
                // First line after the fence may be a language hint.
                var lines = part.components(separatedBy: "\n")
                var language: String? = nil
                if let first = lines.first, !first.contains(" "), !first.isEmpty {
                    language = first
                    lines.removeFirst()
                }
                let code = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
                result.append(.code(code, language))
            }
        }
        return result
    }
}
