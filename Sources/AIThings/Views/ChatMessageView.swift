import SwiftUI

/// Renders one conversation line in terminal style, parsing ``` code fences
/// into copyable code blocks and showing attachments / plans.
struct ChatMessageView: View {
    // No @EnvironmentObject here on purpose: this view must NOT re-render on every
    // keystroke in the composer (draft lives on the same model). It depends only
    // on its `message`, so body runs only when the message itself changes.
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
                            if message.role == .assistant && message.kind == .normal {
                                assistantText(value)
                            } else {
                                Text(value)
                                    .font(Theme.mono(12.5))
                                    .foregroundStyle(textColor)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
        .padding(message.role == .user ? 8 : 0)
        .background {
            // Tint the user's own turns so the conversation reads as alternating.
            if message.role == .user {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.user.opacity(0.07))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.user.opacity(0.55))
                            .frame(width: 2.5)
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
            Button { preview = attachment } label: {
                HStack(spacing: 6) {
                    Image(systemName: attachment.symbol)
                    Text(attachment.name).lineLimit(1)
                    Text(attachment.typeLabel)
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .font(Theme.mono(11))
                .foregroundStyle(Theme.highlight)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.surfaceElevated)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Click to preview")
        }
    }

    // MARK: - Assistant text (colored summary / achievements)

    /// Render an assistant text block line-by-line so we can tint the parts that
    /// summarize what was achieved: completed actions green, summary headers
    /// highlighted, failures red, everything else default.
    private func assistantText(_ value: String) -> some View {
        let lines = value.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                assistantLine(line)
            }
        }
    }

    @ViewBuilder
    private func assistantLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 5)
        } else if trimmed.hasPrefix("⚙") {
            toolActivityRow(trimmed)
        } else {
            Text(line)
                .font(Theme.mono(12.5, weight: assistantLineWeight(line)))
                .foregroundStyle(assistantLineColor(line))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A scannable, color-coded row for an agent action ("⚙︎ Edit · file.dart"),
    /// so the conversation visibly shows what the agent is doing.
    private func toolActivityRow(_ line: String) -> some View {
        let afterGlyph = line.drop { !$0.isLetter }            // "Edit · file.dart"
        let name = String(afterGlyph.prefix { $0.isLetter })   // "Edit"
        let style = Self.toolStyle(name)
        return HStack(spacing: 6) {
            Image(systemName: style.symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(afterGlyph.isEmpty ? line : String(afterGlyph))
                .font(Theme.mono(11.5, weight: .medium))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(style.color.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    /// Icon + color per agent tool: inspecting = blue, editing = amber,
    /// running = green, sub-task = accent.
    private static func toolStyle(_ name: String) -> (symbol: String, color: Color) {
        switch name {
        case "Read":                         return ("doc.text", Theme.highlight)
        case "Edit", "Write", "NotebookEdit": return ("pencil.line", Theme.warning)
        case "Bash":                         return ("terminal", Theme.success)
        case "Grep", "Glob":                 return ("magnifyingglass", Theme.highlight)
        case "Task":                         return ("sparkles", Theme.accent)
        default:                              return ("gearshape", Theme.textSecondary)
        }
    }

    private static let doneWords: Set<String> = [
        "added", "fixed", "created", "implemented", "updated", "removed", "deleted",
        "renamed", "merged", "pushed", "committed", "passed", "completed", "done",
        "wired", "introduced", "resolved", "bumped", "refactored", "replaced",
        "enabled", "disabled", "migrated", "built", "shipped", "verified"
    ]
    private static let failWords: Set<String> = [
        "failed", "error", "blocked", "unable", "cannot", "broken"
    ]
    private static let headerWords: Set<String> = [
        "summary", "changes", "achievements", "achieved", "result", "results",
        "outcome", "what", "done"
    ]

    /// First word after any leading bullet / marker glyphs, lowercased.
    private func firstWord(_ line: String) -> String {
        let body = line.trimmingCharacters(in: .whitespaces)
            .drop { "•-*◦·–—>».✦✓✅✔☑✗✘⛔❌ ".contains($0) }
        return body.prefix { $0.isLetter }.lowercased()
    }

    private func assistantLineColor(_ line: String) -> Color {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("STATUS: FAIL") { return Theme.danger }
        if trimmed.contains("STATUS: PASS") { return Theme.success }
        if let f = trimmed.first, "✗✘⛔❌".contains(f) { return Theme.danger }
        if let f = trimmed.first, "✓✅✔☑".contains(f) { return Theme.success }

        let word = firstWord(line)
        if Self.failWords.contains(word) { return Theme.danger }
        if Self.doneWords.contains(word) { return Theme.success }
        // Summary headers are usually a short label line (often ending in ":").
        if Self.headerWords.contains(word) && (trimmed.hasSuffix(":") || trimmed.count <= 28) {
            return Theme.highlight
        }
        return textColor
    }

    private func assistantLineWeight(_ line: String) -> Font.Weight {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if Self.headerWords.contains(firstWord(line)) && (trimmed.hasSuffix(":") || trimmed.count <= 28) {
            return .semibold
        }
        return .regular
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
                PlanActionButtons(messageID: message.id)
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

/// Approve/Reject buttons for a proposed plan. Split out so it (not the whole
/// message row) is the only thing holding the model — keeps message rows from
/// re-rendering on every composer keystroke.
private struct PlanActionButtons: View {
    @EnvironmentObject private var model: AppModel
    let messageID: UUID

    var body: some View {
        HStack {
            Button("Approve & Apply") { model.approvePlan(messageID: messageID) }
                .buttonStyle(.borderedProminent)
            Button("Reject") { model.rejectPlan(messageID: messageID) }
                .buttonStyle(.bordered)
        }
        .controlSize(.small)
    }
}
