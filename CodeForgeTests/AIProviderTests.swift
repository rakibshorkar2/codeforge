import XCTest
@testable import CodeForge

final class AIProviderTests: XCTestCase {
    func testAIProviderTypeDisplayNames() {
        XCTAssertEqual(AIProviderType.openAI.displayName, "OpenAI")
        XCTAssertEqual(AIProviderType.anthropic.displayName, "Anthropic")
        XCTAssertEqual(AIProviderType.googleGemini.displayName, "Google Gemini")
        XCTAssertEqual(AIProviderType.openRouter.displayName, "OpenRouter")
        XCTAssertEqual(AIProviderType.custom.displayName, "Custom Endpoint")
    }

    func testAIProviderTypeIcons() {
        XCTAssertEqual(AIProviderType.openAI.icon, "brain.head.profile")
        XCTAssertEqual(AIProviderType.anthropic.icon, "a.circle")
        XCTAssertEqual(AIProviderType.googleGemini.icon, "sparkle")
        XCTAssertEqual(AIProviderType.openRouter.icon, "arrow.triangle.branch")
        XCTAssertEqual(AIProviderType.custom.icon, "gearshape")
    }

    func testAIProviderTypeDefaultURLs() {
        XCTAssertEqual(AIProviderType.openAI.defaultBaseURL, "https://api.openai.com/v1")
        XCTAssertEqual(AIProviderType.anthropic.defaultBaseURL, "https://api.anthropic.com")
        XCTAssertEqual(AIProviderType.openRouter.defaultBaseURL, "https://openrouter.ai/api/v1")
        XCTAssertFalse(AIProviderType.custom.defaultBaseURL.isEmpty)
    }

    func testAIProviderTypeDefaultModels() {
        XCTAssertFalse(AIProviderType.openAI.defaultModels.isEmpty)
        XCTAssertFalse(AIProviderType.anthropic.defaultModels.isEmpty)
        XCTAssertFalse(AIProviderType.googleGemini.defaultModels.isEmpty)
        XCTAssertFalse(AIProviderType.openRouter.defaultModels.isEmpty)
        XCTAssertTrue(AIProviderType.custom.defaultModels.isEmpty)
    }

    func testAIProviderTypeAllCases() {
        XCTAssertEqual(AIProviderType.allCases.count, 5)
    }

    func testAIModelInitialization() {
        let model = AIModel(id: "gpt-4o", providerID: "openai", displayName: "GPT-4o", contextWindow: 128000, supportsStreaming: true, supportsFunctionCalling: true)
        XCTAssertEqual(model.id, "gpt-4o")
        XCTAssertEqual(model.providerID, "openai")
        XCTAssertEqual(model.displayName, "GPT-4o")
        XCTAssertEqual(model.contextWindow, 128000)
        XCTAssertTrue(model.supportsStreaming)
        XCTAssertTrue(model.supportsFunctionCalling)
    }

    func testAIModelDefaults() {
        let model = AIModel(id: "test", providerID: "test", displayName: "Test")
        XCTAssertNil(model.contextWindow)
        XCTAssertTrue(model.supportsStreaming)
        XCTAssertFalse(model.supportsFunctionCalling)
    }

    func testAIModelEquatable() {
        let m1 = AIModel(id: "gpt-4o", providerID: "openai", displayName: "GPT-4o")
        let m2 = AIModel(id: "gpt-4o", providerID: "openai", displayName: "GPT-4o")
        let m3 = AIModel(id: "gpt-4o-mini", providerID: "openai", displayName: "GPT-4o Mini")
        XCTAssertEqual(m1, m2)
        XCTAssertNotEqual(m1, m3)
    }

    func testProviderConfigInitialization() {
        let config = ProviderConfig(name: "My OpenAI", type: .openAI)
        XCTAssertFalse(config.id.uuidString.isEmpty)
        XCTAssertEqual(config.name, "My OpenAI")
        XCTAssertEqual(config.type, .openAI)
        XCTAssertEqual(config.baseURL, "https://api.openai.com/v1")
        XCTAssertTrue(config.isEnabled)
        XCTAssertNil(config.selectedModelID)
        XCTAssertTrue(config.customModels.isEmpty)
    }

    func testProviderConfigCustomBaseURL() {
        let config = ProviderConfig(name: "Custom", type: .custom, baseURL: "https://my-api.com/v1")
        XCTAssertEqual(config.baseURL, "https://my-api.com/v1")
    }

