import SwiftUI

/// Horizontal strip of attachment chips. Images show a small thumbnail that
/// can be clicked to open an enlarged preview. When `onRemove` is provided,
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
            if attachment.kind == .image,
               let data = attachment.imageData,
               let image = NSImage(data: data) {
                Button { preview = attachment } label: {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Click to enlarge")
            } else {
                Image(systemName: attachment.symbol)
                    .foregroundStyle(Theme.highlight)
            }

            Text(attachment.name)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

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
}

/// Enlarged image preview shown in a resizable sheet.
struct ImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: UserAttachment

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

            if let data = attachment.imageData, let image = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                }
                .background(Theme.background)
            } else {
                Text("No preview available")
                    .font(Theme.mono(12)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .frame(minWidth: 480, idealWidth: 760, minHeight: 360, idealHeight: 600)
    }
}
