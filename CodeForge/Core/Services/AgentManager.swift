import Foundation

@MainActor
final class AgentManager: ObservableObject {
    @Published var currentSession: AgentSession?
    @Published var isProcessing = false
    @Published var lastError: AgentError?
    @Published var recentEdits: [String] = []

    let config: AgentConfig
    let permissionManager: AgentPermissionManager
    let auditLog: AgentAuditLog

    private var toolRegistry: AgentToolRegistry?
    private var contextManager: AgentContextManager?
    private var requestService: AIRequestService?
    private var currentTask: Task<Void, Never>?

    init(
        config: AgentConfig = AgentConfig(),
        permissionManager: AgentPermissionManager = AgentPermissionManager(),
        auditLog: AgentAuditLog = AgentAuditLog()
    ) {
        self.config = config
        self.permissionManager = permissionManager
        self.auditLog = auditLog
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
    }

    func stopSession() {
        currentTask?.cancel()
        currentTask = nil
        currentSession?.isRunning = false
        isProcessing = false
    }

    func processMessage(_ userMessage: String) async {
        guard let session = currentSession, let service = requestService,
              let context = contextManager else {
            return
        }

        session.isRunning = true
        isProcessing = true
        lastError = nil
        session.addUserMessage(userMessage)

        defer {
            session.isRunning = false
            isProcessing = false
        }

        var iteration = 0
        while iteration < config.maxIterations {
            iteration += 1
            session.incrementIteration()

            let projectStructure = context.getProjectStructure()
            var aiMessages = context.buildContext(
                userMessage: userMessage,
                recentEdits: recentEdits,
                toolResults: [],
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
                let response = try await service.sendMessage(aiMessages, maxTokens: config.maxResponseTokens)
                let assistantContent = response.choices.first?.message?.content ?? ""

                if assistantContent.isEmpty && (response.choices.first?.finishReason == "stop" || response.choices.first?.finishReason == "end_turn") {
                    session.addAssistantMessage("(Task complete)")
                    break
                }

                session.addAssistantMessage(assistantContent)

                if config.mode == .plan {
                    break
                }

                if config.mode == .ask {
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
                return
            }
        }

        if iteration >= config.maxIterations {
            lastError = AgentError(
                message: "Reached maximum iterations (\(config.maxIterations)). Stopping to prevent infinite loop.",
                code: .maxIterations
            )
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        currentSession?.isRunning = false
        isProcessing = false
        lastError = AgentError(message: "Cancelled by user", code: .cancelled)
    }

    private func buildToolContext(tools: [AgentToolDefinition], mode: AgentMode) -> String {
        switch mode {
        case .ask:
            return "Mode: Ask (read-only). You can only read files and answer questions. Do not use write/edit/delete tools."
        case .plan:
            return "Mode: Plan. You can analyze the project and propose changes. Do not use write/edit/delete tools. Describe what changes you would make."
        case .code:
            let toolNames = tools.map(\.name).joined(separator: ", ")
            return "Available tools: \(toolNames). Use the format [TOOL:tool_name] with parameters to call a tool."
        }
    }

    private func parseToolCalls(from response: String) -> [AgentMessage.ToolCall]? {
        let pattern = #"\[TOOL:(\w+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let _ = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
            return nil
        }

        var calls: [AgentMessage.ToolCall] = []
        let matches = regex.matches(in: response, range: NSRange(response.startIndex..., in: response))

        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: response) else { continue }
            let toolName = String(response[nameRange])

            let argsPattern = #"\{[^}]*\}"#
            if let argsRegex = try? NSRegularExpression(pattern: argsPattern),
               let argsMatch = argsRegex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
               let argsRange = Range(argsMatch.range, in: response) {
                let argsStr = String(response[argsRange])
                let call = AgentMessage.ToolCall(id: UUID().uuidString, name: toolName, arguments: argsStr)
                calls.append(call)
            } else {
                let call = AgentMessage.ToolCall(id: UUID().uuidString, name: toolName, arguments: "{}")
                calls.append(call)
            }
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
            do {
                let result = try tool.execute(parameters: params, workspace: session.workspace)
                results.append(ToolResult(toolCallID: call.id, content: result))

                if tool.requiredPermission == .write || tool.requiredPermission == .delete {
                    if let path = params["path"] as? String ?? params["source"] as? String {
                        recentEdits.append(path)
                        if recentEdits.count > 20 {
                            recentEdits.removeFirst(recentEdits.count - 20)
                        }
                    }
                }
            } catch {
                results.append(ToolResult(toolCallID: call.id, content: error.localizedDescription, isError: true))
            }
        }

        return results
    }

    private func parseArguments(_ jsonString: String) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }
}
