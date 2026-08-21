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

    var icon: String {
        switch self {
        case .read: return "doc.text"
        case .write: return "pencil"
        case .delete: return "trash"
        case .execute: return "terminal"
        case .network: return "network"
        case .github: return "chevron.left.forwardslash.chevron.right"
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

enum PermissionDecision: Equatable {
    case allowOnce
    case allowForSession
    case deny
}

protocol AgentPermissionManagerProtocol: AnyObject {
    func requestPermission(level: PermissionLevel, resource: String) -> Bool
    func setPolicy(_ policy: PermissionPolicy, for level: PermissionLevel)
    func policy(for level: PermissionLevel) -> PermissionPolicy
    func allowedLevels() -> Set<PermissionLevel>
    func requestPermissionAsync(level: PermissionLevel, resource: String) async -> PermissionDecision
    func grantSessionPermission(level: PermissionLevel)
    func hasSessionGrant(for level: PermissionLevel) -> Bool
}

final class AgentPermissionManager: AgentPermissionManagerProtocol {
    private var policies: [PermissionLevel: PermissionPolicy]
    private var sessionGrants: Set<PermissionLevel> = []
    private var pendingContinuations: [UUID: CheckedContinuation<PermissionDecision, Never>] = [:]
    private var pendingRequests: [UUID: PendingPermissionRequest] = [:]

    @Published var currentRequest: PendingPermissionRequest?

    struct PendingPermissionRequest: Identifiable {
        let id = UUID()
        let level: PermissionLevel
        let resource: String
        let timestamp = Date()
    }

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
        if sessionGrants.contains(level) { return true }
        let policy = policies[level] ?? .askDestructive
        switch policy {
        case .allowAutomatically:
            return true
        case .askDestructive:
            return !level.destructive
        case .askEveryTime:
            return false
        }
    }

    func requestPermissionAsync(level: PermissionLevel, resource: String) async -> PermissionDecision {
        if sessionGrants.contains(level) { return .allowForSession }

        let policy = policies[level] ?? .askDestructive
        switch policy {
        case .allowAutomatically:
            return .allowOnce
        case .askDestructive:
            guard level.destructive else { return .allowOnce }
        case .askEveryTime:
            break
        }

        let request = PendingPermissionRequest(level: level, resource: resource)
        return await withCheckedContinuation { continuation in
            let id = request.id
            pendingContinuations[id] = continuation
            pendingRequests[id] = request
            Task { @MainActor in
                self.currentRequest = request
            }
        }
    }

    func respondToRequest(id: UUID, decision: PermissionDecision) {
        guard let request = pendingRequests[id] else { return }
        if decision == .allowForSession {
            sessionGrants.insert(request.level)
        }
        pendingContinuations[id]?.resume(returning: decision)
        pendingContinuations.removeValue(forKey: id)
        pendingRequests.removeValue(forKey: id)
        Task { @MainActor in
            self.currentRequest = nil
        }
    }

    func grantSessionPermission(level: PermissionLevel) {
        sessionGrants.insert(level)
    }

    func hasSessionGrant(for level: PermissionLevel) -> Bool {
        sessionGrants.contains(level)
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
