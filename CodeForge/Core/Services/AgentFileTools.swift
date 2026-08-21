import Foundation

class BaseFileTool {
    let workspace: String
    let permissions: AgentPermissionManagerProtocol
    let auditLog: AgentAuditLogProtocol
    let fileManager: FileManager

    init(workspace: String, permissions: AgentPermissionManagerProtocol, auditLog: AgentAuditLogProtocol, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.permissions = permissions
        self.auditLog = auditLog
        self.fileManager = fileManager
    }

    func validatePath(_ path: String) throws -> String {
        try PathSecurity.validate(path: path, workspace: workspace)
    }

    func checkPermission(_ level: PermissionLevel, resource: String) throws {
        guard permissions.requestPermission(level: level, resource: resource) else {
            throw AgentError(message: "Permission denied for \(level.displayName) on \(resource)", code: .permissionDenied)
        }
    }

    func log(toolName: String, path: String, success: Bool, error: String? = nil) {
        auditLog.record(toolName: toolName, filePath: path, success: success, errorMessage: error)
    }
}

final class ReadFileTool: BaseFileTool, AgentTool {
    let name = "read_file"
    let description = "Read the contents of a file. Returns the file content as text."
    let requiredPermission = PermissionLevel.read

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to the file within the project", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String else {
            throw AgentError(message: "Missing required parameter: path", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.read, resource: path)

        guard fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "File not found")
            throw AgentError(message: "File not found: \(path)", code: .toolExecutionFailed)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: resolved))
        guard let content = String(data: data, encoding: .utf8) else {
            log(toolName: name, path: path, success: false, error: "Cannot read file")
            throw AgentError(message: "Cannot read file as text: \(path)", code: .toolExecutionFailed)
        }

        log(toolName: name, path: path, success: true)
        return content
    }
}

final class WriteFileTool: BaseFileTool, AgentTool {
    let name = "write_file"
    let description = "Write content to a file. Creates the file if it does not exist, or overwrites if it does."
    let requiredPermission = PermissionLevel.write

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to the file", required: true),
                .init(name: "content", type: "string", description: "Content to write to the file", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String,
              let content = parameters["content"] as? String else {
            throw AgentError(message: "Missing required parameters: path, content", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.write, resource: path)

        let dir = (resolved as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: dir) {
            try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        try content.write(toFile: resolved, atomically: true, encoding: .utf8)
        log(toolName: name, path: path, success: true)
        return "File written successfully: \(path)"
    }
}

final class CreateFileTool: BaseFileTool, AgentTool {
    let name = "create_file"
    let description = "Create a new file with optional initial content. Fails if the file already exists."
    let requiredPermission = PermissionLevel.write

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path for the new file", required: true),
                .init(name: "content", type: "string", description: "Initial content (optional)", required: false),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String else {
            throw AgentError(message: "Missing required parameter: path", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.write, resource: path)

        guard !fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "File already exists")
            throw AgentError(message: "File already exists: \(path)", code: .toolExecutionFailed)
        }

        let content = parameters["content"] as? String ?? ""
        let dir = (resolved as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: dir) {
            try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        try content.write(toFile: resolved, atomically: true, encoding: .utf8)
        log(toolName: name, path: path, success: true)
        return "File created: \(path)"
    }
}

final class DeleteFileTool: BaseFileTool, AgentTool {
    let name = "delete_file"
    let description = "Delete a file. This action is irreversible."
    let requiredPermission = PermissionLevel.delete

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to the file to delete", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String else {
            throw AgentError(message: "Missing required parameter: path", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.delete, resource: path)

        guard fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "File not found")
            throw AgentError(message: "File not found: \(path)", code: .toolExecutionFailed)
        }

        try fileManager.removeItem(atPath: resolved)
        log(toolName: name, path: path, success: true)
        return "File deleted: \(path)"
    }
}

final class RenameFileTool: BaseFileTool, AgentTool {
    let name = "rename_file"
    let description = "Rename or move a file within the project."
    let requiredPermission = PermissionLevel.write

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Current relative path", required: true),
                .init(name: "new_name", type: "string", description: "New filename (same directory) or new relative path", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String,
              let newName = parameters["new_name"] as? String else {
            throw AgentError(message: "Missing required parameters: path, new_name", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.write, resource: path)

        let newPath: String
        if newName.contains("/") {
            newPath = try validatePath(newName)
        } else {
            let dir = (resolved as NSString).deletingLastPathComponent
            newPath = (dir as NSString).appendingPathComponent(newName)
        }

        guard fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "File not found")
            throw AgentError(message: "File not found: \(path)", code: .toolExecutionFailed)
        }

        try fileManager.moveItem(atPath: resolved, toPath: newPath)
        log(toolName: name, path: path, success: true)
        return "File renamed: \(path) -> \(newName)"
    }
}

