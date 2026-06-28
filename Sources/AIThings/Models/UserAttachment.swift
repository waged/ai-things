import Foundation

/// Something the user attached to a message: an image, a file, or a path reference.
struct UserAttachment: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case image
        case file
        case filePath
        case codeSnippet
    }

    let id: UUID
    var kind: Kind
    var name: String
    /// File-system path for file / image / path attachments.
    var path: String?
    /// Raw image bytes (PNG) for pasted / dropped images.
    var imageData: Data?
    /// Inline text for code-snippet attachments.
    var snippet: String?

    init(
        id: UUID = UUID(),
        kind: Kind,
        name: String,
        path: String? = nil,
        imageData: Data? = nil,
        snippet: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.path = path
        self.imageData = imageData
        self.snippet = snippet
    }

    /// Lowercased file extension (from the path, else the name).
    var fileExtension: String {
        ((path ?? name) as NSString).pathExtension.lowercased()
    }

    /// Short type badge shown next to the name, e.g. "RTF", "TXT", "PNG".
    var typeLabel: String {
        let ext = fileExtension
        if !ext.isEmpty { return ext.uppercased() }
        switch kind {
        case .image: return "IMG"
        case .codeSnippet: return "CODE"
        case .filePath: return "PATH"
        case .file: return "FILE"
        }
    }

    /// SF Symbol for the chip / inline icon — specific to the file type.
    var symbol: String {
        switch kind {
        case .image:       return "photo"
        case .filePath:    return "link"
        case .codeSnippet: return "chevron.left.forwardslash.chevron.right"
        case .file:
            switch fileExtension {
            case "txt", "md", "markdown", "log", "text":  return "doc.text"
            case "rtf", "rtfd":                           return "doc.richtext"
            case "pdf":                                   return "doc.fill"
            case "json", "xml", "yml", "yaml", "plist", "toml": return "curlybraces"
            case "csv":                                   return "tablecells"
            case "zip", "gz", "tar", "tgz":               return "archivebox"
            case "swift", "js", "ts", "py", "java", "c", "h", "cpp",
                 "rb", "go", "rs", "kt", "dart", "html", "css", "sh":
                return "chevron.left.forwardslash.chevron.right"
            default:                                      return "doc"
            }
        }
    }

    /// Short id used inside inline reference tokens.
    var shortID: String { String(id.uuidString.prefix(8)) }

    /// Token embedded in the message text to mark where this attachment sits,
    /// e.g. `[[img:1A2B3C4D]]`. Rendered inline in chat; replaced with a file
    /// path when the message is sent to the AI.
    var inlineToken: String { "[[img:\(shortID)]]" }
}
