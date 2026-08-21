import XCTest
@testable import CodeForge

final class ModelTests: XCTestCase {
    func testTabProperties() {
        XCTAssertEqual(Tab.projects.title, "Projects")
        XCTAssertEqual(Tab.agent.title, "Agent")
        XCTAssertEqual(Tab.files.title, "Files")
        XCTAssertEqual(Tab.builds.title, "Builds")
        XCTAssertEqual(Tab.settings.title, "Settings")
    }

    func testTabSystemImages() {
        XCTAssertEqual(Tab.projects.systemImage, "folder")
        XCTAssertEqual(Tab.agent.systemImage, "brain.head.profile")
        XCTAssertEqual(Tab.files.systemImage, "doc.text")
        XCTAssertEqual(Tab.builds.systemImage, "hammer")
        XCTAssertEqual(Tab.settings.systemImage, "gearshape")
    }

    func testTabEquality() {
        XCTAssertEqual(Tab.projects, Tab.projects)
        XCTAssertNotEqual(Tab.projects, Tab.agent)
    }

    func testProjectInitialization() {
        let project = Project(name: "Test", path: "/test")
        XCTAssertEqual(project.name, "Test")
        XCTAssertEqual(project.path, "/test")
        XCTAssertNotNil(project.id)
    }

    func testProjectEquality() {
        let project1 = Project(name: "A", path: "/a")
        let project2 = Project(name: "A", path: "/a")
        XCTAssertNotEqual(project1, project2)
    }
}
