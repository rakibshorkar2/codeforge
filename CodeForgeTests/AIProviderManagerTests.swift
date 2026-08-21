import XCTest
@testable import CodeForge

@MainActor
final class AIProviderManagerTests: XCTestCase {
    var manager: AIProviderManager!
    var mockKeychain: MockKeychainService!
    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
        defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        manager = AIProviderManager(keychain: mockKeychain, defaults: defaults)
    }

    func testInitialState() {
        XCTAssertTrue(manager.providers.isEmpty)
        XCTAssertNil(manager.activeProvider)
        XCTAssertNil(manager.activeModel)
    }

    func testAddProvider() {
        let config = ProviderConfig(name: "Test", type: .openAI)
        manager.addProvider(config)
        XCTAssertEqual(manager.providers.count, 1)
    }

    func testAddMultipleProviders() {
        manager.addProvider(ProviderConfig(name: "OpenAI", type: .openAI))
        manager.addProvider(ProviderConfig(name: "Anthropic", type: .anthropic))
        XCTAssertEqual(manager.providers.count, 2)
    }

    func testRemoveProvider() {
        let config = ProviderConfig(name: "To Remove", type: .openAI)
        manager.addProvider(config)
        manager.removeProvider(id: config.id)
        XCTAssertTrue(manager.providers.isEmpty)
    }

    func testSetActiveProvider() {
        let c1 = ProviderConfig(name: "A", type: .openAI)
        let c2 = ProviderConfig(name: "B", type: .anthropic)
        manager.addProvider(c1)
        manager.addProvider(c2)
        manager.setActiveProvider(id: c2.id)
        XCTAssertEqual(manager.activeProviderID, c2.id)
    }

    func testSetSelectedModel() {
        let config = ProviderConfig(name: "OpenAI", type: .openAI)
        manager.addProvider(config)
        manager.setSelectedModel(providerID: config.id, modelID: "gpt-4o-mini")
        XCTAssertEqual(manager.activeModel?.id, "gpt-4o-mini")
    }

    func testSaveAndLoadAPIKey() throws {
        let config = ProviderConfig(name: "Test", type: .openAI)
        manager.addProvider(config)
        try manager.saveAPIKey(providerID: config.id, key: "sk-test123")
        let key = try manager.loadAPIKey(providerID: config.id)
        XCTAssertEqual(key, "sk-test123")
    }

    func testHasAPIKey() throws {
        let config = ProviderConfig(name: "Test", type: .openAI)
        manager.addProvider(config)
        XCTAssertFalse(manager.hasAPIKey(providerID: config.id))
        try manager.saveAPIKey(providerID: config.id, key: "sk-test")
        XCTAssertTrue(manager.hasAPIKey(providerID: config.id))
    }

    func testDeleteAPIKey() throws {
        let config = ProviderConfig(name: "Test", type: .openAI)
        manager.addProvider(config)
        try manager.saveAPIKey(providerID: config.id, key: "sk-test")
        try manager.deleteAPIKey(providerID: config.id)
        XCTAssertFalse(manager.hasAPIKey(providerID: config.id))
    }

    func testPersistence() {
        let config = ProviderConfig(name: "Persisted", type: .openAI)
        manager.addProvider(config)
        let newManager = AIProviderManager(keychain: mockKeychain, defaults: defaults)
        XCTAssertEqual(newManager.providers.count, 1)
        XCTAssertEqual(newManager.providers.first?.name, "Persisted")
    }

    func testActiveProviderFallsBackToFirst() {
        manager.addProvider(ProviderConfig(name: "First", type: .openAI))
        manager.addProvider(ProviderConfig(name: "Second", type: .anthropic))
        manager.activeProviderID = nil
        XCTAssertEqual(manager.activeProvider?.name, "First")
    }
}
