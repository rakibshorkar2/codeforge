import Foundation

struct FileSnapshot: Codable {
    let path: String
    let content: String
    let timestamp: Date
}

struct AgentChangeTracker {
    private(set) var snapshots: [String: FileSnapshot] = [:]
    private(set) var pendingChanges: [FileChange] = []

    struct FileChange: Codable, Identifiable {
        let id: UUID
        let path: String
        let operation: Operation
        let oldContent: String?
        let newContent: String?
        let timestamp: Date

        enum Operation: String, Codable {
            case create
            case modify
            case delete
            case rename
            case move
        }

        init(path: String, operation: Operation, oldContent: String? = nil, newContent: String? = nil) {
            self.id = UUID()
            self.path = path
            self.operation = operation
            self.oldContent = oldContent
            self.newContent = newContent
            self.timestamp = Date()
        }
    }

    mutating func snapshot(path: String, content: String) {
        snapshots[path] = FileSnapshot(path: path, content: content, timestamp: Date())
    }

    mutating func recordChange(_ change: FileChange) {
        pendingChanges.append(change)
    }

    func snapshot(for path: String) -> FileSnapshot? {
        snapshots[path]
    }

    func hasConflict(path: String, currentContent: String) -> Bool {
        guard let snapshot = snapshots[path] else { return false }
        return snapshot.content != currentContent
    }

    mutating func rollback(workspace: String) -> [String] {
        var rolledBack: [String] = []
        let fm = FileManager.default

        for change in pendingChanges.reversed() {
            let fullPath = (workspace as NSString).appendingPathComponent(change.path)
            switch change.operation {
            case .create:
                try? fm.removeItem(atPath: fullPath)
                rolledBack.append(change.path)
            case .modify:
                if let oldContent = change.oldContent {
                    try? oldContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
                    rolledBack.append(change.path)
                }
            case .delete:
                if let oldContent = change.oldContent {
                    let dir = (fullPath as NSString).deletingLastPathComponent
                    if !fm.fileExists(atPath: dir) {
                        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    }
                    try? oldContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
                    rolledBack.append(change.path)
                }
            case .rename, .move:
                if let oldContent = change.oldContent {
                    try? oldContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
                    rolledBack.append(change.path)
                }
            }
        }

        pendingChanges.removeAll()
        return rolledBack
    }

    mutating func clear() {
        snapshots.removeAll()
        pendingChanges.removeAll()
    }

    var changeSummary: [String: Operation] {
        var summary: [String: Operation] = [:]
        for change in pendingChanges {
            summary[change.path] = change.operation
        }
        return summary
    }

    typealias Operation = FileChange.Operation
}
