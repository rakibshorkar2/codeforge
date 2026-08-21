import Foundation

struct AgentMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var toolCalls: [ToolCall]?
    var toolCallID: String?

    enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    struct ToolCall: Codable, Equatable {
        let id: String
        let name: String
        let arguments: String
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        toolCalls: [ToolCall]? = nil,
        toolCallID: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
    }
}

struct ToolResult: Codable, Equatable {
    let toolCallID: String
    let content: String
    let isError: Bool

    init(toolCallID: String, content: String, isError: Bool = false) {
        self.toolCallID = toolCallID
        self.content = content
        self.isError = isError
    }
}

struct AgentPlan: Codable, Equatable {
    var steps: [Step]
    var currentStepIndex: Int
    let createdAt: Date

    struct Step: Codable, Equatable {
        var description: String
        var status: Status

        enum Status: String, Codable {
            case pending
            case inProgress
            case completed
            case failed
        }
    }

    init(steps: [Step] = [], currentStepIndex: Int = 0, createdAt: Date = Date()) {
        self.steps = steps
        self.currentStepIndex = currentStepIndex
        self.createdAt = createdAt
    }

    var currentStep: Step? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var isComplete: Bool {
        currentStepIndex >= steps.count
    }

    mutating func advanceStep() {
        if currentStepIndex < steps.count {
            steps[currentStepIndex].status = .completed
            currentStepIndex += 1
        }
    }

    mutating func markCurrentFailed() {
        if currentStepIndex < steps.count {
            steps[currentStepIndex].status = .failed
        }
    }
}

enum AgentMode: String, Codable, CaseIterable {
    case ask = "Ask"
    case plan = "Plan"
    case code = "Code"

    var description: String {
        switch self {
        case .ask: return "Read-only. Ask questions about the codebase."
        case .plan: return "Analyze and plan changes without modifying files."
        case .code: return "Full access to read and modify files."
        }
    }
}

struct AgentToolDefinition: Codable, Equatable {
    let name: String
    let description: String
    let parameters: [Parameter]

    struct Parameter: Codable, Equatable {
        let name: String
        let type: String
        let description: String
        let required: Bool
    }

    var functionSchema: [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        for param in parameters {
            properties[param.name] = ["type": param.type, "description": param.description]
            if param.required {
                required.append(param.name)
            }
        }
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ],
            ],
        ]
    }
}

struct AgentTokenUsage: Codable {
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int

    init(promptTokens: Int = 0, completionTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = promptTokens + completionTokens
    }

    mutating func add(_ other: AgentTokenUsage) {
        promptTokens += other.promptTokens
        completionTokens += other.completionTokens
        totalTokens += other.totalTokens
    }
}

final class AgentConfig: Codable {
    var maxIterations: Int
    var maxContextTokens: Int
    var maxResponseTokens: Int
    var mode: AgentMode

    init(
        maxIterations: Int = 20,
        maxContextTokens: Int = 8000,
        maxResponseTokens: Int = 4096,
        mode: AgentMode = .code
    ) {
        self.maxIterations = maxIterations
        self.maxContextTokens = maxContextTokens
        self.maxResponseTokens = maxResponseTokens
        self.mode = mode
    }
}

struct AgentError: Error, LocalizedError {
    let message: String
    let code: Code

    enum Code: String {
        case maxIterations = "MAX_ITERATIONS"
        case permissionDenied = "PERMISSION_DENIED"
        case pathViolation = "PATH_VIOLATION"
        case toolExecutionFailed = "TOOL_EXECUTION_FAILED"
        case cancelled = "CANCELLED"
        case providerError = "PROVIDER_ERROR"
        case invalidTool = "INVALID_TOOL"
        case contextOverflow = "CONTEXT_OVERFLOW"
    }

    var errorDescription: String? { message }
}

struct AuditLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let toolName: String
    let filePath: String
    let success: Bool
    let errorMessage: String?

    init(toolName: String, filePath: String, success: Bool, errorMessage: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.toolName = toolName
        self.filePath = filePath
        self.success = success
        self.errorMessage = errorMessage
    }
}
