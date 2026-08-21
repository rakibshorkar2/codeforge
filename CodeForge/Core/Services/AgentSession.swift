import Foundation

@MainActor
final class AgentSession: ObservableObject, Identifiable {
    let id: UUID
    let projectID: String
    let projectName: String
    let workspace: String

    @Published var messages: [AgentMessage] = []
    @Published var isRunning = false
    @Published var currentPlan: AgentPlan?
    @Published var tokenUsage: AgentTokenUsage = AgentTokenUsage()

    private(set) var iterationCount = 0

    init(projectID: String, projectName: String, workspace: String) {
        self.id = UUID()
        self.projectID = projectID
        self.projectName = projectName
        self.workspace = workspace
    }

    func addUserMessage(_ content: String) {
        let message = AgentMessage(role: .user, content: content)
        messages.append(message)
    }

    func addAssistantMessage(_ content: String, toolCalls: [AgentMessage.ToolCall]? = nil) {
        let message = AgentMessage(role: .assistant, content: content, toolCalls: toolCalls)
        messages.append(message)
    }

    func addToolResultMessage(_ result: ToolResult) {
        let message = AgentMessage(role: .tool, content: result.content, toolCallID: result.toolCallID)
        messages.append(message)
    }

    func addSystemMessage(_ content: String) {
        let message = AgentMessage(role: .system, content: content)
        messages.append(message)
    }

    func incrementIteration() {
        iterationCount += 1
    }

    func addTokens(_ usage: AgentTokenUsage) {
        tokenUsage.add(usage)
    }

    func reset() {
        messages.removeAll()
        iterationCount = 0
        tokenUsage = AgentTokenUsage()
        currentPlan = nil
        isRunning = false
    }
}
