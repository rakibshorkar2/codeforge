import Foundation

struct EditFileTool: BaseFileTool, AgentTool {
    let name = "edit_file"
    let description = "Edit a file using search/replace or line-based patches. Returns an error if the patch cannot be safely applied."
    let requiredPermission = PermissionLevel.write

    var definition: AgentToolDefinition {
        AgentToolDefinition(
            name: name,
            description: description,
            parameters: [
                .init(name: "path", type: "string", description: "Relative path to the file", required: true),
                .init(name: "old_text", type: "string", description: "Text to find and replace (exact match)", required: false),
                .init(name: "new_text", type: "string", description: "Replacement text", required: false),
                .init(name: "line_start", type: "integer", description: "Start line number for line-based edit (1-indexed)", required: false),
                .init(name: "line_end", type: "integer", description: "End line number for line-based edit (1-indexed, inclusive)", required: false),
                .init(name: "replacement", type: "string", description: "Replacement text for line-based edit", required: false),
            ]
        )
    }

    func execute(parameters: [String: Any], workspace: String) throws -> String {
        guard let path = parameters["path"] as? String else {
            throw AgentError(message: "Missing required parameter: path", code: .invalidTool)
        }
        let resolved = try validatePath(path)
        try checkPermission(.write, resource: path)

        guard fileManager.fileExists(atPath: resolved) else {
            log(toolName: name, path: path, success: false, error: "File not found")
            throw AgentError(message: "File not found: \(path)", code: .toolExecutionFailed)
        }

        let content = try String(contentsOfFile: resolved, encoding: .utf8)

        let oldText = parameters["old_text"] as? String
        let newText = parameters["new_text"] as? String
        let lineStart = parameters["line_start"] as? Int
        let lineEnd = parameters["line_end"] as? Int
        let replacement = parameters["replacement"] as? String

        let newContent: String

        if let oldText = oldText, let newText = newText {
            newContent = try applySearchReplace(original: content, oldText: oldText, newText: newText, path: path)
        } else if let start = lineStart, let end = lineEnd, let replacement = replacement {
            newContent = try applyLinePatch(original: content, start: start, end: end, replacement: replacement, path: path)
        } else {
            throw AgentError(message: "Provide either old_text/new_text or line_start/line_end/replacement", code: .invalidTool)
        }

        try newContent.write(toFile: resolved, atomically: true, encoding: .utf8)
        log(toolName: name, path: path, success: true)
        return "File edited successfully: \(path)"
    }

    private func applySearchReplace(original: String, oldText: String, newText: String, path: String) throws -> String {
        guard original.contains(oldText) else {
            throw AgentError(message: "Search text not found in \(path). The text may have changed or the match is not exact.", code: .toolExecutionFailed)
        }

        let count = original.components(separatedBy: oldText).count - 1
        if count > 1 {
            throw AgentError(message: "Ambiguous edit: found \(count) occurrences of search text in \(path). Provide more context to make the match unique.", code: .toolExecutionFailed)
        }

        return original.replacingOccurrences(of: oldText, with: newText)
    }

    private func applyLinePatch(original: String, start: Int, end: Int, replacement: String, path: String) throws -> String {
        let lines = original.components(separatedBy: .newlines)

        guard start >= 1, start <= lines.count else {
            throw AgentError(message: "Line start \(start) out of range (1-\(lines.count)) in \(path)", code: .toolExecutionFailed)
        }
        guard end >= start, end <= lines.count else {
            throw AgentError(message: "Line end \(end) out of range (\(start)-\(lines.count)) in \(path)", code: .toolExecutionFailed)
        }

        var newLines = Array(lines.prefix(start - 1))
        newLines.append(contentsOf: replacement.components(separatedBy: .newlines))
        newLines.append(contentsOf: lines.suffix(from: end))

        return newLines.joined(separator: "\n")
    }
}
