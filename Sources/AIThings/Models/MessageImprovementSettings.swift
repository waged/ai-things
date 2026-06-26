import Foundation

/// Composer behavior toggles that shape how the assistant responds.
/// (Cleaning up the draft text is a one-shot action, not a toggle.)
struct MessageImprovementSettings: Codable, Equatable {
    /// "Ask questions first" – the assistant clarifies before touching files.
    var askQuestionsFirst: Bool = false
    /// "Direct mode" – concise, bullet-point answers focused on actions.
    var directMode: Bool = true
    /// "Precise" – answer as briefly as possible; terse fragments over prose,
    /// trading grammar for brevity to save tokens.
    var precise: Bool = false

    private enum CodingKeys: String, CodingKey { case askQuestionsFirst, directMode, precise }

    init(askQuestionsFirst: Bool = false, directMode: Bool = true, precise: Bool = false) {
        self.askQuestionsFirst = askQuestionsFirst
        self.directMode = directMode
        self.precise = precise
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        askQuestionsFirst = (try? c.decode(Bool.self, forKey: .askQuestionsFirst)) ?? false
        directMode = (try? c.decode(Bool.self, forKey: .directMode)) ?? true
        precise = (try? c.decode(Bool.self, forKey: .precise)) ?? false
    }
}
