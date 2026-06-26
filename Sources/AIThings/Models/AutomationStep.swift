import Foundation

/// A post-task step in the automation pipeline. The user's own message is the
/// implicit "implement" step; these run as Claude follow-up turns after it.
struct AutomationStep: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case review
        case test
        case translations
        case updateDocs
        case bumpVersion
        case commit
        case mergeAndPush
    }

    var kind: Kind
    var enabled: Bool
    var id: String { kind.rawValue }

    /// Sensible default pipeline (review + docs on; the rest opt-in).
    static let defaults: [AutomationStep] = [
        AutomationStep(kind: .review, enabled: true),
        AutomationStep(kind: .test, enabled: false),
        AutomationStep(kind: .translations, enabled: false),
        AutomationStep(kind: .updateDocs, enabled: true),
        AutomationStep(kind: .bumpVersion, enabled: false),
        AutomationStep(kind: .commit, enabled: false),
        AutomationStep(kind: .mergeAndPush, enabled: false)
    ]
}

extension AutomationStep.Kind {
    var title: String {
        switch self {
        case .review:        return "Review"
        case .test:          return "Test"
        case .translations:  return "Translations"
        case .updateDocs:    return "Update docs"
        case .bumpVersion:   return "Bump version"
        case .commit:        return "Commit"
        case .mergeAndPush:  return "Merge & push"
        }
    }

    var symbol: String {
        switch self {
        case .review:        return "checkmark.shield"
        case .test:          return "checkmark.diamond"
        case .translations:  return "globe"
        case .updateDocs:    return "doc.text"
        case .bumpVersion:   return "number.circle"
        case .commit:        return "checkmark.seal"
        case .mergeAndPush:  return "arrow.triangle.merge"
        }
    }

    /// Gating steps must pass (verify → fix → re-verify); a failure stops the
    /// pipeline before commit/merge.
    var isGating: Bool { self == .review || self == .test }

    var detail: String {
        switch self {
        case .review:        return "Verify rules, fix, must pass (gate)"
        case .test:          return "Add/adjust tests, run, must pass (gate)"
        case .translations:  return "Add any missing translations"
        case .updateDocs:    return "Refresh CLAUDE.md & .aithings docs"
        case .bumpVersion:   return "Increment the project version"
        case .commit:        return "Commit the changes"
        case .mergeAndPush:  return "Merge into base branch & push"
        }
    }

    /// The follow-up instruction sent to Claude (resuming the same session).
    var prompt: String {
        switch self {
        case .review:
            return "Review the change you just made: confirm it is correct and builds/compiles. If you find problems, fix them. Then give a 1–2 line verdict."
        case .test:
            return "Make the project's tests reflect the change you just made: decide whether new behavior needs new tests and add them, and update any existing tests the change affects. Then detect the project's test command (e.g. xcodebuild test / swift test / npm test) and run the suite. If tests fail, fix them and re-run until green or explain what's blocking."
        case .mergeAndPush:
            // The target branch is injected by the app at run time.
            return "Commit any pending changes, then merge the current branch into the base branch and push it to origin. Report what you did."
        case .translations:
            return "Check whether this change added or modified any user-facing strings. If the project has localization/translation files, add the missing translations. If localization isn't used here, say so in one line."
        case .updateDocs:
            return "Update the project's AI docs to reflect this change: CLAUDE.md (overview/conventions if changed) and .aithings/status.html + features.html (status, progress entry, feature state). Only change what's outdated."
        case .bumpVersion:
            return "A unit of work was completed. Find where the project version is defined and increment it by one (patch/build as appropriate), then state the new version in one line."
        case .commit:
            return "Stage all changes and create one commit with a concise conventional-commit message describing what changed. Report the commit subject."
        }
    }
}
