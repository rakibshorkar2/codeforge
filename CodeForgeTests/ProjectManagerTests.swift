import XCTest
@testable import CodeForge

final class ProjectManagerTests: XCTestCase {
    func testAddProject() {
        let manager = ProjectManager()
        let project = manager.addProject(name: "Test", path: "/test")
        XCTAssertEqual(manager.projects.count, 1)
        XCTAssertEqual(manager.projects.first?.name, "Test")
        XCTAssertEqual(project.name, "Test")
    }

    func testRemoveProject() {
        let manager = ProjectManager()
        let project = manager.addProject(name: "Test", path: "/test")
        manager.removeProject(id: project.id)
        XCTAssertTrue(manager.projects.isEmpty)
    }

    func testEmptyProjects() {
        let manager = ProjectManager()
        XCTAssertTrue(manager.projects.isEmpty)
    }
}
