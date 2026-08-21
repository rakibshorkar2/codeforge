import XCTest
@testable import CodeForge

final class AgentToolTests: XCTestCase {
    var workspace: String!
    var permissionManager: AgentPermissionManager!
    var auditLog: AgentAuditLog!
    var fm: FileManager!

    override func setUp() {
        super.setUp()
        fm = FileManager.default
        workspace = (NSTemporaryDirectory() as NSString).appendingPathComponent("agent_test_\(UUID().uuidString)")
        try? fm.createDirectory(atPath: workspace, withIntermediateDirectories: true)
        permissionManager = AgentPermissionManager()
        auditLog = AgentAuditLog()
    }

    override func tearDown() {
        try? fm.removeItem(atPath: workspace)
        super.tearDown()
    }

    func testCreateAndReadFile() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let result = try create.execute(parameters: ["path": "hello.txt", "content": "Hello World"], workspace: workspace)
        XCTAssertTrue(result.contains("created"))

        let read = ReadFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let content = try read.execute(parameters: ["path": "hello.txt"], workspace: workspace)
        XCTAssertEqual(content, "Hello World")
    }

    func testWriteFile() throws {
        let write = WriteFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try write.execute(parameters: ["path": "out.txt", "content": "data"], workspace: workspace)

        let read = ReadFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let content = try read.execute(parameters: ["path": "out.txt"], workspace: workspace)
        XCTAssertEqual(content, "data")
    }

    func testDeleteFile() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "del.txt", "content": ""], workspace: workspace)

        let delete = DeleteFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try delete.execute(parameters: ["path": "del.txt"], workspace: workspace)

        XCTAssertFalse(fm.fileExists(atPath: (workspace as NSString).appendingPathComponent("del.txt")))
    }

    func testEditFileSearchReplace() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "edit.txt", "content": "aaa bbb ccc"], workspace: workspace)

        let edit = EditFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try edit.execute(parameters: ["path": "edit.txt", "old_text": "bbb", "new_text": "XXX"], workspace: workspace)

        let read = ReadFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let content = try read.execute(parameters: ["path": "edit.txt"], workspace: workspace)
        XCTAssertEqual(content, "aaa XXX ccc")
    }

    func testEditFileNotFound() {
        let edit = EditFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        XCTAssertThrowsError(try edit.execute(parameters: ["path": "missing.txt", "old_text": "a", "new_text": "b"], workspace: workspace))
    }

    func testEditFileSearchNotFound() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "edit2.txt", "content": "hello"], workspace: workspace)

        let edit = EditFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        XCTAssertThrowsError(try edit.execute(parameters: ["path": "edit2.txt", "old_text": "ZZZZZ", "new_text": "YYY"], workspace: workspace))
    }

    func testPathTraversalRejection() {
        let read = ReadFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        XCTAssertThrowsError(try read.execute(parameters: ["path": "../etc/passwd"], workspace: workspace))
    }

    func testPermissionRejection() {
        let denyManager = AgentPermissionManager()
        denyManager.setPolicy(.askEveryTime, for: .read)
        let read = ReadFileTool(workspace: workspace, permissions: denyManager, auditLog: auditLog)
        XCTAssertThrowsError(try read.execute(parameters: ["path": "any.txt"], workspace: workspace))
    }

    func testListDirectory() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "a.txt", "content": ""], workspace: workspace)
        _ = try create.execute(parameters: ["path": "b.txt", "content": ""], workspace: workspace)

        let list = ListDirectoryTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let result = try list.execute(parameters: [:], workspace: workspace)
        XCTAssertTrue(result.contains("a.txt"))
        XCTAssertTrue(result.contains("b.txt"))
    }

    func testSearchFiles() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "main.swift", "content": ""], workspace: workspace)
        _ = try create.execute(parameters: ["path": "style.css", "content": ""], workspace: workspace)

        let search = SearchFilesTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let result = try search.execute(parameters: ["pattern": "*.swift"], workspace: workspace)
        XCTAssertTrue(result.contains("main.swift"))
        XCTAssertFalse(result.contains("style.css"))
    }

    func testSearchText() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "code.swift", "content": "func hello() {\n    print(\"hi\")\n}"], workspace: workspace)

        let search = SearchTextTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let result = try search.execute(parameters: ["query": "print"], workspace: workspace)
        XCTAssertTrue(result.contains("print"))
    }

    func testGetFileMetadata() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "meta.txt", "content": "data"], workspace: workspace)

        let meta = GetFileMetadataTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let result = try meta.execute(parameters: ["path": "meta.txt"], workspace: workspace)
        XCTAssertTrue(result.contains("File"))
        XCTAssertTrue(result.contains("meta.txt"))
    }

    func testGetProjectStructure() throws {
        let create = CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try create.execute(parameters: ["path": "src/main.swift", "content": ""], workspace: workspace)

        let structure = GetProjectStructureTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        let result = try structure.execute(parameters: [:], workspace: workspace)
        XCTAssertTrue(result.contains("src/"))
        XCTAssertTrue(result.contains("main.swift"))
    }

    func testCreateDirectory() throws {
        let dir = CreateDirectoryTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog)
        _ = try dir.execute(parameters: ["path": "newdir"], workspace: workspace)

        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: (workspace as NSString).appendingPathComponent("newdir"), isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testToolRegistry() {
        let registry = AgentToolRegistry.defaultRegistry(workspace: workspace, permissionManager: permissionManager, auditLog: auditLog)
        XCTAssertEqual(registry.availableTools.count, 13)
        XCTAssertNotNil(registry.tool(named: "read_file"))
        XCTAssertNotNil(registry.tool(named: "write_file"))
        XCTAssertNil(registry.tool(named: "nonexistent"))
    }
}