    func testProviderConfigAvailableModels() {
        let openAIConfig = ProviderConfig(name: "OpenAI", type: .openAI)
        XCTAssertEqual(openAIConfig.availableModels.count, AIProviderType.openAI.defaultModels.count)

        let customConfig = ProviderConfig(name: "Custom", type: .custom, customModels: [
            AIModel(id: "custom-1", providerID: "custom", displayName: "Custom Model 1")
        ])
        XCTAssertEqual(customConfig.availableModels.count, 1)
        XCTAssertEqual(customConfig.availableModels.first?.id, "custom-1")
    }

    func testProviderConfigSelectedModel() {
        var config = ProviderConfig(name: "OpenAI", type: .openAI)
        config.selectedModelID = "gpt-4o"
        XCTAssertEqual(config.selectedModel?.id, "gpt-4o")

        config.selectedModelID = "nonexistent"
        XCTAssertNil(config.selectedModel)
    }

    func testProviderConfigSelectedModelDefault() {
        let config = ProviderConfig(name: "OpenAI", type: .openAI)
        XCTAssertEqual(config.selectedModel?.id, "gpt-4o")
    }

    func testProviderConfigEquatable() {
        let id = UUID()
        let c1 = ProviderConfig(id: id, name: "Test", type: .openAI)
        let c2 = ProviderConfig(id: id, name: "Test 2", type: .anthropic)
        let c3 = ProviderConfig(name: "Other", type: .openAI)
        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
    }

    func testAIMessageInitialization() {
        let msg = AIMessage(role: .user, content: "Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
    }

    func testAIMessageRoles() {
        XCTAssertEqual(AIMessage.MessageRole.system.rawValue, "system")
        XCTAssertEqual(AIMessage.MessageRole.user.rawValue, "user")
        XCTAssertEqual(AIMessage.MessageRole.assistant.rawValue, "assistant")
    }

    func testAIChatRequestInitialization() {
        let messages = [AIMessage(role: .user, content: "Hi")]
        let req = AIChatRequest(model: "gpt-4o", messages: messages)
        XCTAssertEqual(req.model, "gpt-4o")
        XCTAssertEqual(req.messages.count, 1)
        XCTAssertTrue(req.stream)
        XCTAssertNil(req.temperature)
        XCTAssertNil(req.maxTokens)
    }

    func testAIChatRequestCodable() throws {
        let req = AIChatRequest(model: "gpt-4o", messages: [AIMessage(role: .user, content: "Hi")], stream: false, temperature: 0.7, maxTokens: 100)
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(AIChatRequest.self, from: data)
        XCTAssertEqual(decoded.model, "gpt-4o")
        XCTAssertFalse(decoded.stream)
        XCTAssertEqual(decoded.temperature, 0.7)
        XCTAssertEqual(decoded.maxTokens, 100)
    }

    func testAIChatResponseCodable() throws {
        let response = AIChatResponse(
            id: "chatcmpl-123",
            choices: [AIChatResponse.Choice(
                index: 0,
                message: AIMessage(role: .assistant, content: "Hello!"),
                delta: nil,
                finishReason: "stop"
            )],
            usage: AIChatResponse.Usage(promptTokens: 10, completionTokens: 20, totalTokens: 30)
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
        XCTAssertEqual(decoded.id, "chatcmpl-123")
        XCTAssertEqual(decoded.choices.first?.message?.content, "Hello!")
        XCTAssertEqual(decoded.usage?.totalTokens, 30)
    }

    func testAIStreamEventInitialization() {
        let event = AIStreamEvent(content: "Hello", finishReason: nil)
        XCTAssertEqual(event.content, "Hello")
        XCTAssertNil(event.finishReason)
    }

    func testOpenAIModelsHaveExpectedCount() {
        let models = AIProviderType.openAI.defaultModels
        XCTAssertTrue(models.count >= 3)
        XCTAssertTrue(models.contains { $0.id == "gpt-4o" })
        XCTAssertTrue(models.contains { $0.id == "gpt-4o-mini" })
    }

    func testAnthropicModelsHaveExpectedCount() {
        let models = AIProviderType.anthropic.defaultModels
        XCTAssertTrue(models.count >= 2)
        XCTAssertTrue(models.contains { $0.id == "claude-sonnet-4-20250514" })
    }

    func testGeminiModelsHaveExpectedCount() {
        let models = AIProviderType.googleGemini.defaultModels
        XCTAssertTrue(models.count >= 2)
        XCTAssertTrue(models.contains { $0.id == "gemini-2.0-flash" })
    }

    func testOpenRouterModelsHaveExpectedCount() {
        let models = AIProviderType.openRouter.defaultModels
        XCTAssertTrue(models.count >= 2)
    }
}
