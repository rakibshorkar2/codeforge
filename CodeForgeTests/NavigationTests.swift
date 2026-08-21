import XCTest
@testable import CodeForge

@MainActor
final class NavigationTests: XCTestCase {
    func testDefaultTabIsProjects() {
        let environment = AppEnvironment()
        XCTAssertEqual(environment.selectedTab, .projects)
    }

    func testAllTabsAreAccessible() {
        let environment = AppEnvironment()
        for tab in Tab.allCases {
            environment.selectedTab = tab
            XCTAssertEqual(environment.selectedTab, tab)
        }
    }

    func testTabCount() {
        XCTAssertEqual(Tab.allCases.count, 5)
    }
}
