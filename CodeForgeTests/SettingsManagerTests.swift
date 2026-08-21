import XCTest
@testable import CodeForge

final class SettingsManagerTests: XCTestCase {
    func testDefaultAppearance() {
        let manager = SettingsManager()
        let appearance = manager.appearance
        XCTAssertTrue(AppearanceOption.allCases.contains(appearance))
    }

    func testDefaultFontSize() {
        let manager = SettingsManager()
        XCTAssertEqual(manager.fontSize, 16.0)
    }

    func testSetFontSize() {
        let manager = SettingsManager()
        manager.setFontSize(20.0)
        XCTAssertEqual(manager.fontSize, 20.0)
        manager.setFontSize(16.0)
    }

    func testAppearanceOptions() {
        XCTAssertEqual(AppearanceOption.allCases.count, 3)
        XCTAssertEqual(AppearanceOption.system.displayName, "System")
        XCTAssertEqual(AppearanceOption.light.displayName, "Light")
        XCTAssertEqual(AppearanceOption.dark.displayName, "Dark")
    }
}
