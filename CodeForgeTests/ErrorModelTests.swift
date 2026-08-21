import XCTest
@testable import CodeForge

final class ErrorModelTests: XCTestCase {
    func testNetworkErrors() {
        let errors: [AppError] = [
            .network(.noConnection),
            .network(.timeout),
            .network(.serverError(500)),
            .network(.invalidResponse)
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testAuthErrors() {
        let errors: [AppError] = [
            .authentication(.notAuthenticated),
            .authentication(.tokenExpired),
            .authentication(.invalidCredentials)
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
        }
    }

    func testFileErrors() {
        let errors: [AppError] = [
            .filesystem(.notFound("test.swift")),
            .filesystem(.permissionDenied),
            .filesystem(.readFailed),
            .filesystem(.writeFailed),
            .filesystem(.invalidPath),
            .filesystem(.custom("Custom error"))
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
        }
    }

    func testAIErrors() {
        let errors: [AppError] = [
            .ai(.apiKeyMissing),
            .ai(.rateLimited),
            .ai(.invalidRequest),
            .ai(.modelUnavailable)
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
        }
    }

    func testGitHubErrors() {
        let errors: [AppError] = [
            .github(.notAuthenticated),
            .github(.rateLimited),
            .github(.repositoryNotFound),
            .github(.permissionDenied)
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
        }
    }

    func testBuildErrors() {
        let errors: [AppError] = [
            .build(.compilationFailed("syntax error")),
            .build(.signingFailed),
            .build(.missingDependencies),
            .build(.unsupportedPlatform)
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
        }
    }

    func testUnknownError() {
        let error = AppError.unknown("Something went wrong")
        XCTAssertEqual(error.localizedDescription, "Something went wrong")
    }

    func testErrorIdentity() {
        let error1 = AppError.network(.noConnection)
        let error2 = AppError.network(.noConnection)
        XCTAssertEqual(error1.id, error2.id)
    }

    func testWorkspaceFileErrorDescriptions() {
        let errors: [WorkspaceFileError] = [
            .directoryCreationFailed("/path"),
            .fileCreationFailed("/path"),
            .readFailed("/path"),
            .writeFailed("/path"),
            .deleteFailed("/path"),
            .moveFailed("/path"),
            .copyFailed("/path"),
            .renameFailed("/path"),
            .pathTraversalDetected,
            .itemNotFound("/path"),
            .notADirectory("/path"),
            .notAFile("/path"),
            .zipExtractionFailed("reason"),
            .zipCreationFailed("reason")
        ]
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
