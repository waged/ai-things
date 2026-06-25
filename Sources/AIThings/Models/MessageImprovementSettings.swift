import Foundation

/// The three composer toggles that shape how a message is processed before
/// it reaches the main assistant.
struct MessageImprovementSettings: Codable, Equatable {
    /// "Make message clearer" – rewrite the user message to be short and direct.
    var makeClearer: Bool = false
    /// "Ask questions first" – the assistant clarifies before touching files.
    var askQuestionsFirst: Bool = false
    /// "Direct mode" – concise, bullet-point answers focused on actions.
    var directMode: Bool = true
}
