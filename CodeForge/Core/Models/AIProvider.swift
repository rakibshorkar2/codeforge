import Foundation

struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let providerID: String
    let displayName: String
    var contextWindow: Int?
    var supportsStreaming: Bool
    var supportsFunctionCalling: Bool

    init(
        id: String,
        providerID: String,
        displayName: String,
        contextWindow: Int? = nil,
        supportsStreaming: Bool = true,
        supportsFunctionCalling: Bool = false
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName
        self.contextWindow = contextWindow
        self.supportsStreaming = supportsStreaming
        self.supportsFunctionCalling = supportsFunctionCalling
    }
}

enum AIProviderType: String, CaseIterable, Codable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case googleGemini = "google_gemini"
    case openRouter = "openrouter"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .googleGemini: return "Google Gemini"
        case .openRouter: return "OpenRouter"
        case .custom: return "Custom Endpoint"
        }
    }

    var icon: String {
        switch self {
        case .openAI: return "brain.head.profile"
        case .anthropic: return "a.circle"
        case .googleGemini: return "sparkle"
        case .openRouter: return "arrow.triangle.branch"
        case .custom: return "gearshape"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .googleGemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }

    var defaultModels: [AIModel] {
        switch self {
        case .openAI:
            return [
                AIModel(id: "gpt-4o", providerID: rawValue, displayName: "GPT-4o", contextWindow: 128000, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "gpt-4o-mini", providerID: rawValue, displayName: "GPT-4o Mini", contextWindow: 128000, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "o1", providerID: rawValue, displayName: "o1", contextWindow: 200000, supportsStreaming: false, supportsFunctionCalling: false),
                AIModel(id: "o1-mini", providerID: rawValue, displayName: "o1 Mini", contextWindow: 128000, supportsStreaming: false, supportsFunctionCalling: false),
            ]
        case .anthropic:
            return [
                AIModel(id: "claude-sonnet-4-20250514", providerID: rawValue, displayName: "Claude Sonnet 4", contextWindow: 200000, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "claude-3-5-sonnet-20241022", providerID: rawValue, displayName: "Claude 3.5 Sonnet", contextWindow: 200000, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "claude-3-5-haiku-20241022", providerID: rawValue, displayName: "Claude 3.5 Haiku", contextWindow: 200000, supportsStreaming: true, supportsFunctionCalling: true),
            ]
        case .googleGemini:
            return [
                AIModel(id: "gemini-2.0-flash", providerID: rawValue, displayName: "Gemini 2.0 Flash", contextWindow: 1048576, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "gemini-2.5-pro-preview-05-06", providerID: rawValue, displayName: "Gemini 2.5 Pro", contextWindow: 1048576, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "gemini-1.5-pro", providerID: rawValue, displayName: "Gemini 1.5 Pro", contextWindow: 2097152, supportsStreaming: true, supportsFunctionCalling: true),
            ]
        case .openRouter:
            return [
                AIModel(id: "openai/gpt-4o", providerID: rawValue, displayName: "GPT-4o (via OpenRouter)", contextWindow: 128000, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "anthropic/claude-sonnet-4-20250514", providerID: rawValue, displayName: "Claude Sonnet 4 (via OpenRouter)", contextWindow: 200000, supportsStreaming: true, supportsFunctionCalling: true),
                AIModel(id: "google/gemini-2.0-flash", providerID: rawValue, displayName: "Gemini 2.0 Flash (via OpenRouter)", contextWindow: 1048576, supportsStreaming: true, supportsFunctionCalling: true),
            ]
        case .custom:
            return []
        }
    }
}

struct ProviderConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: AIProviderType
    var baseURL: String
    var isEnabled: Bool
    var selectedModelID: String?
    var customModels: [AIModel]

    init(
        id: UUID = UUID(),
        name: String,
        type: AIProviderType,
        baseURL: String? = nil,
        isEnabled: Bool = true,
        selectedModelID: String? = nil,
        customModels: [AIModel] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.baseURL = baseURL ?? type.defaultBaseURL
        self.isEnabled = isEnabled
        self.selectedModelID = selectedModelID
        self.customModels = customModels
    }

    var availableModels: [AIModel] {
        if type == .custom {
            return customModels
        }
        return type.defaultModels + customModels
    }

    var selectedModel: AIModel? {
        guard let modelID = selectedModelID else { return availableModels.first }
        return availableModels.first { $0.id == modelID }
    }

    static func == (lhs: ProviderConfig, rhs: ProviderConfig) -> Bool {
        lhs.id == rhs.id
    }
}

struct AIMessage: Codable, Equatable {
    let role: MessageRole
    let content: String

    enum MessageRole: String, Codable {
        case system
        case user
        case assistant
    }
}

struct AIChatRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let stream: Bool
    var temperature: Double?
    var maxTokens: Int?

    init(model: String, messages: [AIMessage], stream: Bool = true, temperature: Double? = nil, maxTokens: Int? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

struct AIChatResponse: Codable {
    let id: String?
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let index: Int?
        let message: AIMessage?
        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case delta
            case finishReason = "finish_reason"
        }

        struct Delta: Codable {
            let role: String?
            let content: String?
        }
    }

    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct AIStreamEvent {
    let content: String?
    let finishReason: String?
}
