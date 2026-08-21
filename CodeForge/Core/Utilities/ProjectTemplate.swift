import Foundation

struct ProjectTemplate {
    static func createProjectFiles(
        in directory: URL,
        projectName: String,
        type: ProjectType,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        try fileService.createDirectory(at: directory)

        switch type {
        case .swiftiOS:
            try createSwiftiOSProject(in: directory, name: projectName, fileService: fileService)
        case .swiftPackage:
            try createSwiftPackageProject(in: directory, name: projectName, fileService: fileService)
        case .python:
            try createPythonProject(in: directory, name: projectName, fileService: fileService)
        case .javascript:
            try createJavaScriptProject(in: directory, name: projectName, fileService: fileService)
        case .typescript:
            try createTypeScriptProject(in: directory, name: projectName, fileService: fileService)
        case .web:
            try createWebProject(in: directory, name: projectName, fileService: fileService)
        case .empty:
            break
        }
    }

    private static func createSwiftiOSProject(
        in directory: URL,
        name: String,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        let sources = directory.appendingPathComponent("Sources")
        try fileService.createDirectory(at: sources)

        let mainFile = sources.appendingPathComponent("\(name.replacingOccurrences(of: " ", with: "")).swift")
        let content = """
        import SwiftUI

        @main
        struct \(name.replacingOccurrences(of: " ", with: ""))App: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        """
        try fileService.createFile(at: mainFile, contents: content.data(using: .utf8))

        let contentView = sources.appendingPathComponent("ContentView.swift")
        let contentBody = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                VStack {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("Hello, world!")
                }
                .padding()
            }
        }
        """
        try fileService.createFile(at: contentView, contents: contentBody.data(using: .utf8))
    }

    private static func createSwiftPackageProject(
        in directory: URL,
        name: String,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        let safeName = name.replacingOccurrences(of: " ", with: "")
        let sources = directory.appendingPathComponent("Sources").appendingPathComponent(safeName)
        try fileService.createDirectory(at: sources)

        let mainFile = sources.appendingPathComponent("\(safeName).swift")
        let content = """
        public struct \(safeName) {
            public private(set) var text = "Hello, World!"

            public init() {
            }
        }
        """
        try fileService.createFile(at: mainFile, contents: content.data(using: .utf8))

        let tests = directory.appendingPathComponent("Tests").appendingPathComponent("\(safeName)Tests")
        try fileService.createDirectory(at: tests)

        let testFile = tests.appendingPathComponent("\(safeName)Tests.swift")
        let testContent = """
        import XCTest
        @testable import \(safeName)

        final class \(safeName)Tests: XCTestCase {
            func testExample() throws {
                let sut = \(safeName)()
                XCTAssertEqual(sut.text, "Hello, World!")
            }
        }
        """
        try fileService.createFile(at: testFile, contents: testContent.data(using: .utf8))

        let packageFile = directory.appendingPathComponent("Package.swift")
        let packageContent = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "\(safeName)",
            products: [
                .library(name: "\(safeName)", targets: ["\(safeName)"]),
            ],
            targets: [
                .target(name: "\(safeName)"),
                .testTarget(name: "\(safeName)Tests", dependencies: ["\(safeName)"]),
            ]
        )
        """
        try fileService.createFile(at: packageFile, contents: packageContent.data(using: .utf8))
    }

    private static func createPythonProject(
        in directory: URL,
        name: String,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        let mainFile = directory.appendingPathComponent("main.py")
        let content = """
        #!/usr/bin/env python3
        \"\"\"
        \(name)
        \"\"\"

        def main():
            print("Hello from \(name)!")

        if __name__ == "__main__":
            main()
        """
        try fileService.createFile(at: mainFile, contents: content.data(using: .utf8))

        let gitignore = directory.appendingPathComponent(".gitignore")
        let giContent = """
        __pycache__/
        *.py[cod]
        *$py.class
        .env
        venv/
        """
        try fileService.createFile(at: gitignore, contents: giContent.data(using: .utf8))
    }

    private static func createJavaScriptProject(
        in directory: URL,
        name: String,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        let mainFile = directory.appendingPathComponent("index.js")
        let content = """
        /**
         * \(name)
         */

        function main() {
            console.log("Hello from \(name)!");
        }

        main();
        """
        try fileService.createFile(at: mainFile, contents: content.data(using: .utf8))

        let gitignore = directory.appendingPathComponent(".gitignore")
        let giContent = """
        node_modules/
        .env
        dist/
        """
        try fileService.createFile(at: gitignore, contents: giContent.data(using: .utf8))
    }

    private static func createTypeScriptProject(
        in directory: URL,
        name: String,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        let mainFile = directory.appendingPathComponent("index.ts")
        let content = """
        /**
         * \(name)
         */

        function main(): void {
            console.log("Hello from \(name)!");
        }

        main();
        """
        try fileService.createFile(at: mainFile, contents: content.data(using: .utf8))

        let tsconfig = directory.appendingPathComponent("tsconfig.json")
        let config = """
        {
            "compilerOptions": {
                "target": "ES2020",
                "module": "commonjs",
                "strict": true,
                "esModuleInterop": true,
                "outDir": "./dist"
            },
            "include": ["*.ts"]
        }
        """
        try fileService.createFile(at: tsconfig, contents: config.data(using: .utf8))

        let gitignore = directory.appendingPathComponent(".gitignore")
        let giContent = """
        node_modules/
        .env
        dist/
        """
        try fileService.createFile(at: gitignore, contents: giContent.data(using: .utf8))
    }

    private static func createWebProject(
        in directory: URL,
        name: String,
        fileService: WorkspaceFileServiceProtocol
    ) throws {
        let indexFile = directory.appendingPathComponent("index.html")
        let content = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(name)</title>
            <style>
                body { font-family: -apple-system, sans-serif; margin: 40px; }
            </style>
        </head>
        <body>
            <h1>\(name)</h1>
            <p>Edit this file to start building.</p>
        </body>
        </html>
        """
        try fileService.createFile(at: indexFile, contents: content.data(using: .utf8))
    }
}
