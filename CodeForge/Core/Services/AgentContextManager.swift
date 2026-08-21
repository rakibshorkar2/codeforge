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
        toolResults: [ToolResult],
        projectStructure: String?
    ) -> [AIMessage] {
        var messages: [AIMessage] = []
        var tokenEstimate = 0

        let systemPrompt = buildSystemPrompt()
        messages.append(AIMessage(role: .system, content: systemPrompt))
        tokenEstimate += estimateTokens(systemPrompt)

        if let structure = projectStructure, tokenEstimate + estimateTokens(structure) < maxTokens / 2 {
            let projectContext = "Project structure:\n\(structure)"
            messages.append(AIMessage(role: .system, content: projectContext))
            tokenEstimate += estimateTokens(projectContext)
        }

        if !recentEdits.isEmpty {
            let editContext = "Recently modified files: \(recentEdits.joined(separator: ", "))"
            messages.append(AIMessage(role: .system, content: editContext))
            tokenEstimate += estimateTokens(editContext)
        }

        messages.append(AIMessage(role: .user, content: userMessage))
        tokenEstimate += estimateTokens(userMessage)

        return messages
    }

    func appendToolResults(_ results: [ToolResult], to messages: [AIMessage]) -> [AIMessage] {
        var updated = messages
        for result in results {
            let content = result.isError ? "Error: \(result.content)" : result.content
            let truncated = truncateToTokenLimit(content, maxTokens: maxTokens / 4)
            updated.append(AIMessage(role: .tool, content: truncated))
        }
        return updated
    }

    func appendAssistantMessage(_ message: AgentMessage, to messages: [AIMessage]) -> [AIMessage] {
        var updated = messages
        updated.append(AIMessage(role: .assistant, content: message.content))
        return updated
    }

    func truncateConversation(_ messages: [AIMessage]) -> [AIMessage] {
        var result: [AIMessage] = []
        var totalTokens = 0
        let limit = maxTokens

        for message in messages.reversed() {
            let tokens = estimateTokens(message.content)
            if totalTokens + tokens > limit { break }
            result.insert(message, at: 0)
            totalTokens += tokens
        }

        return result
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

    func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }

    private func truncateToTokenLimit(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if text.count <= maxChars { return text }
        let truncated = String(text.prefix(maxChars))
        return truncated + "\n... (truncated)"
    }

    func getProjectStructure(maxDepth: Int = 3) -> String? {
        var lines: [String] = []
        buildTree(path: workspace, prefix: "", depth: 0, maxDepth: maxDepth, lines: &lines)
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func buildTree(path: String, prefix: String, depth: Int, maxDepth: Int, lines: inout [String]) {
        guard depth < maxDepth else { return }
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { return }
        let skipped: Set<String> = [".git", "node_modules", ".build", "DerivedData", ".DS_Store"]
        let sorted = items.filter { !skipped.contains($0) }.sorted()

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
