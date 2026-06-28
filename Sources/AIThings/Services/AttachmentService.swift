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

        // 1) File URLs (a file copied in Finder) — typed by its own extension.
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.map { attachment(for: $0) }
        }

        // 2) Real bitmap image data ONLY (screenshots / copied images). Crucially,
        //    require an actual PNG/TIFF/JPEG type before reading NSImage: NSImage
        //    also decodes RTF/RTFD, so Universal Clipboard rich text would
        //    otherwise be turned into a bogus "image". Rich text falls through to
        //    pasteboardText() and is pasted as plain text instead.
        let bitmapTypes: [NSPasteboard.PasteboardType] = [.png, .tiff, .init("public.jpeg")]
        guard pb.availableType(from: bitmapTypes) != nil,
              let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] else {
            return []
        }
        return images.compactMap { image in
            guard let data = image.pngData() else { return nil }
            // Name keyed on the attachment's own id so the chat name, the inline
            // token, and the saved file all match.
            var attachment = UserAttachment(kind: .image, name: "image.png", imageData: data)
            attachment.name = "image-\(attachment.shortID).png"
            return attachment
        }
    }

    /// Plain text currently on the pasteboard, if any. Falls back to flattening
    /// rich text (RTF/RTFD) to plain text — Universal Clipboard often delivers
    /// RTF, and we want it pasted as text, not as rich text.
    func pasteboardText() -> String? {
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .string), !s.isEmpty { return s }
        for type in [NSPasteboard.PasteboardType.rtf, .rtfd] {
            if let data = pb.data(forType: type),
               let attributed = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
                return attributed.string
            }
        }
        return nil
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
