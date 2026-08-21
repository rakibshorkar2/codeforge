import Foundation

protocol AgentAuditLogProtocol {
    func record(toolName: String, filePath: String, success: Bool, errorMessage: String?)
    func entries() -> [AuditLogEntry]
    func clear()
}

final class AgentAuditLog: AgentAuditLogProtocol {
    @Published private(set) var logEntries: [AuditLogEntry] = []
    private let maxEntries: Int

    init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    func record(toolName: String, filePath: String, success: Bool, errorMessage: String? = nil) {
        let entry = AuditLogEntry(toolName: toolName, filePath: filePath, success: success, errorMessage: errorMessage)
        logEntries.append(entry)
        if logEntries.count > maxEntries {
            logEntries.removeFirst(logEntries.count - maxEntries)
        }
    }

    func entries() -> [AuditLogEntry] {
        logEntries
    }

    func clear() {
        logEntries.removeAll()
    }

    func entries(for toolName: String) -> [AuditLogEntry] {
        logEntries.filter { $0.toolName == toolName }
    }

    func failedEntries() -> [AuditLogEntry] {
        logEntries.filter { !$0.success }
    }
}
