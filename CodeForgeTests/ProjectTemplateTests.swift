import XCTest
@testable import CodeForge

final class ProjectTemplateTests: XCTestCase {
    private var tempDir: URL!
    private var fileService: WorkspaceFileService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fileService = WorkspaceFileService(workspaceRoot: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateSwiftiOSProject() throws {
        let dir = tempDir.appendingPathComponent("TestApp")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "TestApp", type: .swiftiOS, fileService: fileService)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources/TestApp.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources/ContentView.swift").path))
    }

    func testCreateSwiftPackageProject() throws {
        let dir = tempDir.appendingPathComponent("MyPackage")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "MyPackage", type: .swiftPackage, fileService: fileService)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources/MyPackage/MyPackage.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Tests/MyPackageTests/MyPackageTests.swift").path))
    }

    func testCreatePythonProject() throws {
        let dir = tempDir.appendingPathComponent("PyApp")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "PyApp", type: .python, fileService: fileService)
        let mainPy = dir.appendingPathComponent("main.py")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainPy.path))
        let content = String(data: try Data(contentsOf: mainPy), encoding: .utf8) ?? ""
        XCTAssertTrue(content.contains("def main():"))
    }

    func testCreateJavaScriptProject() throws {
        let dir = tempDir.appendingPathComponent("JSApp")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "JSApp", type: .javascript, fileService: fileService)
        let mainJS = dir.appendingPathComponent("index.js")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainJS.path))
    }

    func testCreateTypeScriptProject() throws {
        let dir = tempDir.appendingPathComponent("TSApp")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "TSApp", type: .typescript, fileService: fileService)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("index.ts").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("tsconfig.json").path))
    }

    func testCreateWebProject() throws {
        let dir = tempDir.appendingPathComponent("WebApp")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "WebApp", type: .web, fileService: fileService)
        let indexHTML = dir.appendingPathComponent("index.html")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexHTML.path))
        let content = String(data: try Data(contentsOf: indexHTML), encoding: .utf8) ?? ""
        XCTAssertTrue(content.contains("<!DOCTYPE html>"))
    }

    func testCreateEmptyProject() throws {
        let dir = tempDir.appendingPathComponent("Empty")
        try ProjectTemplate.createProjectFiles(in: dir, projectName: "Empty", type: .empty, fileService: fileService)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        XCTAssertTrue(contents.isEmpty)
    }
}
