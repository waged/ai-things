import SwiftUI
import AppKit

/// Horizontal strip of attachment chips. Images show a small thumbnail that
/// can be clicked to open an enlarged preview; other files show a type-specific
/// icon + type badge and open a text/preview sheet. When `onRemove` is provided,
/// each chip also gets a remove button (composer use).
struct AttachmentPreviewView: View {
    let attachments: [UserAttachment]
    var onRemove: ((UserAttachment) -> Void)?

    @State private var preview: UserAttachment?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    chip(for: attachment)
                }
            }
        }
        .sheet(item: $preview) { ImagePreviewView(attachment: $0) }
    }

    @ViewBuilder
    private func chip(for attachment: UserAttachment) -> some View {
        HStack(spacing: 6) {
            Button { preview = attachment } label: {
                HStack(spacing: 6) {
                    thumbnailOrIcon(attachment)
                    Text(attachment.name)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    typeBadge(attachment.typeLabel)
                }
            }
            .buttonStyle(.plain)
            .help(attachment.kind == .image ? "Click to enlarge" : "Click to preview")

            if let onRemove {
                Button { onRemove(attachment) } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.surfaceElevated)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func thumbnailOrIcon(_ attachment: UserAttachment) -> some View {
        if attachment.kind == .image, let data = attachment.imageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1))
        } else {
            Image(systemName: attachment.symbol)
                .foregroundStyle(Theme.highlight)
        }
    }

    private func typeBadge(_ label: String) -> some View {
        Text(label)
            .font(Theme.mono(8, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

extension UserAttachment {
    /// Best-effort plain-text preview: an inline snippet, an RTF flattened to
    /// text, or a UTF-8 file's contents. nil for binary / unsupported files.
    func loadTextPreview() -> String? {
        if let snippet { return snippet }
        guard let path else { return nil }
        let url = URL(fileURLWithPath: path)
        if fileExtension == "rtf" || fileExtension == "rtfd" {
            guard let data = try? Data(contentsOf: url),
                  let attributed = try? NSAttributedString(data: data, options: [:], documentAttributes: nil)
            else { return nil }
            return attributed.string
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

/// Enlarged image preview shown in a resizable sheet.
struct ImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: UserAttachment

    private var previewImage: NSImage? {
        if let data = attachment.imageData, let img = NSImage(data: data) { return img }
        if attachment.kind == .image, let path = attachment.path { return NSImage(contentsOfFile: path) }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(attachment.name)
                    .font(Theme.mono(12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(Theme.accent)
            }
            .padding(12)
            .background(Theme.surface)
            Divider().overlay(Theme.border)

            if let image = previewImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                }
                .background(Theme.background)
            } else if let text = attachment.loadTextPreview() {
                ScrollView([.vertical]) {
                    Text(text)
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .background(Theme.background)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: attachment.symbol).font(.system(size: 32))
                        .foregroundStyle(Theme.textSecondary)
                    Text("No preview for \(attachment.typeLabel) files")
                        .font(Theme.mono(12)).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .frame(minWidth: 480, idealWidth: 760, minHeight: 360, idealHeight: 600)
    }
}
