import Foundation

protocol AIProviderAdapter {
    var providerType: AIProviderType { get }
    func buildRequest(config: ProviderConfig, chatRequest: AIChatRequest, apiKey: String) throws -> URLRequest
    func parseResponse(data: Data) throws -> AIChatResponse
    func parseStreamEvent(data: Data) -> AIStreamEvent?
}

struct OpenAIAdapter: AIProviderAdapter {
    let providerType: AIProviderType = .openAI

    func buildRequest(config: ProviderConfig, chatRequest: AIChatRequest, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw AIProviderError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(chatRequest)
        request.httpBody = body
        request.timeoutInterval = 120
        return request
    }

    func parseResponse(data: Data) throws -> AIChatResponse {
        try JSONDecoder().decode(AIChatResponse.self, from: data)
    }

    func parseStreamEvent(data: Data) -> AIStreamEvent? {
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        let lines = jsonString.components(separatedBy: "\n")
        for line in lines where line.hasPrefix("data: ") {
            let json = String(line.dropFirst(6))
            if json.trimmingCharacters(in: .whitespaces) == "[DONE]" { return nil }
            guard let jsonData = json.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(AIChatResponse.self, from: jsonData),
                  let choice = chunk.choices.first else { continue }
            return AIStreamEvent(content: choice.delta?.content, finishReason: choice.finishReason)
        }
        return nil
    }
}

struct AnthropicAdapter: AIProviderAdapter {
    let providerType: AIProviderType = .anthropic

    func buildRequest(config: ProviderConfig, chatRequest: AIChatRequest, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(config.baseURL)/v1/messages") else {
            throw AIProviderError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": chatRequest.model,
            "max_tokens": chatRequest.maxTokens ?? 4096,
            "stream": chatRequest.stream,
        ]

        var messages: [[String: String]] = []
        var systemPrompt: String?
        for msg in chatRequest.messages {
            if msg.role == .system {
                systemPrompt = msg.content
            } else {
                messages.append(["role": msg.role.rawValue, "content": msg.content])
            }
        }

        if let system = systemPrompt {
            body["system"] = system
        }
        body["messages"] = messages

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120
        return request
    }

    func parseResponse(data: Data) throws -> AIChatResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let content = (json["content"] as? [[String: Any]]) ?? []
        let text = content.compactMap { $0["text"] as? String }.joined()
        let usage = json["usage"] as? [String: Any]

        return AIChatResponse(
            id: json["id"] as? String,
            choices: [AIChatResponse.Choice(
                index: 0,
                message: AIMessage(role: .assistant, content: text),
                delta: nil,
                finishReason: json["stop_reason"] as? String
            )],
            usage: usage != nil ? AIChatResponse.Usage(
                promptTokens: usage?["input_tokens"] as? Int,
                completionTokens: usage?["output_tokens"] as? Int,
                totalTokens: ((usage?["input_tokens"] as? Int) ?? 0) + ((usage?["output_tokens"] as? Int) ?? 0)
            ) : nil
        )
    }

    func parseStreamEvent(data: Data) -> AIStreamEvent? {
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        let lines = jsonString.components(separatedBy: "\n")
        for line in lines where line.hasPrefix("data: ") {
            let json = String(line.dropFirst(6))
            guard let jsonData = json.data(using: .utf8),
                  let chunk = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }
            let type = chunk["type"] as? String ?? ""
            if type == "content_block_delta" {
                let delta = chunk["delta"] as? [String: Any]
                let text = delta?["text"] as? String
                return AIStreamEvent(content: text, finishReason: nil)
            }
            if type == "message_stop" {
                return AIStreamEvent(content: nil, finishReason: "stop")
            }
        }
        return nil
    }
}

struct GoogleGeminiAdapter: AIProviderAdapter {
    let providerType: AIProviderType = .googleGemini

