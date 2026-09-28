import XCTest
@testable import Pip

final class AppRegistryTests: XCTestCase {

    // MARK: - decode

    func testDecodeDropsInvalidEntries() {
        let json = """
        [
          { "id": "good-one", "name": "Good", "webURL": "https://example.com", "kind": "web" },
          { "id": "Bad_ID!", "name": "Bad", "webURL": "https://example.com", "kind": "web" }
        ]
        """
        let result = AppRegistry.decode(Data(json.utf8), source: .bundled)
        XCTAssertEqual(result.map(\.id), ["good-one"])
    }

    func testDecodeDropsDuplicateIds() {
        let json = """
        [
          { "id": "dup", "name": "First", "webURL": "https://example.com", "kind": "web" },
          { "id": "dup", "name": "Second", "webURL": "https://example.org", "kind": "web" }
        ]
        """
        let result = AppRegistry.decode(Data(json.utf8), source: .bundled)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "First")
    }

    func testDecodeEnforcesMaxEntries() {
        let entries = (0..<(AppRegistry.maxEntries + 50)).map { i in
            "{ \"id\": \"app-\(i)\", \"name\": \"App \(i)\", \"webURL\": \"https://example.com\", \"kind\": \"web\" }"
        }
        let json = "[" + entries.joined(separator: ",") + "]"
        let result = AppRegistry.decode(Data(json.utf8), source: .bundled)
        XCTAssertEqual(result.count, AppRegistry.maxEntries)
    }

    func testDecodeEnforcesMaxFileBytes() {
        // Oversized blob (the size gate rejects it before any JSON parsing is attempted).
        let padding = String(repeating: "x", count: AppRegistry.maxFileBytes + 1024)
        let oversized = "[{\"pad\":\"\(padding)\"}]"
        let result = AppRegistry.decode(Data(oversized.utf8), source: .bundled)
        XCTAssertEqual(result, [])
    }

    func testDecodeReturnsEmptyForMalformedJSON() {
        let result = AppRegistry.decode(Data("not valid json".utf8), source: .bundled)
        XCTAssertEqual(result, [])
    }

    // MARK: - merge

    func testMergeCustomCannotReplaceCatalogId() {
        let catalogEntry = AITarget(id: "claude", name: "Claude", webURL: URL(string: "https://claude.ai")!, kind: .web)
        let spoofedCustomEntry = AITarget(id: "claude", name: "Not Claude", webURL: URL(string: "https://evil.example")!, kind: .web)
        let merged = AppRegistry.merge(catalog: [catalogEntry], custom: [spoofedCustomEntry])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.name, "Claude")
    }

    func testMergeAppendsNewCustomIds() {
        let catalogEntry = AITarget(id: "claude", name: "Claude", webURL: URL(string: "https://claude.ai")!, kind: .web)
        let customEntry = AITarget(id: "my-tool", name: "My Tool", webURL: URL(string: "https://example.com")!, kind: .web)
        let merged = AppRegistry.merge(catalog: [catalogEntry], custom: [customEntry])
        XCTAssertEqual(merged.map(\.id), ["claude", "my-tool"])
    }

    func testMergeRejectsCustomEntryReusingCatalogNameOrAlias() {
        let catalogEntry = AITarget(id: "chatgpt", name: "ChatGPT", aliases: ["gpt"],
                                    webURL: URL(string: "https://chatgpt.com")!, kind: .web)
        let sameName = AITarget(id: "my-chat", name: "chat gpt", webURL: URL(string: "https://evil.example")!, kind: .web)
        let fullWidth = AITarget(id: "my-chat2", name: "ＣｈａｔＧＰＴ", webURL: URL(string: "https://evil.example")!, kind: .web)
        let sameAlias = AITarget(id: "my-chat3", name: "Totally Different", aliases: ["GPT"],
                                 webURL: URL(string: "https://evil.example")!, kind: .web)
        let merged = AppRegistry.merge(catalog: [catalogEntry], custom: [sameName, fullWidth, sameAlias])
        XCTAssertEqual(merged.map(\.id), ["chatgpt"])
    }

    func testDecodeKeepsGoodEntriesWhenOneEntryIsMalformed() {
        let json = """
        [
          { "id": "good-one", "name": "Good", "webURL": "https://example.com", "kind": "web" },
          { "id": "broken", "name": 42 },
          { "id": "good-two", "name": "Also Good", "webURL": "https://example.org", "kind": "web" }
        ]
        """
        let result = AppRegistry.decode(Data(json.utf8), source: .user)
        XCTAssertEqual(result.map(\.id), ["good-one", "good-two"])
    }

    // MARK: - readUserFile

    private func makeTempFile(name: String = UUID().uuidString, contents: Data = Data("[]".utf8), permissions: Int16 = 0o600) -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: contents,
                                        attributes: [.posixPermissions: permissions])
        return url
    }

    func testReadUserFileAcceptsRegularFileWithSafePermissions() {
        let contents = Data("[]".utf8)
        let url = makeTempFile(contents: contents, permissions: 0o600)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(AppRegistry.readUserFile(at: url), contents)
    }

    func testReadUserFileRejectsSymlink() {
        let target = makeTempFile(permissions: 0o600)
        defer { try? FileManager.default.removeItem(at: target) }

        let linkURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: target)
        defer { try? FileManager.default.removeItem(at: linkURL) }

        XCTAssertNil(AppRegistry.readUserFile(at: linkURL))
    }

    func testReadUserFileRejectsGroupOrWorldWritableFile() {
        let url = makeTempFile(permissions: 0o666)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(AppRegistry.readUserFile(at: url))
    }

    func testReadUserFileRejectsTooLargeFile() {
        let contents = Data(repeating: 0x41, count: AppRegistry.maxFileBytes + 1)
        let url = makeTempFile(contents: contents, permissions: 0o600)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(AppRegistry.readUserFile(at: url))
    }

    func testReadUserFileRejectsMissingFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertNil(AppRegistry.readUserFile(at: url))
    }

    // MARK: - bundled catalog

    func testBundledCatalogEntriesAreAllValid() throws {
        // Tests run hosted in Pip.app, so Bundle.main is the app bundle (Bundle(for:) would be PipTests).
        let url = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = AppRegistry.decode(data, source: .bundled)
        XCTAssertEqual(decoded.count, 10)
    }

    func testBundledCatalogHasExactlyOneCLIEntry() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = AppRegistry.decode(data, source: .bundled)
        XCTAssertEqual(decoded.filter { $0.kind == .cli }.count, 1)
    }
}
