import Foundation

/// A git branch in the current repository.
struct GitBranch: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    var isCurrent: Bool
    var isRemote: Bool

    init(name: String, isCurrent: Bool = false, isRemote: Bool = false) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
    }
}

/// The kind of branch the user is creating, used to build the branch prefix.
enum BranchKind: String, CaseIterable, Identifiable {
    case feature
    case bugfix
    case refactor
    case experiment
    case hotfix

    var id: String { rawValue }

    /// The git prefix, e.g. "feature/", "bugfix/".
    var prefix: String { rawValue + "/" }

    var label: String {
        switch self {
        case .feature: return "Feature"
        case .bugfix: return "Bug fix"
        case .refactor: return "Refactor"
        case .experiment: return "Experiment"
        case .hotfix: return "Hotfix"
        }
    }

    var symbol: String {
        switch self {
        case .feature: return "sparkles"
        case .bugfix: return "ant"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .experiment: return "flask"
        case .hotfix: return "flame"
        }
    }
}
