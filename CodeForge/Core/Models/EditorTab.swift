import Foundation
import SwiftUI

struct EditorTab: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    var content: String
    var originalContent: String
    var isModified: Bool

    init(fileURL: URL, content: String = "") {
        self.id = UUID()
        self.fileURL = fileURL
        self.content = content
        self.originalContent = content
        self.isModified = false
    }

    var filename: String {
        fileURL.lastPathComponent
    }

    var language: SyntaxLanguage {
        SyntaxLanguage.detect(from: filename)
    }

    static func == (lhs: EditorTab, rhs: EditorTab) -> Bool {
        lhs.id == rhs.id
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        isModified = content != originalContent
    }

    mutating func save() {
        originalContent = content
        isModified = false
    }

    mutating func discard() {
        content = originalContent
        isModified = false
    }
}

@MainActor
final class FileTabManager: ObservableObject {
    @Published private(set) var openTabs: [EditorTab] = []
    @Published private(set) var activeTabID: UUID?

    var activeTab: EditorTab? {
        guard let id = activeTabID else { return nil }
        return openTabs.first { $0.id == id }
    }

    var activeTabIndex: Int? {
        guard let id = activeTabID else { return nil }
        return openTabs.firstIndex { $0.id == id }
    }

    func openFile(at url: URL, content: String) {
        if let existingIndex = openTabs.firstIndex(where: { $0.fileURL == url }) {
            activeTabID = openTabs[existingIndex].id
            return
        }

        var tab = EditorTab(fileURL: url, content: content)
        tab.originalContent = content
        openTabs.append(tab)
        activeTabID = tab.id
    }

    func closeTab(id: UUID) {
        openTabs.removeAll { $0.id == id }
        if activeTabID == id {
            activeTabID = openTabs.last?.id
        }
    }

    func closeAllTabs() {
        openTabs.removeAll()
        activeTabID = nil
    }

    func closeOtherTabs(keeping tabID: UUID) {
        openTabs.removeAll { $0.id != tabID }
        activeTabID = tabID
    }

    func switchToTab(id: UUID) {
        guard openTabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    func switchToNextTab() {
        guard !openTabs.isEmpty else { return }
        guard let currentIndex = activeTabIndex else {
            activeTabID = openTabs.first?.id
            return
        }
        let nextIndex = (currentIndex + 1) % openTabs.count
        activeTabID = openTabs[nextIndex].id
    }

    func switchToPreviousTab() {
        guard !openTabs.isEmpty else { return }
        guard let currentIndex = activeTabIndex else {
            activeTabID = openTabs.last?.id
            return
        }
        let prevIndex = (currentIndex - 1 + openTabs.count) % openTabs.count
        activeTabID = openTabs[prevIndex].id
    }

    func updateContent(forTabID id: UUID, content: String) {
        guard let index = openTabs.firstIndex(where: { $0.id == id }) else { return }
        openTabs[index].updateContent(content)
    }

    func markSaved(tabID: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        openTabs[index].save()
    }

    func discardChanges(tabID: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        openTabs[index].discard()
    }

    var hasUnsavedChanges: Bool {
        openTabs.contains { $0.isModified }
    }

    var unsavedTabCount: Int {
        openTabs.filter { $0.isModified }.count
    }
}
