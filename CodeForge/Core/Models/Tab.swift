import Foundation

enum Tab: String, CaseIterable, Identifiable {
    case projects
    case agent
    case files
    case builds
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .agent: return "Agent"
        case .files: return "Files"
        case .builds: return "Builds"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: return "folder"
        case .agent: return "brain.head.profile"
        case .files: return "doc.text"
        case .builds: return "hammer"
        case .settings: return "gearshape"
        }
    }
}
