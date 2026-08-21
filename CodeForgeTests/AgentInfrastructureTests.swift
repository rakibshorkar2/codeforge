import XCTest
@testable import CodeForge

final class PathSecurityTests: XCTestCase {
    func testNormalizeSimplePath() {
        let result = PathSecurity.normalize(path: "src/main.swift")
        XCTAssertEqual(result, "/src/main.swift")
    }

    func testNormalizeDoubleSlashes() {
        let result = PathSecurity.normalize(path: "src//main.swift")
        XCTAssertEqual(result, "/src/main.swift")
    }

    func testNormalizeDot() {
        let result = PathSecurity.normalize(path: "./src/main.swift")
        XCTAssertEqual(result, "/src/main.swift")
    }

    func testNormalizeDotDot() {
        let result = PathSecurity.normalize(path: "src/../main.swift")
        XCTAssertEqual(result, "/main.swift")
    }

    func testRejectPathTraversal() {
        XCTAssertThrowsError(try PathSecurity.validate(path: "../secret.txt", workspace: NSTemporaryDirectory()))
    }

    func testRejectAbsoluteOutsideWorkspace() {
        let tmp = NSTemporaryDirectory()
        let ws = (tmp as NSString).appendingPathComponent("ws_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: ws, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: ws) }
        XCTAssertThrowsError(try PathSecurity.validate(path: "/etc/passwd", workspace: ws))
    }

    func testRejectEmptyPath() {
        XCTAssertThrowsError(try PathSecurity.validate(path: "", workspace: NSTemporaryDirectory()))
    }

    func testValidRelativePath() {
        let tmp = NSTemporaryDirectory()
        let ws = (tmp as NSString).appendingPathComponent("ws_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: ws, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: ws) }
        XCTAssertNoThrow(try PathSecurity.validate(path: "src/main.swift", workspace: ws))
    }

    func testIsInsideWorkspace() {
        let tmp = NSTemporaryDirectory()
        let ws = (tmp as NSString).appendingPathComponent("ws_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: ws, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: ws) }
        XCTAssertTrue(PathSecurity.isInsideWorkspace(path: "src/main.swift", workspace: ws))
        XCTAssertFalse(PathSecurity.isInsideWorkspace(path: "/etc/passwd", workspace: ws))
    }
}

final class AgentPermissionManagerTests: XCTestCase {
    func testDefaultPolicies() {
        let m = AgentPermissionManager()
        XCTAssertEqual(m.policy(for: .read), .allowAutomatically)
        XCTAssertEqual(m.policy(for: .write), .askDestructive)
        XCTAssertEqual(m.policy(for: .delete), .askDestructive)
    }

    func testSetPolicy() {
        let m = AgentPermissionManager()
        m.setPolicy(.allowAutomatically, for: .write)
        XCTAssertEqual(m.policy(for: .write), .allowAutomatically)
    }

    func testReadAllowedByDefault() {
        let m = AgentPermissionManager()
        XCTAssertTrue(m.requestPermission(level: .read, resource: "test.swift"))
    }

    func testWriteBlockedByDefault() {
        let m = AgentPermissionManager()
        XCTAssertFalse(m.requestPermission(level: .write, resource: "test.swift"))
    }

    func testDeleteBlockedByDefault() {
        let m = AgentPermissionManager()
        XCTAssertFalse(m.requestPermission(level: .delete, resource: "test.swift"))
    }

    func testAllowedLevels() {
        let m = AgentPermissionManager()
        let allowed = m.allowedLevels()
        XCTAssertTrue(allowed.contains(.read))
        XCTAssertFalse(allowed.contains(.write))
    }
}

final class AgentAuditLogTests: XCTestCase {
    func testRecord() {
        let log = AgentAuditLog()
        log.record(toolName: "read_file", filePath: "test.swift", success: true)
        XCTAssertEqual(log.entries().count, 1)
        XCTAssertEqual(log.entries().first?.toolName, "read_file")
    }

    func testRecordFailure() {
        let log = AgentAuditLog()
        log.record(toolName: "write_file", filePath: "test.swift", success: false, errorMessage: "err")
        XCTAssertEqual(log.failedEntries().count, 1)
    }

    func testClear() {
        let log = AgentAuditLog()
        log.record(toolName: "a", filePath: "a", success: true)
        log.clear()
        XCTAssertTrue(log.entries().isEmpty)
    }

    func testMaxEntries() {
        let log = AgentAuditLog(maxEntries: 3)
        for i in 0..<5 {
            log.record(toolName: "tool\(i)", filePath: "f\(i)", success: true)
        }
        XCTAssertEqual(log.entries().count, 3)
    }

    func testFilterByTool() {
        let log = AgentAuditLog()
        log.record(toolName: "read", filePath: "a", success: true)
        log.record(toolName: "write", filePath: "b", success: true)
        log.record(toolName: "read", filePath: "c", success: true)
        XCTAssertEqual(log.entries(for: "read").count, 2)
    }
}
