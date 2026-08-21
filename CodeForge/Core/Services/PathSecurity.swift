import Foundation

enum PathSecurityError: Error, LocalizedError {
    case pathTraversalAttempt(String)
    case symlinkEscape(String)
    case outsideWorkspace(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .pathTraversalAttempt(let p): return "Path traversal attempt detected: \(p)"
        case .symlinkEscape(let p): return "Symlink escapes workspace: \(p)"
        case .outsideWorkspace(let p): return "Path is outside workspace: \(p)"
        case .invalidPath(let p): return "Invalid path: \(p)"
        }
    }
}

struct PathSecurity {
    static func validate(path: String, workspace: String) throws -> String {
        let normalized = normalize(path: path)

        guard !normalized.isEmpty else {
            throw PathSecurityError.invalidPath(path)
        }

        if normalized.contains("..") {
            throw PathSecurityError.pathTraversalAttempt(path)
        }

        let workspaceNorm = normalize(path: workspace)
        let fullPath: String
        if normalized.hasPrefix("/") {
            fullPath = normalized
        } else {
            fullPath = (workspaceNorm as NSString).appendingPathComponent(normalized)
        }

        let resolved = resolveSymlinks(path: fullPath)
        let resolvedWorkspace = resolveSymlinks(path: workspaceNorm)

        guard resolved.hasPrefix(resolvedWorkspace) || resolved == resolvedWorkspace else {
            throw PathSecurityError.outsideWorkspace(path)
        }

        return resolved
    }

    static func normalize(path: String) -> String {
        var result = path
        while result.contains("//") {
            result = result.replacingOccurrences(of: "//", with: "/")
        }
        let parts = result.split(separator: "/", omittingEmptySubsequences: true)
        var stack: [String] = []
        for part in parts {
            if part == "." { continue }
            if part == ".." {
                stack.removeLast()
            } else {
                stack.append(String(part))
        }
        }
        return "/" + stack.joined(separator: "/")
    }

    static func resolveSymlinks(path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.standardized.path
    }

    static func isInsideWorkspace(path: String, workspace: String) -> Bool {
        (try? validate(path: path, workspace: workspace)) != nil
    }
}
