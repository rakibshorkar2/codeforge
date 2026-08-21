import XCTest
@testable import CodeForge

final class ProjectManagerTests: XCTestCase {
    private var tempDir: URL!
    private var fileService: WorkspaceFileService!
    private var manager: ProjectManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileService = WorkspaceFileService(workspaceRoot: tempDir)
        manager = ProjectManager(fileService: fileService)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateProject() async throws {
        let project = try await manager.createProject(name: "TestApp", type: .swiftiOS)
        XCTAssertEqual(project.name, "TestApp")
        XCTAssertEqual(project.type, .swiftiOS)
        XCTAssertEqual(manager.projects.count, 1)
    }

    func testCreateProjectDirectoryExists() async throws {
        let project = try await manager.createProject(name: "TestApp", type: .python)
        let dir = manager.projectDirectory(for: project)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    func testCreateProjectFilesCreated() async throws {
        let project = try await manager.createProject(name: "MyApp", type: .python)
        let dir = manager.projectDirectory(for: project)
        let mainPy = dir.appendingPathComponent("main.py")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainPy.path))
    }

    func testCreateProjectEmptyName() async {
        do {
            _ = try await manager.createProject(name: "", type: .empty)
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testCreateDuplicateProject() async throws {
        _ = try await manager.createProject(name: "Test", type: .empty)
        do {
            _ = try await manager.createProject(name: "Test", type: .empty)
            XCTFail("Should throw error for duplicate name")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testDeleteProject() async throws {
        let project = try await manager.createProject(name: "ToDelete", type: .empty)
        try await manager.deleteProject(id: project.id)
        XCTAssertTrue(manager.projects.isEmpty)
    }

    func testDeleteProjectDirectoryRemoved() async throws {
        let project = try await manager.createProject(name: "ToDelete", type: .empty)
        let dir = manager.projectDirectory(for: project)
        try await manager.deleteProject(id: project.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }

    func testDeleteNonexistentProject() async {
        do {
            try await manager.deleteProject(id: UUID())
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testRenameProject() async throws {
        let project = try await manager.createProject(name: "OldName", type: .empty)
        try await manager.renameProject(id: project.id, newName: "NewName")
        XCTAssertEqual(manager.projects.first?.name, "NewName")
    }

    func testRenameProjectDirectoryMoved() async throws {
        let project = try await manager.createProject(name: "OldName", type: .empty)
        let oldDir = manager.projectDirectory(for: project)
        try await manager.renameProject(id: project.id, newName: "NewName")
        let newProject = manager.projects.first!
        let newDir = manager.projectDirectory(for: newProject)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDir.path))
    }

    func testRenameEmptyName() async throws {
        let project = try await manager.createProject(name: "Test", type: .empty)
        do {
            try await manager.renameProject(id: project.id, newName: "")
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testDuplicateProject() async throws {
        let original = try await manager.createProject(name: "Original", type: .swiftiOS)
        let duplicate = try await manager.duplicateProject(id: original.id, newName: "Original Copy")
        XCTAssertEqual(manager.projects.count, 2)
        XCTAssertEqual(duplicate.name, "Original Copy")
        XCTAssertEqual(duplicate.type, original.type)
    }

    func testDuplicateProjectFilesCopied() async throws {
        let original = try await manager.createProject(name: "Original", type: .python)
        _ = try await manager.duplicateProject(id: original.id, newName: "Original Copy")
        let copyProject = manager.projects.first { $0.name == "Original Copy" }!
        let copyDir = manager.projectDirectory(for: copyProject)
        let mainPy = copyDir.appendingPathComponent("main.py")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainPy.path))
    }

    func testProjectExists() async throws {
        _ = try await manager.createProject(name: "Existing", type: .empty)
        XCTAssertTrue(manager.projectExists(name: "Existing"))
        XCTAssertFalse(manager.projectExists(name: "Nonexistent"))
    }

    func testLoadProjects() async throws {
        _ = try await manager.createProject(name: "Test1", type: .empty)
        _ = try await manager.createProject(name: "Test2", type: .empty)
        let newManager = ProjectManager(fileService: fileService)
        await newManager.loadProjects()
        XCTAssertEqual(newManager.projects.count, 2)
    }

    func testProjectDirectory() async throws {
        let project = try await manager.createProject(name: "Test", type: .empty)
        let dir = manager.projectDirectory(for: project)
        XCTAssertTrue(dir.path.contains("Projects"))
        XCTAssertTrue(dir.path.contains("Test"))
    }
}
