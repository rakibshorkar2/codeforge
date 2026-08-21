import Foundation

struct PersistedAgentSession: Codable, Identifiable {
    let id: UUID
    let projectID: String
    let projectName: String
    let workspace: String
    var messages: [AgentMessage]
    var tokenUsage: AgentTokenUsage
    var iterationCount: Int
    let createdAt: Date
    var modifiedAt: Date

    init(from session: AgentSession) {
        self.id = session.id
        self.projectID = session.projectID
        self.projectName = session.projectName
        self.workspace = session.workspace
        self.messages = session.messages
        self.tokenUsage = session.tokenUsage
        self.iterationCount = session.iterationCount
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

protocol AgentSessionStoreProtocol {
    func save(_ session: PersistedAgentSession) throws
    func loadAll() throws -> [PersistedAgentSession]
    func load(id: UUID) throws -> PersistedAgentSession?
    func delete(id: UUID) throws
    func sessions(forProject projectID: String) throws -> [PersistedAgentSession]
}

final class AgentSessionStore: AgentSessionStoreProtocol {
    private let defaults: UserDefaults
    private let storageKey = "agent_sessions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ session: PersistedAgentSession) throws {
        var sessions = try loadAll()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        let data = try JSONEncoder().encode(sessions)
        defaults.set(data, forKey: storageKey)
    }

    func loadAll() throws -> [PersistedAgentSession] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return try JSONDecoder().decode([PersistedAgentSession].self, from: data)
    }

    func load(id: UUID) throws -> PersistedAgentSession? {
        let sessions = try loadAll()
        return sessions.first { $0.id == id }
    }

    func delete(id: UUID) throws {
        var sessions = try loadAll()
        sessions.removeAll { $0.id == id }
        let data = try JSONEncoder().encode(sessions)
        defaults.set(data, forKey: storageKey)
    }

    func sessions(forProject projectID: String) throws -> [PersistedAgentSession] {
        try loadAll().filter { $0.projectID == projectID }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}
