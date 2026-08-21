import XCTest
@testable import CodeForge

@MainActor
final class AppEnvironmentTests: XCTestCase {
    func testInitialization() {
        let environment = AppEnvironment()
        XCTAssertEqual(environment.selectedTab, .projects)
        XCTAssertFalse(environment.isLoading)
    }

    func testDefaultManagersAreInitialized() {
        let environment = AppEnvironment()
        XCTAssertNotNil(environment.projectManager)
        XCTAssertNotNil(environment.settingsManager)
    }

    func testTabSelection() {
        let environment = AppEnvironment()
        environment.selectedTab = .agent
        XCTAssertEqual(environment.selectedTab, .agent)
        environment.selectedTab = .settings
        XCTAssertEqual(environment.selectedTab, .settings)
    }
}
