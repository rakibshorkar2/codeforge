import Foundation

enum AppError: Error, Identifiable, Equatable {
    case network(NetworkError)
    case authentication(AuthError)
    case filesystem(FileError)
    case ai(AIError)
    case github(GitHubError)
    case build(BuildError)
    case unknown(String)

    var id: String { localizedDescription }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

enum NetworkError: Error, Equatable {
    case noConnection
    case timeout
    case serverError(Int)
    case invalidResponse
}

enum AuthError: Error, Equatable {
    case notAuthenticated
    case tokenExpired
    case invalidCredentials
}

enum FileError: Error, Equatable {
    case notFound(String)
    case permissionDenied
    case readFailed
    case writeFailed
    case invalidPath
}

enum AIError: Error, Equatable {
    case apiKeyMissing
    case rateLimited
    case invalidRequest
    case modelUnavailable
}

enum GitHubError: Error, Equatable {
    case notAuthenticated
    case rateLimited
    case repositoryNotFound
    case permissionDenied
}

enum BuildError: Error, Equatable {
    case compilationFailed(String)
    case signingFailed
    case missingDependencies
    case unsupportedPlatform
}

extension AppError {
    var localizedDescription: String {
        switch self {
        case .network(let error):
            switch error {
            case .noConnection: return "No internet connection"
            case .timeout: return "Request timed out"
            case .serverError(let code): return "Server error (\(code))"
            case .invalidResponse: return "Invalid server response"
            }
        case .authentication(let error):
            switch error {
            case .notAuthenticated: return "Not authenticated"
            case .tokenExpired: return "Authentication token expired"
            case .invalidCredentials: return "Invalid credentials"
            }
        case .filesystem(let error):
            switch error {
            case .notFound(let path): return "File not found: \(path)"
            case .permissionDenied: return "Permission denied"
            case .readFailed: return "Failed to read file"
            case .writeFailed: return "Failed to write file"
            case .invalidPath: return "Invalid file path"
            }
        case .ai(let error):
            switch error {
            case .apiKeyMissing: return "AI API key not configured"
            case .rateLimited: return "AI request rate limited"
            case .invalidRequest: return "Invalid AI request"
            case .modelUnavailable: return "AI model unavailable"
            }
        case .github(let error):
            switch error {
            case .notAuthenticated: return "GitHub not authenticated"
            case .rateLimited: return "GitHub API rate limited"
            case .repositoryNotFound: return "Repository not found"
            case .permissionDenied: return "GitHub permission denied"
            }
        case .build(let error):
            switch error {
            case .compilationFailed(let msg): return "Compilation failed: \(msg)"
            case .signingFailed: return "Code signing failed"
            case .missingDependencies: return "Missing dependencies"
            case .unsupportedPlatform: return "Unsupported platform"
            }
        case .unknown(let message): return message
        }
    }
}
