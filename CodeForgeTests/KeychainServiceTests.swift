import XCTest
@testable import CodeForge

final class KeychainServiceTests: XCTestCase {
    var keychain: KeychainService!

    override func setUp() {
        super.setUp()
        keychain = KeychainService()
    }

    override func tearDown() {
        try? keychain.delete(key: "test_key")
        try? keychain.delete(key: "test_string")
        super.tearDown()
    }

    func testSaveAndLoadString() throws {
        try keychain.save(key: "test_string", string: "hello world")
        let loaded = try keychain.loadString(key: "test_string")
        XCTAssertEqual(loaded, "hello world")
    }

    func testSaveAndLoadData() throws {
        let data = "test data".data(using: .utf8)!
        try keychain.save(key: "test_key", data: data)
        let loaded = try keychain.load(key: "test_key")
        XCTAssertEqual(loaded, data)
    }

    func testOverwriteExistingKey() throws {
        try keychain.save(key: "test_string", string: "first")
        try keychain.save(key: "test_string", string: "second")
        let loaded = try keychain.loadString(key: "test_string")
        XCTAssertEqual(loaded, "second")
    }

    func testDeleteKey() throws {
        try keychain.save(key: "test_string", string: "to delete")
        XCTAssertTrue(keychain.exists(key: "test_string"))
        try keychain.delete(key: "test_string")
        XCTAssertFalse(keychain.exists(key: "test_string"))
    }

    func testDeleteNonexistentKey() throws {
        try keychain.delete(key: "nonexistent_key_\(UUID().uuidString)")
    }

    func testExistsReturnsFalseForMissing() {
        XCTAssertFalse(keychain.exists(key: "nonexistent_\(UUID().uuidString)"))
    }

    func testExistsReturnsTrueForPresent() throws {
        try keychain.save(key: "test_string", string: "exists")
        XCTAssertTrue(keychain.exists(key: "test_string"))
    }

    func testLoadStringThrowsForMissing() {
        XCTAssertThrowsError(try keychain.loadString(key: "missing_\(UUID().uuidString)")) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }

    func testLoadThrowsForMissing() {
        XCTAssertThrowsError(try keychain.load(key: "missing_\(UUID().uuidString)")) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
}

final class MockKeychainService: KeychainServiceProtocol {
    var storage: [String: Data] = [:]
    var saveShouldFail = false
    var loadShouldFail = false

    func save(key: String, data: Data) throws {
        if saveShouldFail { throw KeychainError.unexpectedStatus(errSecParam) }
        storage[key] = data
    }

    func save(key: String, string: String) throws {
        if saveShouldFail { throw KeychainError.unexpectedStatus(errSecParam) }
        storage[key] = string.data(using: .utf8)
    }

    func load(key: String) throws -> Data {
        if loadShouldFail { throw KeychainError.itemNotFound }
        guard let data = storage[key] else { throw KeychainError.itemNotFound }
        return data
    }

    func loadString(key: String) throws -> String {
        let data = try load(key: key)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func delete(key: String) throws {
        storage.removeValue(forKey: key)
    }

    func exists(key: String) -> Bool {
        storage[key] != nil
    }
}
