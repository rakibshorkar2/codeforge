import XCTest
@testable import CodeForge

final class WorkspaceFileServiceTests: XCTestCase {
    private var tempDir: URL!
    private var service: WorkspaceFileService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        service = WorkspaceFileService(workspaceRoot: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateDirectory() throws {
        let dir = tempDir.appendingPathComponent("newdir")
        try service.createDirectory(at: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    func testCreateDirectoryRecursive() throws {
        let dir = tempDir.appendingPathComponent("a/b/c")
        try service.createDirectory(at: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    func testCreateFile() throws {
        let file = tempDir.appendingPathComponent("test.txt")
        try service.createFile(at: file, contents: "hello".data(using: .utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testCreateFileWithIntermediateDirs() throws {
        let file = tempDir.appendingPathComponent("a/b/c/test.txt")
        try service.createFile(at: file, contents: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testReadFile() throws {
        let file = tempDir.appendingPathComponent("test.txt")
        let data = "hello world".data(using: .utf8)!
        try service.createFile(at: file, contents: data)
        let read = try service.readFile(at: file)
        XCTAssertEqual(read, data)
    }

    func testReadNonexistentFile() {
        let file = tempDir.appendingPathComponent("missing.txt")
        XCTAssertThrowsError(try service.readFile(at: file))
    }

    func testWriteFile() throws {
        let file = tempDir.appendingPathComponent("test.txt")
        let data = "new content".data(using: .utf8)!
        try service.writeFile(at: file, data: data)
        let read = try service.readFile(at: file)
        XCTAssertEqual(read, data)
    }

    func testOverwriteFile() throws {
        let file = tempDir.appendingPathComponent("test.txt")
        try service.createFile(at: file, contents: "first".data(using: .utf8))
        try service.writeFile(at: file, data: "second".data(using: .utf8))
        let read = try service.readFile(at: file)
        XCTAssertEqual(String(data: read, encoding: .utf8), "second")
    }

    func testDeleteItem() throws {
        let file = tempDir.appendingPathComponent("delete_me.txt")
        try service.createFile(at: file, contents: nil)
        try service.deleteItem(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeleteDirectory() throws {
        let dir = tempDir.appendingPathComponent("delete_dir")
        try service.createDirectory(at: dir)
        try service.createFile(at: dir.appendingPathComponent("file.txt"), contents: nil)
        try service.deleteItem(at: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }

    func testDeleteNonexistent() {
        XCTAssertThrowsError(try service.deleteItem(at: tempDir.appendingPathComponent("missing")))
    }

    func testMoveItem() throws {
        let src = tempDir.appendingPathComponent("source.txt")
        let dst = tempDir.appendingPathComponent("dest.txt")
        try service.createFile(at: src, contents: "data".data(using: .utf8))
        try service.moveItem(from: src, to: dst)
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
    }

    func testCopyItem() throws {
        let src = tempDir.appendingPathComponent("source.txt")
        let dst = tempDir.appendingPathComponent("copy.txt")
        try service.createFile(at: src, contents: "data".data(using: .utf8))
        try service.copyItem(from: src, to: dst)
        XCTAssertTrue(FileManager.default.fileExists(atPath: src.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
        let read = try service.readFile(at: dst)
        XCTAssertEqual(String(data: read, encoding: .utf8), "data")
    }

    func testRenameItem() throws {
        let file = tempDir.appendingPathComponent("old.txt")
        try service.createFile(at: file, contents: nil)
        let newURL = try service.renameItem(at: file, to: "new.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func testListDirectory() throws {
        try service.createFile(at: tempDir.appendingPathComponent("a.txt"), contents: nil)
        try service.createFile(at: tempDir.appendingPathComponent("b.txt"), contents: nil)
        try service.createDirectory(at: tempDir.appendingPathComponent("subdir"))
        let items = try service.listDirectory(at: tempDir)
        XCTAssertEqual(items.count, 3)
    }

    func testListEmptyDirectory() throws {
        let items = try service.listDirectory(at: tempDir)
        XCTAssertTrue(items.isEmpty)
    }

    func testFileExists() throws {
        let file = tempDir.appendingPathComponent("exists.txt")
        XCTAssertFalse(service.fileExists(at: file))
        try service.createFile(at: file, contents: nil)
        XCTAssertTrue(service.fileExists(at: file))
    }

    func testIsDirectory() throws {
        let dir = tempDir.appendingPathComponent("mydir")
        let file = tempDir.appendingPathComponent("myfile.txt")
        try service.createDirectory(at: dir)
        try service.createFile(at: file, contents: nil)
        XCTAssertTrue(service.isDirectory(at: dir))
        XCTAssertFalse(service.isDirectory(at: file))
    }

    func testSanitizePathValid() throws {
        let result = try service.sanitizePath("subdir/file.txt", relativeTo: tempDir)
        XCTAssertTrue(result.path.hasPrefix(tempDir.path))
    }

    func testSanitizePathTraversalDetected() {
        XCTAssertThrowsError(
            try service.sanitizePath("../../etc/passwd", relativeTo: tempDir)
        ) { error in
            guard case WorkspaceFileError.pathTraversalDetected = error else {
                XCTFail("Expected pathTraversalDetected error")
                return
            }
        }
    }

    func testFileCount() throws {
        try service.createFile(at: tempDir.appendingPathComponent("a.txt"), contents: nil)
        try service.createFile(at: tempDir.appendingPathComponent("b.txt"), contents: nil)
        let count = try service.fileCount(in: tempDir)
        XCTAssertEqual(count, 2)
    }

    func testWorkspaceRootCreated() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.workspaceRoot.path))
    }
}
