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
        let project = Project(name: "Test", type: .swiftiOS)
        XCTAssertEqual(project.name, "Test")
        XCTAssertEqual(project.type, .swiftiOS)
        XCTAssertNotNil(project.id)
    }

    func testProjectEquality() {
        let project1 = Project(name: "A", type: .empty)
        let project2 = Project(name: "A", type: .empty)
        XCTAssertNotEqual(project1, project2)
    }

    func testProjectDirectoryName() {
        let project = Project(name: "My Cool Project", type: .empty)
        XCTAssertEqual(project.directoryName, "My_Cool_Project")
    }

    func testProjectTypeDisplayNames() {
        XCTAssertEqual(ProjectType.swiftiOS.displayName, "Swift iOS")
        XCTAssertEqual(ProjectType.swiftPackage.displayName, "Swift Package")
        XCTAssertEqual(ProjectType.python.displayName, "Python")
        XCTAssertEqual(ProjectType.javascript.displayName, "JavaScript")
        XCTAssertEqual(ProjectType.typescript.displayName, "TypeScript")
        XCTAssertEqual(ProjectType.web.displayName, "Web")
        XCTAssertEqual(ProjectType.empty.displayName, "Empty Project")
    }

    func testProjectTypeLanguages() {
        XCTAssertEqual(ProjectType.swiftiOS.language, "Swift")
        XCTAssertEqual(ProjectType.swiftPackage.language, "Swift")
        XCTAssertEqual(ProjectType.python.language, "Python")
        XCTAssertEqual(ProjectType.javascript.language, "JavaScript")
        XCTAssertEqual(ProjectType.typescript.language, "TypeScript")
        XCTAssertEqual(ProjectType.web.language, "HTML/CSS")
        XCTAssertEqual(ProjectType.empty.language, "None")
    }

    func testProjectTypeIcons() {
        XCTAssertEqual(ProjectType.swiftiOS.icon, "iphone")
        XCTAssertEqual(ProjectType.swiftPackage.icon, "package")
        XCTAssertEqual(ProjectType.python.icon, "doc.text")
        XCTAssertEqual(ProjectType.web.icon, "globe")
        XCTAssertEqual(ProjectType.empty.icon, "folder")
    }

    func testProjectTypeFileExtensions() {
        XCTAssertEqual(ProjectType.swiftiOS.fileExtension, "swift")
        XCTAssertEqual(ProjectType.python.fileExtension, "py")
        XCTAssertEqual(ProjectType.javascript.fileExtension, "js")
        XCTAssertEqual(ProjectType.typescript.fileExtension, "ts")
        XCTAssertEqual(ProjectType.web.fileExtension, "html")
        XCTAssertEqual(ProjectType.empty.fileExtension, "")
    }
}
