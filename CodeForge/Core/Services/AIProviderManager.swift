import Foundation

protocol AIProviderManagerProtocol {
    var providers: [ProviderConfig] { get }
    var activeProvider: ProviderConfig? { get }
    var activeModel: AIModel? { get }
    func addProvider(_ config: ProviderConfig)
    func updateProvider(_ config: ProviderConfig)
    func removeProvider(id: UUID)
    func setActiveProvider(id: UUID)
    func setSelectedModel(providerID: UUID, modelID: String)
    func saveAPIKey(providerID: UUID, key: String) throws
    func loadAPIKey(providerID: UUID) throws -> String
    func deleteAPIKey(providerID: UUID) throws
    func hasAPIKey(providerID: UUID) -> Bool
    func loadPersistedProviders()
}

final class AIProviderManager: AIProviderManagerProtocol, ObservableObject {
    @Published private(set) var providers: [ProviderConfig] = []
    @Published private(set) var activeProviderID: UUID?

    private let keychain: KeychainServiceProtocol
    private let storageKey = "ai_providers"
    private let activeProviderKey = "active_provider_id"
    private let defaults: UserDefaults

    var activeProvider: ProviderConfig? {
        guard let id = activeProviderID else { return providers.first }
        return providers.first { $0.id == id } ?? providers.first
    }

    var activeModel: AIModel? {
        activeProvider?.selectedModel
    }

    init(keychain: KeychainServiceProtocol = KeychainService(), defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
        loadPersistedProviders()
    }

    func loadPersistedProviders() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ProviderConfig].self, from: data) {
            providers = decoded
        }

        if let idString = defaults.string(forKey: activeProviderKey),
           let id = UUID(uuidString: idString) {
            activeProviderID = id
        }
    }

    func addProvider(_ config: ProviderConfig) {
        providers.append(config)
        persist()
        if providers.count == 1 {
            setActiveProvider(id: config.id)
        }
    }

    func updateProvider(_ config: ProviderConfig) {
        if let index = providers.firstIndex(where: { $0.id == config.id }) {
            providers[index] = config
            persist()
        }
    }

    func removeProvider(id: UUID) {
        providers.removeAll { $0.id == id }
        try? deleteAPIKey(providerID: id)
        persist()
        if activeProviderID == id {
            activeProviderID = providers.first?.id
            persistActiveProvider()
        }
    }

    func setActiveProvider(id: UUID) {
        guard providers.contains(where: { $0.id == id }) else { return }
        activeProviderID = id
        persistActiveProvider()
    }

    func setSelectedModel(providerID: UUID, modelID: String) {
        guard let index = providers.firstIndex(where: { $0.id == providerID }) else { return }
        providers[index].selectedModelID = modelID
        persist()
    }

    func saveAPIKey(providerID: UUID, key: String) throws {
        let keychainKey = "ai_api_key_\(providerID.uuidString)"
        try keychain.save(key: keychainKey, string: key)
    }

    func loadAPIKey(providerID: UUID) throws -> String {
        let keychainKey = "ai_api_key_\(providerID.uuidString)"
        return try keychain.loadString(key: keychainKey)
    }

    func deleteAPIKey(providerID: UUID) throws {
        let keychainKey = "ai_api_key_\(providerID.uuidString)"
        try keychain.delete(key: keychainKey)
    }

    func hasAPIKey(providerID: UUID) -> Bool {
        let keychainKey = "ai_api_key_\(providerID.uuidString)"
        return keychain.exists(key: keychainKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(providers) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func persistActiveProvider() {
        defaults.set(activeProviderID?.uuidString, forKey: activeProviderKey)
    }
}
