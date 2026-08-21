import Foundation

enum ProjectType: String, CaseIterable, Codable, Identifiable {
    case swiftiOS = "swift_ios"
    case swiftPackage = "swift_package"
    case python = "python"
    case javascript = "javascript"
    case typescript = "typescript"
    case web = "web"
    case empty = "empty"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swiftiOS: return "Swift iOS"
        case .swiftPackage: return "Swift Package"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .web: return "Web"
        case .empty: return "Empty Project"
        }
    }

    var language: String {
        switch self {
        case .swiftiOS, .swiftPackage: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .web: return "HTML/CSS"
        case .empty: return "None"
        }
    }

    var icon: String {
        switch self {
        case .swiftiOS: return "iphone"
        case .swiftPackage: return "package"
        case .python: return "doc.text"
        case .javascript: return "curlybraces"
        case .typescript: return "curlybraces"
        case .web: return "globe"
        case .empty: return "folder"
        }
    }

    var fileExtension: String {
        switch self {
        case .swiftiOS, .swiftPackage: return "swift"
        case .python: return "py"
        case .javascript: return "js"
        case .typescript: return "ts"
        case .web: return "html"
        case .empty: return ""
        }
    }
}

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: ProjectType
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: ProjectType = .empty,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var directoryName: String {
        name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }
}
