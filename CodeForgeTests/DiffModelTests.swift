import XCTest
@testable import CodeForge

final class DiffModelTests: XCTestCase {
    func testIdenticalText() {
        let diff = LineDiff.compute(old: "a\nb\nc", new: "a\nb\nc")
        XCTAssertEqual(diff.count, 3)
        XCTAssertTrue(diff.allSatisfy { $0.type == .unchanged })
    }

    func testAddedLines() {
        let diff = LineDiff.compute(old: "a\nc", new: "a\nb\nc")
        let added = diff.filter { $0.type == .added }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.content, "b")
    }

    func testRemovedLines() {
        let diff = LineDiff.compute(old: "a\nb\nc", new: "a\nc")
        let removed = diff.filter { $0.type == .removed }
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.content, "b")
    }

    func testMixedChanges() {
        let old = "line1\nline2\nline3"
        let new = "line1\nmodified\nline3\nline4"
        let diff = LineDiff.compute(old: old, new: new)
        let added = diff.filter { $0.type == .added }
        let removed = diff.filter { $0.type == .removed }
        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(removed.count, 1)
    }

    func testEmptyOld() {
        let diff = LineDiff.compute(old: "", new: "hello\nworld")
        let added = diff.filter { $0.type == .added }
        XCTAssertEqual(added.count, 2)
    }

    func testEmptyNew() {
        let diff = LineDiff.compute(old: "hello\nworld", new: "")
        let removed = diff.filter { $0.type == .removed }
        XCTAssertEqual(removed.count, 2)
    }

    func testBothEmpty() {
        let diff = LineDiff.compute(old: "", new: "")
        XCTAssertTrue(diff.isEmpty)
    }

    func testLineNumbering() {
        let diff = LineDiff.compute(old: "a", new: "a\nb")
        let lineNumbers = diff.map { $0.lineNumber }
        XCTAssertEqual(lineNumbers, [1, 2])
    }
}