final class AgentModelTests: XCTestCase {
    func testAgentPlanAdvance() {
        var plan = AgentPlan(steps: [
            AgentPlan.Step(description: "Step 1", status: .pending),
            AgentPlan.Step(description: "Step 2", status: .pending),
        ])
        XCTAssertFalse(plan.isComplete)
        XCTAssertEqual(plan.currentStep?.description, "Step 1")

        plan.advanceStep()
        XCTAssertEqual(plan.currentStep?.description, "Step 2")

        plan.advanceStep()
        XCTAssertTrue(plan.isComplete)
    }

    func testAgentPlanMarkFailed() {
        var plan = AgentPlan(steps: [
            AgentPlan.Step(description: "Step 1", status: .pending),
        ])
        plan.markCurrentFailed()
        XCTAssertEqual(plan.currentStep?.status, .failed)
    }

    func testAgentTokenUsage() {
        var usage = AgentTokenUsage(promptTokens: 100, completionTokens: 50)
        XCTAssertEqual(usage.totalTokens, 150)

        usage.add(AgentTokenUsage(promptTokens: 50, completionTokens: 25))
        XCTAssertEqual(usage.totalTokens, 225)
    }

    func testAgentConfigDefaults() {
        let config = AgentConfig()
        XCTAssertEqual(config.maxIterations, 20)
        XCTAssertEqual(config.mode, .code)
    }

    func testAgentModeDescriptions() {
        XCTAssertFalse(AgentMode.ask.description.isEmpty)
        XCTAssertFalse(AgentMode.plan.description.isEmpty)
        XCTAssertFalse(AgentMode.code.description.isEmpty)
    }
}

final class AgentContextManagerTests: XCTestCase {
    func testBuildContext() {
        let tmp = NSTemporaryDirectory()
        let ws = (tmp as NSString).appendingPathComponent("ctx_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: ws, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: ws) }

        let ctx = AgentContextManager(workspace: ws, maxTokens: 8000)
        let messages = ctx.buildContext(userMessage: "Hello", recentEdits: [], toolResults: [], projectStructure: nil)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.first?.role, .system)
        XCTAssertEqual(messages.last?.role, .user)
    }

    func testTruncateConversation() {
        let ctx = AgentContextManager(workspace: NSTemporaryDirectory(), maxTokens: 100)
        var msgs: [AIMessage] = []
        for i in 0..<20 {
            msgs.append(AIMessage(role: .user, content: String(repeating: "x", count: 100)))
        }
        let truncated = ctx.truncateConversation(msgs)
        XCTAssertLessThan(truncated.count, 20)
    }
}
