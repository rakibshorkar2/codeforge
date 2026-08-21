import XCTest
@testable import CodeForge

final class SyntaxHighlighterTests: XCTestCase {
    func testSwiftDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.swift"), .swift)
        XCTAssertEqual(SyntaxLanguage.detect(from: "ContentView.swift"), .swift)
    }

    func testPythonDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.py"), .python)
        XCTAssertEqual(SyntaxLanguage.detect(from: "script.pyw"), .python)
    }

    func testJavaScriptDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "index.js"), .javascript)
        XCTAssertEqual(SyntaxLanguage.detect(from: "App.jsx"), .javascript)
        XCTAssertEqual(SyntaxLanguage.detect(from: "module.mjs"), .javascript)
    }

    func testTypeScriptDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "app.ts"), .typescript)
        XCTAssertEqual(SyntaxLanguage.detect(from: "App.tsx"), .typescript)
    }

    func testJSONDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "data.json"), .json)
        XCTAssertEqual(SyntaxLanguage.detect(from: "package.json"), .json)
    }

    func testYAMLDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "config.yaml"), .yaml)
        XCTAssertEqual(SyntaxLanguage.detect(from: "config.yml"), .yaml)
    }

    func testMarkdownDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "README.md"), .markdown)
    }

    func testHTMLDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "index.html"), .html)
        XCTAssertEqual(SyntaxLanguage.detect(from: "page.htm"), .html)
    }

    func testCSSDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "style.css"), .css)
        XCTAssertEqual(SyntaxLanguage.detect(from: "style.scss"), .css)
    }

    func testCDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.c"), .c)
        XCTAssertEqual(SyntaxLanguage.detect(from: "header.h"), .c)
    }

    func testCppDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.cpp"), .cpp)
        XCTAssertEqual(SyntaxLanguage.detect(from: "app.cc"), .cpp)
    }

    func testRustDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.rs"), .rust)
    }

    func testGoDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.go"), .go)
    }

    func testShellDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "script.sh"), .shell)
        XCTAssertEqual(SyntaxLanguage.detect(from: "script.bash"), .shell)
    }

    func testDartDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "main.dart"), .dart)
    }

    func testJavaDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "Main.java"), .java)
    }

    func testKotlinDetection() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "Main.kt"), .kotlin)
        XCTAssertEqual(SyntaxLanguage.detect(from: "script.kts"), .kotlin)
    }

    func testUnknownDefaultsToPlain() {
        XCTAssertEqual(SyntaxLanguage.detect(from: "file.xyz"), .plain)
        XCTAssertEqual(SyntaxLanguage.detect(from: "noextension"), .plain)
    }

    func testSwiftSyntaxHighlighting() {
        let highlighter = SyntaxHighlighter(language: .swift)
        let tokens = highlighter.highlightLine("func hello() { return true }")
        XCTAssertFalse(tokens.isEmpty)
        let hasKeyword = tokens.contains { if case .keyword(let k) = $0 { return k == "func" }; return false }
        XCTAssertTrue(hasKeyword)
    }

    func testPythonSyntaxHighlighting() {
        let highlighter = SyntaxHighlighter(language: .python)
        let tokens = highlighter.highlightLine("def main():")
        XCTAssertFalse(tokens.isEmpty)
        let hasKeyword = tokens.contains { if case .keyword(let k) = $0 { return k == "def" }; return false }
        XCTAssertTrue(hasKeyword)
    }

    func testJavaScriptSyntaxHighlighting() {
        let highlighter = SyntaxHighlighter(language: .javascript)
        let tokens = highlighter.highlightLine("const x = 42;")
        XCTAssertFalse(tokens.isEmpty)
    }

    func testJSONSyntaxHighlighting() {
        let highlighter = SyntaxHighlighter(language: .json)
        let tokens = highlighter.highlightLine(#""key": "value""#)
        XCTAssertFalse(tokens.isEmpty)
    }

    func testHTMLSyntaxHighlighting() {
        let highlighter = SyntaxHighlighter(language: .html)
        let tokens = highlighter.highlightLine("<div class=\"container\">")
        XCTAssertFalse(tokens.isEmpty)
    }

    func testEmptyLine() {
        let highlighter = SyntaxHighlighter(language: .swift)
        let tokens = highlighter.highlightLine("")
        XCTAssertFalse(tokens.isEmpty)
    }

    func testCommentHighlighting() {
        let highlighter = SyntaxHighlighter(language: .swift)
        let tokens = highlighter.highlightLine("// this is a comment")
        let hasComment = tokens.contains { if case .comment = $0 { return true }; return false }
        XCTAssertTrue(hasComment)
    }

    func testStringHighlighting() {
        let highlighter = SyntaxHighlighter(language: .swift)
        let tokens = highlighter.highlightLine(#"let s = "hello""#)
        let hasString = tokens.contains { if case .string = $0 { return true }; return false }
        XCTAssertTrue(hasString)
    }

    func testNumberHighlighting() {
        let highlighter = SyntaxHighlighter(language: .swift)
        let tokens = highlighter.highlightLine("let x = 42")
        let hasNumber = tokens.contains { if case .number = $0 { return true }; return false }
        XCTAssertTrue(hasNumber)
    }

    func testPlainLanguageNoRules() {
        let highlighter = SyntaxHighlighter(language: .plain)
        let tokens = highlighter.highlightLine("hello world 123")
        XCTAssertTrue(tokens.allSatisfy {
            if case .plain = $0 { return true }
            return false
        })
    }
}
