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

    var symbol: String {
        switch kind {
        case .image:       return "photo"
        case .file:        return "doc"
        case .filePath:    return "link"
        case .codeSnippet: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
