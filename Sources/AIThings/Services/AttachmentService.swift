import Foundation
import AppKit
import UniformTypeIdentifiers

/// Builds `UserAttachment`s from the pasteboard, file pickers, and drag-and-drop.
final class AttachmentService {

    // MARK: - Pasteboard

    /// Read non-text items (images / files) from the general pasteboard.
    /// Covers screenshots copied to the clipboard (raw image data) and copied
    /// files (file URLs). Returns [] when the clipboard holds only text.
    func attachmentsFromPasteboard() -> [UserAttachment] {
        let pb = NSPasteboard.general
        var result: [UserAttachment] = []

        // 1) File URLs (e.g. a screenshot saved then copied in Finder).
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls { result.append(attachment(for: url)) }
        }

        // 2) Raw image data on the clipboard (Cmd-Ctrl-Shift-4 screenshots, copied images).
        if result.isEmpty,
           let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            for image in images {
                if let data = image.pngData() {
                    // Name keyed on the attachment's own id so the chat name,
                    // the inline token, and the saved file all match.
                    var attachment = UserAttachment(kind: .image, name: "image.png", imageData: data)
                    attachment.name = "image-\(attachment.shortID).png"
                    result.append(attachment)
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

    /// A filesystem path for an attachment, writing pasted image data to a temp
    /// file if needed — so the path can be handed to the AI (which reads files).
    func filePath(for attachment: UserAttachment) -> String? {
        if let path = attachment.path { return path }
        guard let data = attachment.imageData else { return nil }
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AIThings/attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Use the (sanitized) display name as the filename so the path's
        // basename matches the name shown in the chat. Name already carries the
        // unique short id, so collisions don't happen.
        let safeName = attachment.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\: ")).joined(separator: "-")
        let filename = safeName.isEmpty ? "\(attachment.id.uuidString).png" : safeName
        let url = dir.appendingPathComponent(filename)
        try? data.write(to: url)
        return url.path
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
