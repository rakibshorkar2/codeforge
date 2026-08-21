import Foundation

enum PermissionLevel: String, Codable, CaseIterable, Comparable {
    case read
    case write
    case delete
    case execute
    case network
    case github

    var displayName: String {
        switch self {
        case .read: return "Read Files"
        case .write: return "Write Files"
        case .delete: return "Delete Files"
        case .execute: return "Execute Commands"
        case .network: return "Network Access"
        case .github: return "GitHub Access"
        }
    }

    var destructive: Bool {
        switch self {
        case .read, .execute: return false
        case .write, .delete, .network, .github: return true
        }
    }

    static func < (lhs: PermissionLevel, rhs: PermissionLevel) -> Bool {
        let order: [PermissionLevel] = [.read, .write, .delete, .execute, .network, .github]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

enum PermissionPolicy: String, Codable, CaseIterable {
    case askEveryTime = "Ask Every Time"
    case askDestructive = "Ask for Destructive"
    case allowAutomatically = "Allow Automatically"

    var displayName: String { rawValue }
}

protocol AgentPermissionManagerProtocol {
    func requestPermission(level: PermissionLevel, resource: String) -> Bool
    func setPolicy(_ policy: PermissionPolicy, for level: PermissionLevel)
    func policy(for level: PermissionLevel) -> PermissionPolicy
    func allowedLevels() -> Set<PermissionLevel>
}

final class AgentPermissionManager: AgentPermissionManagerProtocol {
    private var policies: [PermissionLevel: PermissionPolicy]
    private var pendingRequests: [UUID: (Bool) -> Void] = [:]

    init(policies: [PermissionLevel: PermissionPolicy]? = nil) {
        if let policies = policies {
            self.policies = policies
        } else {
            self.policies = [:]
            for level in PermissionLevel.allCases {
                self.policies[level] = level.destructive ? .askDestructive : .allowAutomatically
            }
        }
    }

    func requestPermission(level: PermissionLevel, resource: String) -> Bool {
        let policy = policies[level] ?? .askDestructive
        switch policy {
        case .allowAutomatically:
            return true
        case .askDestructive:
            if !level.destructive { return true }
            return false
        case .askEveryTime:
            return false
        }
    }

    func requestPermissionAsync(level: PermissionLevel, resource: String) async -> Bool {
        let policy = policies[level] ?? .askDestructive
        switch policy {
        case .allowAutomatically:
            return true
        case .askDestructive:
            return level.destructive ? false : true
        case .askEveryTime:
            return false
        }
    }

    func setPolicy(_ policy: PermissionPolicy, for level: PermissionLevel) {
        policies[level] = policy
    }

    func policy(for level: PermissionLevel) -> PermissionPolicy {
        policies[level] ?? .askDestructive
    }

    func allowedLevels() -> Set<PermissionLevel> {
        var allowed: Set<PermissionLevel> = []
        for level in PermissionLevel.allCases {
            if requestPermission(level: level, resource: "") {
                allowed.insert(level)
            }
        }
        return allowed
    }
}
