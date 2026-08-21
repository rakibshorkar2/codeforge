import Foundation

@MainActor
final class AgentManager: ObservableObject {
    @Published var currentSession: AgentSession?
    @Published var isProcessing = false
    @Published var lastError: AgentError?
    @Published var recentEdits: [String] = []
    @Published var changeTracker = AgentChangeTracker()
    @Published var streamingContent: String = ""
    @Published var statusMessage: String = ""

    var config: AgentConfig
    let permissionManager: AgentPermissionManager
    let auditLog: AgentAuditLog
    let sessionStore: AgentSessionStore

    private var toolRegistry: AgentToolRegistry?
    private var contextManager: AgentContextManager?
    private var requestService: AIRequestService?
    private var currentTask: Task<Void, Never>?

    init(
        config: AgentConfig = AgentConfig(),
        permissionManager: AgentPermissionManager = AgentPermissionManager(),
        auditLog: AgentAuditLog = AgentAuditLog(),
        sessionStore: AgentSessionStore = AgentSessionStore()
    ) {
        self.config = config
        self.permissionManager = permissionManager
        self.auditLog = auditLog
        self.sessionStore = sessionStore
    }

    func startSession(projectID: String, projectName: String, workspace: String, requestService: AIRequestService) {
        let session = AgentSession(projectID: projectID, projectName: projectName, workspace: workspace)
        self.currentSession = session
        self.requestService = requestService
        self.toolRegistry = AgentToolRegistry.defaultRegistry(
            workspace: workspace,
            permissionManager: permissionManager,
            auditLog: auditLog
        )
        self.contextManager = AgentContextManager(workspace: workspace, maxTokens: config.maxContextTokens)
        recentEdits.removeAll()
        changeTracker.clear()
        streamingContent = ""
        statusMessage = ""
    }

    func resumeSession(_ persisted: PersistedAgentSession, requestService: AIRequestService) {
        let session = AgentSession(projectID: persisted.projectID, projectName: persisted.projectName, workspace: persisted.workspace)
        session.messages = persisted.messages
        session.addTokens(persisted.tokenUsage)
        for _ in 0..<persisted.iterationCount { session.incrementIteration() }
        self.currentSession = session
        self.requestService = requestService
        self.toolRegistry = AgentToolRegistry.defaultRegistry(
            workspace: persisted.workspace,
            permissionManager: permissionManager,
            auditLog: auditLog
        )
        self.contextManager = AgentContextManager(workspace: persisted.workspace, maxTokens: config.maxContextTokens)
        recentEdits.removeAll()
        changeTracker.clear()
    }

    func stopSession() {
        currentTask?.cancel()
        currentTask = nil
        currentSession?.isRunning = false
        isProcessing = false
        statusMessage = ""
        streamingContent = ""
    }