    func buildRequest(config: ProviderConfig, chatRequest: AIChatRequest, apiKey: String) throws -> URLRequest {
        let endpoint = chatRequest.stream ? "streamGenerateContent" : "generateContent"
        let urlString = "\(config.baseURL)/models/\(chatRequest.model):\(endpoint)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIProviderError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []
        for msg in chatRequest.messages where msg.role != .system {
            contents.append([
                "role": msg.role == .assistant ? "model" : "user",
                "parts": [["text": msg.content]],
            ])
        }

        var body: [String: Any] = ["contents": contents]
        let systemMsgs = chatRequest.messages.filter { $0.role == .system }
        if !systemMsgs.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemMsgs.map(\.content).joined(separator: "\n")]]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120
        return request
    }

    func parseResponse(data: Data) throws -> AIChatResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let candidates = json["candidates"] as? [[String: Any]] ?? []
        let text = candidates.first?["content"] as? [String: Any]
        let parts = text?["parts"] as? [[String: Any]] ?? []
        let content = parts.compactMap { $0["text"] as? String }.joined()

        return AIChatResponse(
            id: nil,
            choices: [AIChatResponse.Choice(
                index: 0,
                message: AIMessage(role: .assistant, content: content),
                delta: nil,
                finishReason: "stop"
            )],
            usage: nil
        )
    }

    func parseStreamEvent(data: Data) -> AIStreamEvent? {
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        guard let jsonData = jsonString.data(using: .utf8),
              let chunk = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
        let candidates = chunk["candidates"] as? [[String: Any]] ?? []
        let content = candidates.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]] ?? []
        let text = parts.compactMap { $0["text"] as? String }.joined()
        return AIStreamEvent(content: text.isEmpty ? nil : text, finishReason: nil)
    }
}

struct OpenRouterAdapter: AIProviderAdapter {
    let providerType: AIProviderType = .openRouter

    func buildRequest(config: ProviderConfig, chatRequest: AIChatRequest, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw AIProviderError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://codeforge.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("CodeForge", forHTTPHeaderField: "X-Title")
        let body = try JSONEncoder().encode(chatRequest)
        request.httpBody = body
        request.timeoutInterval = 120
        return request
    }

    func parseResponse(data: Data) throws -> AIChatResponse {
        try JSONDecoder().decode(AIChatResponse.self, from: data)
    }

    func parseStreamEvent(data: Data) -> AIStreamEvent? {
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        let lines = jsonString.components(separatedBy: "\n")
        for line in lines where line.hasPrefix("data: ") {
            let json = String(line.dropFirst(6))
            if json.trimmingCharacters(in: .whitespaces) == "[DONE]" { return nil }
            guard let jsonData = json.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(AIChatResponse.self, from: jsonData),
                  let choice = chunk.choices.first else { continue }
            return AIStreamEvent(content: choice.delta?.content, finishReason: choice.finishReason)
        }
        return nil
    }
}

struct CustomOpenAIAdapter: AIProviderAdapter {
    let providerType: AIProviderType = .custom

    func buildRequest(config: ProviderConfig, chatRequest: AIChatRequest, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw AIProviderError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(chatRequest)
        request.httpBody = body
        request.timeoutInterval = 120
        return request
    }

    func parseResponse(data: Data) throws -> AIChatResponse {
        try JSONDecoder().decode(AIChatResponse.self, from: data)
    }

    func parseStreamEvent(data: Data) -> AIStreamEvent? {
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        let lines = jsonString.components(separatedBy: "\n")
        for line in lines where line.hasPrefix("data: ") {
            let json = String(line.dropFirst(6))
            if json.trimmingCharacters(in: .whitespaces) == "[DONE]" { return nil }
            guard let jsonData = json.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(AIChatResponse.self, from: jsonData),
                  let choice = chunk.choices.first else { continue }
            return AIStreamEvent(content: choice.delta?.content, finishReason: choice.finishReason)
        }
        return nil
    }
}

struct AIProviderAdapterFactory {
    static func adapter(for type: AIProviderType) -> AIProviderAdapter {
        switch type {
        case .openAI: return OpenAIAdapter()
        case .anthropic: return AnthropicAdapter()
        case .googleGemini: return GoogleGeminiAdapter()
        case .openRouter: return OpenRouterAdapter()
        case .custom: return CustomOpenAIAdapter()
        }
    }
}
