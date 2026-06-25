import Foundation

/// High-level git operations exposed in the toolbar.
/// `isDestructive` drives the mandatory confirmation prompt.
enum GitAction: String, CaseIterable, Identifiable {
    case newBranch
    case feature
    case bugFix
    case commit
    case push
    case pull
    case showChanges
    case discardChanges
    case openInFinder
    case openInXcode
    case openTerminalHere

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newBranch:        return "New Branch"
        case .feature:          return "Feature"
        case .bugFix:           return "Bug Fix"
        case .commit:           return "Commit"
        case .push:             return "Push"
        case .pull:             return "Pull"
        case .showChanges:      return "Show Changes"
        case .discardChanges:   return "Discard Changes"
        case .openInFinder:     return "Open in Finder"
        case .openInXcode:      return "Open in Xcode"
        case .openTerminalHere: return "Open Terminal Here"
        }
    }

    var symbol: String {
        switch self {
        case .newBranch:        return "arrow.branch"
        case .feature:          return "sparkles"
        case .bugFix:           return "ant"
        case .commit:           return "checkmark.seal"
        case .push:             return "arrow.up.circle"
        case .pull:             return "arrow.down.circle"
        case .showChanges:      return "doc.text.magnifyingglass"
        case .discardChanges:   return "trash"
        case .openInFinder:     return "folder"
        case .openInXcode:      return "hammer"
        case .openTerminalHere: return "terminal"
        }
    }

    /// Destructive actions always require explicit confirmation.
    var isDestructive: Bool {
        switch self {
        case .discardChanges, .push: return true
        default: return false
        }
    }
}
