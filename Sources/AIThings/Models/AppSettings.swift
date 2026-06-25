import Foundation

/// Which AI backend the app talks to. Only `.mock` is wired up for now;
/// the others are placeholders that the AIService can be pointed at later.
enum AIProviderKind: String, Codable, CaseIterable, Identifiable {
    case claudeCode   // wraps the local `claude` CLI (real, default)
    case mock         // offline canned responses
    case claude       // Claude API (not yet wired)
    case openAI       // (not yet wired)
    case local        // (not yet wired)
    case custom       // (not yet wired)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claudeCode: return "Claude Code (CLI)"
        case .mock:       return "Mock (offline)"
        case .claude:     return "Claude API"
        case .openAI:     return "OpenAI API"
        case .local:      return "Local model"
        case .custom:     return "Custom backend"
        }
    }

    /// True once the backend is actually implemented.
    var isImplemented: Bool { self == .claudeCode || self == .mock }
}

/// Persisted application preferences.
struct AppSettings: Codable, Equatable {
    var providerKind: AIProviderKind = .claudeCode
    /// Model alias/id for the CLI's `--model` (empty = the CLI default).
    var modelName: String = ""
    /// Base URL for custom / local backends.
    var customEndpoint: String = ""

    /// Pass `--dangerously-skip-permissions` to the Claude Code CLI so edits
    /// apply without per-action prompts. This is the whole point of the app.
    var skipPermissions: Bool = true

    /// When enabled, trusted plans are applied without an approval prompt.
    var autoApplyTrustedChanges: Bool = false

    /// Default composer toggles for new sessions.
    var defaultImprovement: MessageImprovementSettings = MessageImprovementSettings()

    /// Confirm before destructive git / file actions. Strongly recommended on.
    var confirmDestructiveActions: Bool = true

    /// Simulated streaming speed for the mock provider, in seconds per chunk.
    var mockStreamDelay: Double = 0.02
}
