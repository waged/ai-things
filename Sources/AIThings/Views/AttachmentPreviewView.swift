import SwiftUI

/// Horizontal strip of attachment chips. Images show a small thumbnail.
/// When `onRemove` is provided, each chip gets a remove button (composer use).
struct AttachmentPreviewView: View {
    let attachments: [UserAttachment]
    var onRemove: ((UserAttachment) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    chip(for: attachment)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for attachment: UserAttachment) -> some View {
        HStack(spacing: 6) {
            if attachment.kind == .image,
               let data = attachment.imageData,
               let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
