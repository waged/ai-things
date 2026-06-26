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

/// Which semantic-version component the "Bump version" step increments.
enum VersionBump: String, Codable, CaseIterable, Identifiable {
    case major, minor, patch
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
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

    /// Automation pipeline: run post-task steps after each sent task.
    var automationEnabled: Bool = false
    var automationSteps: [AutomationStep] = AutomationStep.defaults
    /// Target branch for the "Merge & push" step. Empty = auto-detect main/master.
    var releaseBranch: String = ""
    /// Rules the "Review" automation step checks the change against. Editable.
    var reviewRules: String = AppSettings.defaultReviewRules
    /// Instructions the "Test" automation step follows when adding/adjusting
    /// tests for the change. Editable.
    var testRules: String = AppSettings.defaultTestRules
    /// Which version component the "Bump version" step increments.
    var versionBump: VersionBump = .patch

    static let defaultReviewRules = """
    - Follow MVVM: keep views declarative; put logic in the view model, not the view.
    - Separate UI from business logic; no networking/file/db calls inside views.
    - Use SwiftUI state correctly (@State/@StateObject/@ObservedObject/@Binding); single source of truth.
    - Do heavy work off the main thread; only update UI on the main actor.
    - No force-unwraps or force-try in non-test code; handle errors and edge cases.
    - Small, well-named functions; match the surrounding style; no dead code.
    """

    static let defaultTestRules = """
    - Add tests for the new or changed behavior this task introduced.
    - Update existing tests that this change affects; don't weaken or delete assertions just to make them pass.
    - Cover edge cases and error paths, not only the happy path.
    - Match the project's existing test framework, layout, and naming.
    - Keep tests fast, isolated, and deterministic (avoid real network/disk/time where possible).
    """

    init() {}

    // Tolerant decoding so adding new fields never wipes saved settings.
    private enum CodingKeys: String, CodingKey {
        case providerKind, modelName, customEndpoint, skipPermissions, autoApplyTrustedChanges
        case defaultImprovement, confirmDestructiveActions, mockStreamDelay
        case automationEnabled, automationSteps, releaseBranch, reviewRules, testRules, versionBump
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        providerKind = (try? c.decode(AIProviderKind.self, forKey: .providerKind)) ?? .claudeCode
        modelName = (try? c.decode(String.self, forKey: .modelName)) ?? ""
        customEndpoint = (try? c.decode(String.self, forKey: .customEndpoint)) ?? ""
        skipPermissions = (try? c.decode(Bool.self, forKey: .skipPermissions)) ?? true
        autoApplyTrustedChanges = (try? c.decode(Bool.self, forKey: .autoApplyTrustedChanges)) ?? false
        defaultImprovement = (try? c.decode(MessageImprovementSettings.self, forKey: .defaultImprovement)) ?? MessageImprovementSettings()
        confirmDestructiveActions = (try? c.decode(Bool.self, forKey: .confirmDestructiveActions)) ?? true
        mockStreamDelay = (try? c.decode(Double.self, forKey: .mockStreamDelay)) ?? 0.02
        automationEnabled = (try? c.decode(Bool.self, forKey: .automationEnabled)) ?? false
        releaseBranch = (try? c.decode(String.self, forKey: .releaseBranch)) ?? ""
        reviewRules = (try? c.decode(String.self, forKey: .reviewRules)) ?? AppSettings.defaultReviewRules
        testRules = (try? c.decode(String.self, forKey: .testRules)) ?? AppSettings.defaultTestRules
        versionBump = (try? c.decode(VersionBump.self, forKey: .versionBump)) ?? .patch
        let saved = (try? c.decode([AutomationStep].self, forKey: .automationSteps)) ?? []
        // Always present steps in the canonical pipeline order (review → test →
        // … → commit → merge&push), carrying over the user's enabled choices.
        // This also slots newly-added steps into their correct position rather
        // than appending them at the end.
        automationSteps = AutomationStep.defaults.map { def in
            if let s = saved.first(where: { $0.kind == def.kind }) {
                return AutomationStep(kind: def.kind, enabled: s.enabled)
            }
            return def
        }
    }
}
