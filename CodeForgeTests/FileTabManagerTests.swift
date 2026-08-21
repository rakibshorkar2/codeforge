import XCTest
@testable import CodeForge

@MainActor
final class FileTabManagerTests: XCTestCase {
    func testOpenFile() {
        let manager = FileTabManager()
        let url = URL(fileURLWithPath: "/test/file.swift")
        manager.openFile(at: url, content: "hello")
        XCTAssertEqual(manager.openTabs.count, 1)
        XCTAssertEqual(manager.activeTab?.filename, "file.swift")
        XCTAssertEqual(manager.activeTab?.content, "hello")
    }

    func testOpenSameFileFocuses() {
        let manager = FileTabManager()
        let url = URL(fileURLWithPath: "/test/file.swift")
        manager.openFile(at: url, content: "a")
        manager.openFile(at: url, content: "b")
        XCTAssertEqual(manager.openTabs.count, 1)
    }

    func testOpenMultipleFiles() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        manager.openFile(at: URL(fileURLWithPath: "/c.swift"), content: "c")
        XCTAssertEqual(manager.openTabs.count, 3)
        XCTAssertEqual(manager.activeTab?.filename, "c.swift")
    }

    func testCloseTab() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        let tabID = manager.openTabs[0].id
        manager.closeTab(id: tabID)
        XCTAssertTrue(manager.openTabs.isEmpty)
        XCTAssertNil(manager.activeTabID)
    }

    func testCloseActiveTabSwitchesToLast() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        let bID = manager.openTabs[1].id
        manager.closeTab(id: bID)
        XCTAssertEqual(manager.activeTab?.filename, "a.swift")
    }

    func testCloseAllTabs() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        manager.closeAllTabs()
        XCTAssertTrue(manager.openTabs.isEmpty)
        XCTAssertNil(manager.activeTabID)
    }

    func testSwitchTab() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        let aID = manager.openTabs[0].id
        manager.switchToTab(id: aID)
        XCTAssertEqual(manager.activeTab?.filename, "a.swift")
    }

    func testSwitchToNextTab() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        let aID = manager.openTabs[0].id
        manager.switchToTab(id: aID)
        manager.switchToNextTab()
        XCTAssertEqual(manager.activeTab?.filename, "b.swift")
    }

    func testSwitchToPreviousTab() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        manager.switchToPreviousTab()
        XCTAssertEqual(manager.activeTab?.filename, "a.swift")
    }

    func testUpdateContentMarksModified() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "original")
        let tabID = manager.openTabs[0].id
        manager.updateContent(forTabID: tabID, content: "modified")
        XCTAssertTrue(manager.activeTab?.isModified ?? false)
        XCTAssertTrue(manager.hasUnsavedChanges)
    }

    func testMarkSaved() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "original")
        let tabID = manager.openTabs[0].id
        manager.updateContent(forTabID: tabID, content: "modified")
        manager.markSaved(tabID: tabID)
        XCTAssertFalse(manager.activeTab?.isModified ?? true)
        XCTAssertFalse(manager.hasUnsavedChanges)
    }

    func testDiscardChanges() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "original")
        let tabID = manager.openTabs[0].id
        manager.updateContent(forTabID: tabID, content: "modified")
        manager.discardChanges(tabID: tabID)
        XCTAssertEqual(manager.activeTab?.content, "original")
        XCTAssertFalse(manager.activeTab?.isModified ?? true)
    }

    func testUnsavedTabCount() {
        let manager = FileTabManager()
        manager.openFile(at: URL(fileURLWithPath: "/a.swift"), content: "a")
        manager.openFile(at: URL(fileURLWithPath: "/b.swift"), content: "b")
        manager.openFile(at: URL(fileURLWithPath: "/c.swift"), content: "c")
        let tabID = manager.openTabs[0].id
        manager.updateContent(forTabID: tabID, content: "modified")
        XCTAssertEqual(manager.unsavedTabCount, 1)
    }

    func testEditorTabLanguage() {
        let swiftTab = EditorTab(fileURL: URL(fileURLWithPath: "/test.swift"), content: "")
        XCTAssertEqual(swiftTab.language, .swift)
        let pyTab = EditorTab(fileURL: URL(fileURLWithPath: "/test.py"), content: "")
        XCTAssertEqual(pyTab.language, .python)
    }

    func testEditorTabModified() {
        var tab = EditorTab(fileURL: URL(fileURLWithPath: "/test.swift"), content: "original")
        XCTAssertFalse(tab.isModified)
        tab.updateContent("modified")
        XCTAssertTrue(tab.isModified)
        tab.save()
        XCTAssertFalse(tab.isModified)
    }

    func testEditorTabDiscard() {
        var tab = EditorTab(fileURL: URL(fileURLWithPath: "/test.swift"), content: "original")
        tab.updateContent("modified")
        tab.discard()
        XCTAssertEqual(tab.content, "original")
        XCTAssertFalse(tab.isModified)
    }
}