final class MoveFileTool: BaseFileTool, AgentTool {
    let name = "move_file"
    let description = "Move a file to a new location within the project."
    let requiredPermission = PermissionLevel.write

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "source", type: "string", description: "Current relative path", required: true),
                .init(name: "destination", type: "string", description: "New relative path", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let source = parameters["source"] as? String,
              let destination = parameters["destination"] as? String else {
            throw AgentError(message: "Missing required parameters: source, destination", code: .invalidTool)
        }
        let resolvedSource = try validatePath(source)
        let resolvedDest = try validatePath(destination)
        try checkPermission(.write, resource: source)

        guard fileManager.fileExists(atPath: resolvedSource) else {
            log(toolName: name, path: source, success: false, error: "Source not found")
            throw AgentError(message: "Source not found: \(source)", code: .toolExecutionFailed)
        }

        let destDir = (resolvedDest as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: destDir) {
            try fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        }

        try fileManager.moveItem(atPath: resolvedSource, toPath: resolvedDest)
        log(toolName: name, path: source, success: true)
        return "File moved: \(source) -> \(destination)"
    }
}

final class CreateDirectoryTool: BaseFileTool, AgentTool {
    let name = "create_directory"
    let description = "Create a new directory (and any necessary intermediate directories)."
    let requiredPermission = PermissionLevel.write

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path for the new directory", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String else {
            throw AgentError(message: "Missing required parameter: path", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.write, resource: path)

        if fileManager.fileExists(atPath: resolved) {
            log(toolName: name, path: path, success: true)
            return "Directory already exists: \(path)"
        }

        try fileManager.createDirectory(atPath: resolved, withIntermediateDirectories: true)
        log(toolName: name, path: path, success: true)
        return "Directory created: \(path)"
    }
}

final class ListDirectoryTool: BaseFileTool, AgentTool {
    let name = "list_directory"
    let description = "List the contents of a directory, showing files and subdirectories."
    let requiredPermission = PermissionLevel.read

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to the directory (empty for project root)", required: false),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        let path = parameters["path"] as? String ?? "."
        let resolved = try validatePath(path)
        try checkPermission(.read, resource: path)

        guard fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "Directory not found")
            throw AgentError(message: "Directory not found: \(path)", code: .toolExecutionFailed)
        }

        let items = try fileManager.contentsOfDirectory(atPath: resolved)
        var output: [String] = []
        for item in items.sorted() {
            let itemPath = (resolved as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)
            let prefix = isDir.boolValue ? "[DIR] " : "      "
            output.append("\(prefix)\(item)")
        }

        log(toolName: name, path: path, success: true)
        if output.isEmpty {
            return "Directory is empty: \(path)"
        }
        return output.joined(separator: "\n")
    }
}

final class SearchFilesTool: BaseFileTool, AgentTool {
    let name = "search_files"
    let description = "Search for files matching a pattern (glob) within the project."
    let requiredPermission = PermissionLevel.read

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "pattern", type: "string", description: "Glob pattern to match (e.g. '*.swift', '**/*.json')", required: true),
                .init(name: "directory", type: "string", description: "Relative directory to search in (defaults to project root)", required: false),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let pattern = parameters["pattern"] as? String else {
            throw AgentError(message: "Missing required parameter: pattern", code: .invalidTool)
        }
        let searchDir = parameters["directory"] as? String ?? "."
        let resolvedDir = try validatePath(searchDir)
        try checkPermission(.read, resource: searchDir)

        guard fileManager.fileExists(atPath: resolvedDir) else {
            throw AgentError(message: "Directory not found: \(searchDir)", code: .toolExecutionFailed)
        }

        let enumerator = fileManager.enumerator(atPath: resolvedDir)
        var matches: [String] = []
        while let item = enumerator?.nextObject() as? String {
            let fullPath = (resolvedDir as NSString).appendingPathComponent(item)
            let relativePath = (searchDir == ".") ? item : "\(searchDir)/\(item)"
            let nsItem = item as NSString
            let fileName = nsItem.lastPathComponent

            if matchPattern(pattern, fileName: fileName) {
                matches.append(relativePath)
            }
        }

        log(toolName: name, path: searchDir, success: true)
        if matches.isEmpty {
            return "No files found matching: \(pattern)"
        }
        return "Found \(matches.count) file(s):\n" + matches.sorted().joined(separator: "\n")
    }

    private func matchPattern(_ pattern: String, fileName: String) -> Bool {
        if pattern.contains("**") {
            let parts = pattern.components(separatedBy: "**")
            let suffix = parts.last ?? ""
            if suffix.isEmpty { return true }
            return fileName.hasSuffix(String(suffix.dropFirst()))
        }
        if pattern.hasPrefix("*.") {
            let ext = String(pattern.dropFirst(2))
            return fileName.hasSuffix(".\(ext)")
        }
        return fileName == pattern
    }
}

