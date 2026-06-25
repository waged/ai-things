import Foundation
import AppKit
import UniformTypeIdentifiers

/// Builds `UserAttachment`s from the pasteboard, file pickers, and drag-and-drop.
final class AttachmentService {

    // MARK: - Pasteboard

    /// Read images and/or text from the general pasteboard.
    /// Returns image attachments first, then a code snippet if text is present.
    func attachmentsFromPasteboard() -> [UserAttachment] {
        let pb = NSPasteboard.general
        var result: [UserAttachment] = []

        // Images (direct image data, or file URLs pointing at images).
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            for (index, image) in images.enumerated() {
                if let data = image.pngData() {
                    result.append(UserAttachment(
                        kind: .image,
                        name: "pasted-image-\(index + 1).png",
                        imageData: data
                    ))
                }
            }
        }
        return result
    }

    /// Plain text currently on the pasteboard, if any.
    func pasteboardText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    // MARK: - Pickers

    @MainActor
    func pickImage() -> UserAttachment? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let data = try? Data(contentsOf: url)
        return UserAttachment(kind: .image, name: url.lastPathComponent, path: url.path, imageData: data)
    }

    @MainActor
    func pickFile() -> UserAttachment? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return UserAttachment(kind: .file, name: url.lastPathComponent, path: url.path)
    }

    // MARK: - Drag & drop

    /// Build an attachment from a dropped file URL.
    func attachment(for url: URL) -> UserAttachment {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            let data = try? Data(contentsOf: url)
            return UserAttachment(kind: .image, name: url.lastPathComponent, path: url.path, imageData: data)
        }
        return UserAttachment(kind: .file, name: url.lastPathComponent, path: url.path)
    }
}

extension NSImage {
    /// PNG representation, used to persist pasted/dropped images.
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
