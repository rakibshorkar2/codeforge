import XCTest
@testable import CodeForge

final class AgentChangeTrackerTests: XCTestCase {
    func testSnapshotAndConflict() {
        var tracker = AgentChangeTracker()
        tracker.snapshot(path: "test.swift", content: "original")
        XCTAssertFalse(tracker.hasConflict(path: "test.swift", currentContent: "original"))
        XCTAssertTrue(tracker.hasConflict(path: "test.swift", currentContent: "modified"))
    }

    func testRecordChange() {
        var tracker = AgentChangeTracker()
        tracker.recordChange(AgentChangeTracker.FileChange(path: "a.swift", operation: .create, newContent: "content"))
        XCTAssertEqual(tracker.pendingChanges.count, 1)
        XCTAssertEqual(tracker.pendingChanges.first?.operation, .create)
    }

    func testRollbackCreate() throws {
        let tmp = NSTemporaryDirectory()
        let ws = (tmp as NSString).appendingPathComponent("rollback_\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: ws, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: ws) }

        let filePath = "new.txt"
        let fullPath = (ws as NSString).appendingPathComponent(filePath)
        try "hello".write(toFile: fullPath, atomically: true, encoding: .utf8)

        var tracker = AgentChangeTracker()
        tracker.recordChange(AgentChangeTracker.FileChange(path: filePath, operation: .create, newContent: "hello"))
        let rolled = tracker.rollback(workspace: ws)
        XCTAssertEqual(rolled.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fullPath))
    }

    func testRollbackModify() throws {
        let tmp = NSTemporaryDirectory()
        let ws = (tmp as NSString).appendingPathComponent("rollback_\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: ws, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: ws) }

        let filePath = "edit.txt"
        let fullPath = (ws as NSString).appendingPathComponent(filePath)
        try "original".write(toFile: fullPath, atomically: true, encoding: .utf8)

        var tracker = AgentChangeTracker()
        tracker.snapshot(path: filePath, content: "original")
        tracker.recordChange(AgentChangeTracker.FileChange(path: filePath, operation: .modify, oldContent: "original", newContent: "modified"))

        try "modified".write(toFile: fullPath, atomically: true, encoding: .utf8)
        let rolled = tracker.rollback(workspace: ws)
        XCTAssertEqual(rolled.count, 1)
        let content = try String(contentsOfFile: fullPath, encoding: .utf8)
        XCTAssertEqual(content, "original")
    }

    func testChangeSummary() {
        var tracker = AgentChangeTracker()
        tracker.recordChange(AgentChangeTracker.FileChange(path: "a.swift", operation: .create))
        tracker.recordChange(AgentChangeTracker.FileChange(path: "b.swift", operation: .modify))
        let summary = tracker.changeSummary
        XCTAssertEqual(summary["a.swift"], .create)
        XCTAssertEqual(summary["b.swift"], .modify)
    }

    func testClear() {
        var tracker = AgentChangeTracker()
        tracker.recordChange(AgentChangeTracker.FileChange(path: "a.swift", operation: .create))
        tracker.snapshot(path: "b.swift", content: "x")
        tracker.clear()
        XCTAssertTrue(tracker.pendingChanges.isEmpty)
        XCTAssertTrue(tracker.snapshots.isEmpty)
    }
}

final class AgentSessionStoreTests: XCTestCase {
    func testSaveAndLoad() throws {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let store = AgentSessionStore(defaults: defaults)
        let session = PersistedAgentSession(from: makeSession())
        try store.save(session)
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, session.id)
    }

    func testDelete() throws {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let store = AgentSessionStore(defaults: defaults)
        let session = PersistedAgentSession(from: makeSession())
        try store.save(session)
        try store.delete(id: session.id)
        let loaded = try store.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSessionsForProject() throws {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let store = AgentSessionStore(defaults: defaults)
        let s1 = PersistedAgentSession(from: makeSession(projectID: "p1"))
        let s2 = PersistedAgentSession(from: makeSession(projectID: "p2"))
        try store.save(s1)
        try store.save(s2)
        let filtered = try store.sessions(forProject: "p1")
        XCTAssertEqual(filtered.count, 1)
    }

    private func makeSession(projectID: String = "test") -> AgentSession {
        AgentSession(projectID: projectID, projectName: "Test", workspace: "/tmp")
    }
}

final class AgentPermissionFlowTests: XCTestCase {
    func testAutoAllowRead() async {
        let manager = AgentPermissionManager()
        let decision = await manager.requestPermissionAsync(level: .read, resource: "test.swift")
        XCTAssertEqual(decision, .allowOnce)
    }

    func testAskDestructiveWrite() async {
        let manager = AgentPermissionManager()
        manager.setPolicy(.askDestructive, for: .write)
        let decision = await manager.requestPermissionAsync(level: .write, resource: "test.swift")
        XCTAssertEqual(decision, .deny)
    }

    func testSessionGrant() async {
        let manager = AgentPermissionManager()
        manager.grantSessionPermission(level: .write)
        let decision = await manager.requestPermissionAsync(level: .write, resource: "test.swift")
        XCTAssertEqual(decision, .allowForSession)
    }

    func testRespondToRequest() async {
        let manager = AgentPermissionManager()
        manager.setPolicy(.askEveryTime, for: .write)

        let task = Task {
            await manager.requestPermissionAsync(level: .write, resource: "test.swift")
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        if let request = manager.currentRequest {
            manager.respondToRequest(id: request.id, decision: .allowOnce)
        }

        let result = await task.value
        XCTAssertEqual(result, .allowOnce)
    }
}

final class AgentContextManagerTestsV2: XCTestCase {
    func testExtractReferencedFiles() {
        let ctx = AgentContextManager(workspace: "/tmp")
        let files = ctx.extractReferencedFiles(from: "Please edit `DashboardView.swift` and read `AppDelegate.swift`")
        XCTAssertTrue(files.contains("DashboardView.swift"))
        XCTAssertTrue(files.contains("AppDelegate.swift"))
    }

    func testSummarizeToolResults() {
        let ctx = AgentContextManager(workspace: "/tmp")
        let results = [
            ToolResult(toolCallID: "1", content: "File content here"),
            ToolResult(toolCallID: "2", content: "Another result", isError: true),
        ]
        let summary = ctx.summarizeToolResults(results, maxTokens: 1000)
        XCTAssertTrue(summary.contains("File content here"))
        XCTAssertTrue(summary.contains("[ERROR]"))
    }

    func testEstimateTokens() {
        let ctx = AgentContextManager(workspace: "/tmp")
        let estimate = ctx.estimateTokens("Hello World")
        XCTAssertEqual(estimate, 2)
    }
}