    func processMessage(_ userMessage: String) async {
        guard let session = currentSession, let service = requestService,
              let context = contextManager else { return }

        session.isRunning = true
        isProcessing = true
        lastError = nil
        statusMessage = "Processing..."
        session.addUserMessage(userMessage)

        defer {
            session.isRunning = false
            isProcessing = false
            statusMessage = ""
            streamingContent = ""
            saveSession()
        }

        let referencedFiles = context.extractReferencedFiles(from: userMessage)

        var iteration = 0
        while iteration < config.maxIterations {
            guard !Task.isCancelled else { return }
            iteration += 1
            session.incrementIteration()
            statusMessage = "Thinking... (iteration \(iteration))"

            let projectStructure = context.getProjectStructure()
            var aiMessages = context.buildContext(
                userMessage: userMessage,
                recentEdits: recentEdits,
                referencedFiles: referencedFiles,
                projectStructure: projectStructure
            )

            for msg in session.messages {
                if msg.role == .assistant {
                    aiMessages.append(AIMessage(role: .assistant, content: msg.content))
                } else if msg.role == .tool {
                    aiMessages.append(AIMessage(role: .user, content: "[Tool Result] \(msg.content)"))
                }
            }

            aiMessages = context.truncateConversation(aiMessages)

            let toolDefs = toolRegistry?.toolDefinitions() ?? []
            let toolContext = buildToolContext(tools: toolDefs, mode: config.mode)
            if !toolContext.isEmpty {
                aiMessages.insert(AIMessage(role: .system, content: toolContext), at: 1)
            }

            do {
                streamingContent = ""
                let response = try await service.sendMessage(aiMessages, maxTokens: config.maxResponseTokens)
                let assistantContent = response.choices.first?.message?.content ?? ""

                if assistantContent.isEmpty && (response.choices.first?.finishReason == "stop" || response.choices.first?.finishReason == "end_turn") {
                    session.addAssistantMessage("(Task complete)")
                    break
                }

                streamingContent = assistantContent
                session.addAssistantMessage(assistantContent)

                if config.mode == .plan || config.mode == .ask {
                    break
                }

                if let toolCalls = parseToolCalls(from: assistantContent) {
                    let toolResults = await executeToolCalls(toolCalls, session: session)
                    if !toolResults.isEmpty {
                        for result in toolResults {
                            session.addToolResultMessage(result)
                        }
                    }
                } else {
                    break
                }

                if let usage = response.usage {
                    session.addTokens(AgentTokenUsage(
                        promptTokens: usage.promptTokens ?? 0,
                        completionTokens: usage.completionTokens ?? 0
                    ))
                }
            } catch is CancellationError {
                return
            } catch {
                lastError = AgentError(message: error.localizedDescription, code: .providerError)
                statusMessage = "Error: \(error.localizedDescription)"
                return
            }
        }

        if iteration >= config.maxIterations {
            lastError = AgentError(
                message: "Reached maximum iterations (\(config.maxIterations)). Stopping to prevent infinite loop.",
                code: .maxIterations
            )
        }

        statusMessage = "Completed"
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        currentSession?.isRunning = false
        isProcessing = false
        lastError = AgentError(message: "Cancelled by user", code: .cancelled)
        statusMessage = "Cancelled"
        streamingContent = ""
    }

    func rollbackSession() -> [String] {
        guard let workspace = currentSession?.workspace else { return [] }
        return changeTracker.rollback(workspace: workspace)
    }

    func retryLastMessage() async {
        guard let session = currentSession else { return }
        let lastUserMessage = session.messages.last(where: { $0.role == .user })?.content ?? ""
        guard !lastUserMessage.isEmpty else { return }
        await processMessage(lastUserMessage)
    }

    func saveSession() {
        guard let session = currentSession else { return }
        let persisted = PersistedAgentSession(from: session)
        try? sessionStore.save(persisted)
    }

    func loadSessions(forProject projectID: String) -> [PersistedAgentSession] {
        (try? sessionStore.sessions(forProject: projectID)) ?? []
    }

    func deleteSession(id: UUID) {
        try? sessionStore.delete(id: id)
    }

    func newChat() {
        guard let session = currentSession else { return }
        let projectID = session.projectID
        let projectName = session.projectName
        let workspace = session.workspace
        let service = requestService
        changeTracker.clear()
        recentEdits.removeAll()
        streamingContent = ""
        statusMessage = ""
        startSession(projectID: projectID, projectName: projectName, workspace: workspace, requestService: service!)
    }

    func getAuditTimeline() -> [(String, Bool, String)] {
        auditLog.entries().suffix(20).map { entry in
            (entry.toolName, entry.success, entry.filePath)
        }
    }

    func checkConflict(path: String) -> Bool {
        guard let workspace = currentSession?.workspace else { return false }
        let fullPath = (workspace as NSString).appendingPathComponent(path)
        guard let currentContent = try? String(contentsOfFile: fullPath, encoding: .utf8) else { return false }
        return changeTracker.hasConflict(path: path, currentContent: currentContent)
    }

    private func buildToolContext(tools: [AgentToolDefinition], mode: AgentMode) -> String {
        switch mode {
        case .ask:
            return "Mode: Ask (read-only). You can only read files and answer questions. Do not use write/edit/delete tools."
        case .plan:
            return "Mode: Plan. You can analyze the project and propose changes. Do not use write/edit/delete tools. Describe what changes you would make as a numbered list."
        case .code:
            let toolNames = tools.map(\.name).joined(separator: ", ")
            return "Available tools: \(toolNames). Use the format [TOOL:tool_name] with JSON parameters to call a tool."
        }
    }

