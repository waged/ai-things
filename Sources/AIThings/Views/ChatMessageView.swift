import SwiftUI

/// Renders one conversation line in terminal style, parsing ``` code fences
/// into copyable code blocks and showing attachments / plans.
struct ChatMessageView: View {
    @EnvironmentObject private var model: AppModel
    let message: ChatMessage
    @State private var preview: UserAttachment?

    /// Attachments that don't appear as an inline token in the text.
    private var unreferencedAttachments: [UserAttachment] {
        message.attachments.filter { !message.text.contains($0.inlineToken) }
    }

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
                        case .attachment(let attachment):
                            inlineAttachment(attachment)
                        }
                    }

                    // Attachments not referenced inline still show as chips.
                    if !unreferencedAttachments.isEmpty {
                        AttachmentPreviewView(attachments: unreferencedAttachments, onRemove: nil)
                    }

                    if let plan = message.plan {
                        planView(plan)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $preview) { ImagePreviewView(attachment: $0) }
    }

    /// An attachment shown inline at its referenced position in the message.
    @ViewBuilder
    private func inlineAttachment(_ attachment: UserAttachment) -> some View {
        if attachment.kind == .image, let data = attachment.imageData, let image = NSImage(data: data) {
            Button { preview = attachment } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    Text(attachment.name)
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .help("Click to enlarge")
        } else {
            Label(attachment.name, systemImage: attachment.symbol)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.highlight)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.surfaceElevated)
                .clipShape(Capsule())
        }
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
        case attachment(UserAttachment)
    }

    /// Split message text on ``` fences into text / code segments, then split
    /// text further on inline attachment tokens (`[[img:ID]]`).
    private var segments: [Segment] {
        let parts = message.text.components(separatedBy: "```")
        guard parts.count > 1 else {
            return message.text.isEmpty ? [] : splitTokens(message.text)
        }
        var result: [Segment] = []
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(contentsOf: splitTokens(trimmed)) }
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

    /// Break a text run into `.text` and `.attachment` segments around any
    /// `[[img:ID]]` tokens, matching the id against this message's attachments.
    private func splitTokens(_ text: String) -> [Segment] {
        guard !message.attachments.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"\[\[img:([0-9A-Fa-f]{1,8})\]\]"#) else {
            return text.isEmpty ? [] : [.text(text)]
        }
        let ns = text as NSString
        var result: [Segment] = []
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                let chunk = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(.text(trimmed)) }
            }
            let shortID = ns.substring(with: match.range(at: 1))
            if let att = message.attachments.first(where: { $0.shortID == shortID }) {
                result.append(.attachment(att))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { result.append(.text(tail)) }
        }
        return result.isEmpty ? [.text(text)] : result
    }
}
