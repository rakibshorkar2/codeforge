import Foundation

enum AIRequestError: Error, LocalizedError {
    case noActiveProvider
    case noActiveModel
    case missingAPIKey
    case requestFailed(String)
    case decodingFailed(String)
    case rateLimited
    case authenticationFailed
    case serverError(Int)
    case timeout
    case cancelled
    case streamingError(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProvider: return "No AI provider configured"
        case .noActiveModel: return "No model selected"
        case .missingAPIKey: return "API key not configured for active provider"
        case .requestFailed(let msg): return "Request failed: \(msg)"
        case .decodingFailed(let msg): return "Failed to decode response: \(msg)"
        case .rateLimited: return "Rate limited. Please try again later."
        case .authenticationFailed: return "Authentication failed. Check your API key."
        case .serverError(let code): return "Server error (\(code))"
        case .timeout: return "Request timed out"
        case .cancelled: return "Request was cancelled"
        case .streamingError(let msg): return "Streaming error: \(msg)"
        }
    }
}

final class AIRequestService: ObservableObject {
    @Published private(set) var isStreaming = false

    private let providerManager: AIProviderManagerProtocol
    private let session: URLSession
    private var currentTask: Task<Void, Never>?
    private var currentStreamTask: URLSessionDataTask?

    init(providerManager: AIProviderManagerProtocol, session: URLSession = .shared) {
        self.providerManager = providerManager
        self.session = session
    }

    func sendMessage(
        _ messages: [AIMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> AIChatResponse {
        guard let provider = providerManager.activeProvider else {
            throw AIRequestError.noActiveProvider
        }

        guard provider.isEnabled else {
            throw AIRequestError.requestFailed("Provider \"\(provider.name)\" is disabled")
        }

        guard let model = provider.selectedModel else {
            throw AIRequestError.noActiveModel
        }

        let apiKey: String
        do {
            apiKey = try providerManager.loadAPIKey(providerID: provider.id)
        } catch {
            throw AIRequestError.missingAPIKey
        }

        let adapter = AIProviderAdapterFactory.adapter(for: provider.type)
        let chatRequest = AIChatRequest(
            model: model.id,
            messages: messages,
            stream: false,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let request = try adapter.buildRequest(config: provider, chatRequest: chatRequest, apiKey: apiKey)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIRequestError.requestFailed("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AIRequestError.authenticationFailed
        case 429:
            throw AIRequestError.rateLimited
        default:
            if httpResponse.statusCode >= 500 {
                throw AIRequestError.serverError(httpResponse.statusCode)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIRequestError.requestFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        do {
            return try adapter.parseResponse(data: data)
        } catch {
            throw AIRequestError.decodingFailed(error.localizedDescription)
        }
    }

    func streamMessage(
        _ messages: [AIMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard let provider = providerManager.activeProvider else {
            onError(AIRequestError.noActiveProvider)
            return
        }

        guard provider.isEnabled else {
            onError(AIRequestError.requestFailed("Provider \"\(provider.name)\" is disabled"))
            return
        }

        guard let model = provider.selectedModel else {
            onError(AIRequestError.noActiveModel)
            return
        }

        let apiKey: String
        do {
            apiKey = try providerManager.loadAPIKey(providerID: provider.id)
        } catch {
            onError(AIRequestError.missingAPIKey)
            return
        }

        cancelCurrentStream()
        isStreaming = true

        let adapter = AIProviderAdapterFactory.adapter(for: provider.type)
        let chatRequest = AIChatRequest(
            model: model.id,
            messages: messages,
            stream: true,
            temperature: temperature,
            maxTokens: maxTokens
        )

        do {
            let request = try adapter.buildRequest(config: provider, chatRequest: chatRequest, apiKey: apiKey)

            let task = session.dataTask(with: request) { [weak self] data, response, error in
                defer { Task { @MainActor in self?.isStreaming = false } }

                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled { return }
                    onError(error)
                    return
                }

                guard let data = data else {
                    onError(AIRequestError.streamingError("No data received"))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200: break
                    case 401:
                        onError(AIRequestError.authenticationFailed)
                        return
                    case 429:
                        onError(AIRequestError.rateLimited)
                        return
                    default:
                        if httpResponse.statusCode >= 500 {
                            onError(AIRequestError.serverError(httpResponse.statusCode))
                            return
                        }
                    }
                }

                var fullResponse = ""
                let lines = data.components(separatedBy: "\n")
                for line in lines where line.hasPrefix("data: ") {
                    let json = String(line.dropFirst(6))
                    if json.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }
                    guard let jsonData = json.data(using: .utf8),
                          let event = adapter.parseStreamEvent(data: jsonData) else { continue }
                    if let content = event.content {
                        fullResponse += content
                        Task { @MainActor in onToken(content) }
                    }
                    if event.finishReason != nil { break }
                }

                Task { @MainActor in onComplete(fullResponse) }
            }

            currentStreamTask = task
            task.resume()
        } catch {
            isStreaming = false
            onError(error)
        }
    }

    func cancelCurrentStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
    }
}