    private func parseToolCalls(from response: String) -> [AgentMessage.ToolCall]? {
        let pattern = #"\[TOOL:(\w+)\]\s*(\{[^}]*\})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let _ = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
            return nil
        }

        var calls: [AgentMessage.ToolCall] = []
        let matches = regex.matches(in: response, range: NSRange(response.startIndex..., in: response))

        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: response) else { continue }
            let toolName = String(response[nameRange])

            let argsStr: String
            if let argsRange = Range(match.range(at: 2), in: response) {
                argsStr = String(response[argsRange])
            } else {
                argsStr = "{}"
            }

            let call = AgentMessage.ToolCall(id: UUID().uuidString, name: toolName, arguments: argsStr)
            calls.append(call)
        }

        return calls.isEmpty ? nil : calls
    }

    private func executeToolCalls(_ toolCalls: [AgentMessage.ToolCall], session: AgentSession) async -> [ToolResult] {
        guard let registry = toolRegistry else { return [] }
        var results: [ToolResult] = []

        for call in toolCalls {
            guard let tool = registry.tool(named: call.name) else {
                results.append(ToolResult(toolCallID: call.id, content: "Unknown tool: \(call.name)", isError: true))
                continue
            }

            if config.mode == .ask || config.mode == .plan {
                if tool.requiredPermission != .read {
                    results.append(ToolResult(
                        toolCallID: call.id,
                        content: "Tool \(call.name) is not available in \(config.mode.rawValue) mode",
                        isError: true
                    ))
                    continue
                }
            }

            let params = parseArguments(call.arguments)

            if tool.requiredPermission.destructive {
                let resource = params["path"] as? String ?? params["source"] as? String ?? ""
                statusMessage = "Requesting permission: \(tool.name) on \(resource)"
                let decision = await permissionManager.requestPermissionAsync(level: tool.requiredPermission, resource: resource)
                guard decision == .allowOnce || decision == .allowForSession else {
                    results.append(ToolResult(toolCallID: call.id, content: "Permission denied for \(tool.name) on \(resource)", isError: true))
                    statusMessage = ""
                    continue
                }
            }

            statusMessage = "Executing \(tool.name)..."
            do {
                if tool.requiredPermission == .write || tool.requiredPermission == .delete {
                    let path = params["path"] as? String ?? params["source"] as? String ?? ""
                    if checkConflict(path: path) {
                        results.append(ToolResult(
                            toolCallID: call.id,
                            content: "File Changed Externally: \(path) was modified after the agent inspected it. Please review and retry.",
                            isError: true
                        ))
                        continue
                    }
                    captureSnapshot(path: path, workspace: session.workspace)
                }

                let result = try tool.execute(parameters: params, workspace: session.workspace)
                results.append(ToolResult(toolCallID: call.id, content: result))

                if tool.requiredPermission == .write || tool.requiredPermission == .delete {
                    let path = params["path"] as? String ?? params["source"] as? String ?? ""
                    recentEdits.append(path)
                    if recentEdits.count > 20 { recentEdits.removeFirst(recentEdits.count - 20) }

                    let operation: AgentChangeTracker.FileChange.Operation
                    switch tool.name {
                    case "create_file": operation = .create
                    case "delete_file": operation = .delete
                    case "rename_file": operation = .rename
                    case "move_file": operation = .move
                    default: operation = .modify
                    }
                    let snapshot = changeTracker.snapshot(for: path)
                    changeTracker.recordChange(AgentChangeTracker.FileChange(
                        path: path,
                        operation: operation,
                        oldContent: snapshot?.content,
                        newContent: nil
                    ))
                }

                auditLog.record(toolName: tool.name, filePath: params["path"] as? String ?? "", success: true)
            } catch {
                results.append(ToolResult(toolCallID: call.id, content: error.localizedDescription, isError: true))
                auditLog.record(toolName: tool.name, filePath: params["path"] as? String ?? "", success: false, errorMessage: error.localizedDescription)
            }
            statusMessage = ""
        }

        return results
    }

    private func captureSnapshot(path: String, workspace: String) {
        let fullPath = (workspace as NSString).appendingPathComponent(path)
        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
            changeTracker.snapshot(path: path, content: content)
        }
    }

    private func parseArguments(_ jsonString: String) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }
}