final class SearchTextTool: BaseFileTool, AgentTool {
    let name = "search_text"
    let description = "Search for text occurrences across project files. Returns matching lines with file paths and line numbers."
    let requiredPermission = PermissionLevel.read

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "query", type: "string", description: "Text to search for", required: true),
                .init(name: "directory", type: "string", description: "Relative directory to search in (defaults to project root)", required: false),
                .init(name: "file_pattern", type: "string", description: "Only search files matching this extension (e.g. '.swift')", required: false),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let query = parameters["query"] as? String else {
            throw AgentError(message: "Missing required parameter: query", code: .invalidTool)
        }
        let searchDir = parameters["directory"] as? String ?? "."
        let filePattern = parameters["file_pattern"] as? String
        let resolvedDir = try validatePath(searchDir)
        try checkPermission(.read, resource: searchDir)

        guard fileManager.fileExists(atPath: resolvedDir) else {
            throw AgentError(message: "Directory not found: \(searchDir)", code: .toolExecutionFailed)
        }

        var results: [String] = []
        let enumerator = fileManager.enumerator(atPath: resolvedDir)
        while let item = enumerator?.nextObject() as? String {
            let fullPath = (resolvedDir as NSString).appendingPathComponent(item)
            let relativePath = (searchDir == ".") ? item : "\(searchDir)/\(item)"

            if let pattern = filePattern, !item.hasSuffix(pattern) { continue }

            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.localizedCaseInsensitiveContains(query) {
                    results.append("\(relativePath):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                    if results.count >= 50 { break }
                }
            }
            if results.count >= 50 { break }
        }

        log(toolName: name, path: searchDir, success: true)
        if results.isEmpty {
            return "No matches found for: \(query)"
        }
        return "Found \(results.count) match(es):\n" + results.joined(separator: "\n")
    }
}

final class GetFileMetadataTool: BaseFileTool, AgentTool {
    let name = "get_file_metadata"
    let description = "Get metadata for a file: size, creation date, modification date, and type."
    let requiredPermission = PermissionLevel.read

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to the file", required: true),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String else {
            throw AgentError(message: "Missing required parameter: path", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.read, resource: path)

        guard fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "File not found")
            throw AgentError(message: "File not found: \(path)", code: .toolExecutionFailed)
        }

        let attrs = try fileManager.attributesOfItem(atPath: resolved)
        let size = (attrs[.size] as? Int64) ?? 0
        let created = (attrs[.creationDate] as? Date) ?? Date.distantPast
        let modified = (attrs[.modificationDate] as? Date) ?? Date.distantPast
        let type = (attrs[.type] as? FileAttributeType) ?? .typeRegular
        let isDir = type == .typeDirectory

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        log(toolName: name, path: path, success: true)
        return """
        Path: \(path)
        Type: \(isDir ? "Directory" : "File")
        Size: \(formatBytes(size))
        Created: \(formatter.string(from: created))
        Modified: \(formatter.string(from: modified))
        """
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

final class GetProjectStructureTool: BaseFileTool, AgentTool {
    let name = "get_project_structure"
    let description = "Get the directory tree structure of the project, showing files and folders up to a specified depth."
    let requiredPermission = PermissionLevel.read

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to start from (defaults to project root)", required: false),
                .init(name: "max_depth", type: "integer", description: "Maximum depth to traverse (defaults to 3)", required: false),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        let path = parameters["path"] as? String ?? "."
        let maxDepth = parameters["max_depth"] as? Int ?? 3
        let resolved = try validatePath(path)
        try checkPermission(.read, resource: path)

        guard fileManager.fileExists(atPath: resolved) else {
            throw AgentError(message: "Path not found: \(path)", code: .toolExecutionFailed)
        }

        var lines: [String] = []
        buildTree(path: resolved, prefix: "", depth: 0, maxDepth: maxDepth, lines: &lines, fileManager: fileManager)

        log(toolName: name, path: path, success: true)
        return lines.isEmpty ? "(empty)" : lines.joined(separator: "\n")
    }

    private func buildTree(path: String, prefix: String, depth: Int, maxDepth: Int, lines: inout [String], fileManager: FileManager) {
        guard depth < maxDepth else { return }
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { return }
        let sorted = items.sorted { a, b in
            let aDir = ((path as NSString).appendingPathComponent(a) as NSString).pathExtension.isEmpty
            let bDir = ((path as NSString).appendingPathComponent(b) as NSString).pathExtension.isEmpty
            if aDir != bDir { return aDir && !bDir }
            return a < b
        }

        for (index, item) in sorted.enumerated() {
            let isLast = index == sorted.count - 1
            let connector = isLast ? "└── " : "├── "
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)

            if isDir.boolValue {
                lines.append("\(prefix)\(connector)\(item)/")
                let newPrefix = prefix + (isLast ? "    " : "│   ")
                buildTree(path: fullPath, prefix: newPrefix, depth: depth + 1, maxDepth: maxDepth, lines: &lines, fileManager: fileManager)
            } else {
                lines.append("\(prefix)\(connector)\(item)")
            }
        }
    }
}
