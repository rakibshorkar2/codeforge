import Foundation

struct AgentContextManager {
    let workspace: String
    let maxTokens: Int
    private let fileManager: FileManager

    init(workspace: String, maxTokens: Int = 8000, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.maxTokens = maxTokens
        self.fileManager = fileManager
    }

    func buildContext(
        userMessage: String,
        recentEdits: [String],
        referencedFiles: [String],
        projectStructure: String?
    ) -> [AIMessage] {
        var messages: [AIMessage] = []
        var tokenEstimate = 0

        let systemPrompt = buildSystemPrompt()
        messages.append(AIMessage(role: .system, content: systemPrompt))
        tokenEstimate += estimateTokens(systemPrompt)

        if let referenced = buildReferencedFilesContext(referencedFiles), tokenEstimate + estimateTokens(referenced) < maxTokens / 2 {
            messages.append(AIMessage(role: .system, content: referenced))
            tokenEstimate += estimateTokens(referenced)
        }

        if !recentEdits.isEmpty {
            let editContext = "Recently modified files: \(recentEdits.suffix(10).joined(separator: ", "))"
            messages.append(AIMessage(role: .system, content: editContext))
            tokenEstimate += estimateTokens(editContext)
        }

        if let structure = projectStructure, tokenEstimate + estimateTokens(structure) < maxTokens / 2 {
            messages.append(AIMessage(role: .system, content: "Project structure:\n\(structure)"))
            tokenEstimate += estimateTokens(structure)
        }

        messages.append(AIMessage(role: .user, content: userMessage))
        tokenEstimate += estimateTokens(userMessage)

        return messages
    }

    func buildReferencedFilesContext(_ paths: [String]) -> String? {
        guard !paths.isEmpty else { return nil }
        var parts: [String] = ["Referenced files:"]
        for path in paths {
            let fullPath = (workspace as NSString).appendingPathComponent(path)
            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                let truncated = String(content.prefix(2000))
                parts.append("--- \(path) ---\n\(truncated)\n---")
            } else {
                parts.append("--- \(path) --- (unreadable)")
            }
        }
        return parts.joined(separator: "\n")
    }

    func summarizeToolResults(_ results: [ToolResult], maxTokens: Int) -> String {
        var summary: [String] = []
        var estimate = 0
        for result in results {
            let text = result.isError ? "[ERROR] \(result.content)" : result.content
            let truncated = truncateToTokenLimit(text, maxTokens: maxTokens / max(results.count, 1))
            let lineEstimate = estimateTokens(truncated)
            if estimate + lineEstimate > maxTokens { break }
            summary.append(truncated)
            estimate += lineEstimate
        }
        return summary.joined(separator: "\n\n")
    }

    func truncateConversation(_ messages: [AIMessage]) -> [AIMessage] {
        var result: [AIMessage] = []
        var totalTokens = 0

        for message in messages.reversed() {
            let tokens = estimateTokens(message.content)
            if totalTokens + tokens > maxTokens { break }
            result.insert(message, at: 0)
            totalTokens += tokens
        }

        return result
    }

    func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }

    func getProjectStructure(maxDepth: Int = 3) -> String? {
        var lines: [String] = []
        buildTree(path: workspace, prefix: "", depth: 0, maxDepth: maxDepth, lines: &lines)
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    func extractReferencedFiles(from message: String) -> [String] {
        var files: [String] = []
        let patterns = [
            #"(?:file|path|read|write|edit|modify):\s*[`"']?([^\s`"']+\.\w+)[`"']?"#,
            #"[`"']([^\s`"']+\.\w+)[`"']?"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: message, range: NSRange(message.startIndex..., in: message))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: message) {
                        files.append(String(message[range]))
                    }
                }
            }
        }
        return Array(Set(files))
    }

    private func buildSystemPrompt() -> String {
        """
        You are an AI coding assistant inside the CodeForge iOS app. You have access to the user's project files through tools.

        Rules:
        - Only use tools that are available to you
        - Always validate your actions before executing them
        - When editing files, prefer search/replace over rewriting entire files
        - Never attempt to access files outside the project workspace
        - If a task is ambiguous, ask the user for clarification
        - When you're done with a task, summarize what you did

        You operate in one of three modes:
        - Ask: Read-only. You can only read files and answer questions.
        - Plan: You can analyze the project and propose changes but cannot modify files.
        - Code: Full access to read and modify files.
        """
    }

    private func truncateToTokenLimit(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if text.count <= maxChars { return text }
        return String(text.prefix(maxChars)) + "\n... (truncated)"
    }

    private func buildTree(path: String, prefix: String, depth: Int, maxDepth: Int, lines: inout [String]) {
        guard depth < maxDepth else { return }
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { return }
        let skipped: Set<String> = [".git", "node_modules", ".build", "DerivedData", ".DS_Store", ".swiftpm", "xcuserdata"]
        let sorted = items.filter { !skipped.contains($0) && !$0.hasPrefix(".") }.sorted()

        for (index, item) in sorted.enumerated() {
            let isLast = index == sorted.count - 1
            let connector = isLast ? "└── " : "├── "
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)

            if isDir.boolValue {
                lines.append("\(prefix)\(connector)\(item)/")
                let newPrefix = prefix + (isLast ? "    " : "│   ")
                buildTree(path: fullPath, prefix: newPrefix, depth: depth + 1, maxDepth: maxDepth, lines: &lines)
            } else {
                lines.append("\(prefix)\(connector)\(item)")
            }
        }
    }
}
