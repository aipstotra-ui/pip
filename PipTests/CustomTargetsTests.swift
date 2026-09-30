import XCTest
@testable import Pip

final class CustomTargetsTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pip-custom-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp)
        super.tearDown()
    }

    /// Tests run hosted in Pip.app, so Bundle.main has the real catalog.
    private var bundled: AppRegistry { AppRegistry.load(customURL: nil) }

    private func site(_ id: String, name: String? = nil) -> AITarget {
        AITarget(id: id, name: name ?? id, webURL: URL(string: "https://example.com")!, kind: .web)
    }

    private func assertThrows(_ expected: CustomTargets.AddError, file: StaticString = #filePath, line: UInt = #line,
                              _ body: () throws -> Void) {
        do {
            try body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as CustomTargets.AddError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    // MARK: makeWebsite

    func testMakeWebsiteAddsHTTPSWhenSchemeMissing() throws {
        let t = try CustomTargets.makeWebsite(name: "Example", address: "example.com", existing: bundled)
        XCTAssertEqual(t.webURL, URL(string: "https://example.com"))
        XCTAssertEqual(t.kind, .web)
        XCTAssertEqual(t.id, "custom-example")
        XCTAssertTrue(TargetValidator.isValid(t, source: .user))
    }

    func testMakeWebsiteTrimsWhitespace() throws {
        let t = try CustomTargets.makeWebsite(name: "  Example  ", address: "  https://example.com/x  ", existing: bundled)
        XCTAssertEqual(t.name, "Example")
        XCTAssertEqual(t.webURL, URL(string: "https://example.com/x"))
    }

    func testMakeWebsiteKeepsExplicitHTTPS() throws {
        let t = try CustomTargets.makeWebsite(name: "Ex", address: "https://example.com", existing: bundled)
        XCTAssertEqual(t.webURL?.scheme, "https")
    }

    func testMakeWebsiteRejectsHTTP() {
        assertThrows(.invalidURL) {
            _ = try CustomTargets.makeWebsite(name: "Ex", address: "http://example.com", existing: bundled)
        }
    }

    func testMakeWebsiteRejectsOtherSchemes() {
        for address in ["ftp://example.com", "file:///etc/passwd", "javascript://x.com/%0Aalert(1)"] {
            assertThrows(.invalidURL) {
                _ = try CustomTargets.makeWebsite(name: "Ex", address: address, existing: bundled)
            }
        }
    }

    func testMakeWebsiteRejectsEmbeddedCredentials() {
        assertThrows(.invalidURL) {
            _ = try CustomTargets.makeWebsite(name: "Ex", address: "https://user@x.com", existing: bundled)
        }
        assertThrows(.invalidURL) {
            _ = try CustomTargets.makeWebsite(name: "Ex", address: "https://chatgpt.com@evil.example", existing: bundled)
        }
    }

    func testMakeWebsiteRejectsEmptyAddress() {
        assertThrows(.invalidURL) {
            _ = try CustomTargets.makeWebsite(name: "Ex", address: "   ", existing: bundled)
        }
    }

    func testMakeWebsiteRejectsEmptyName() {
        assertThrows(.invalidName) {
            _ = try CustomTargets.makeWebsite(name: "", address: "example.com", existing: bundled)
        }
        assertThrows(.invalidName) {
            _ = try CustomTargets.makeWebsite(name: "   \n ", address: "example.com", existing: bundled)
        }
    }

    func testMakeWebsiteRejectsOverlongName() {
        assertThrows(.invalidName) {
            _ = try CustomTargets.makeWebsite(name: String(repeating: "a", count: 61), address: "example.com", existing: bundled)
        }
    }

    func testMakeWebsiteRejectsBidiControlInName() {
        assertThrows(.invalidName) {
            _ = try CustomTargets.makeWebsite(name: "Cl\u{202E}aude", address: "example.com", existing: bundled)
        }
    }

    func testMakeWebsiteDuplicateOfCatalogName() {
        assertThrows(.duplicate("ChatGPT")) {
            _ = try CustomTargets.makeWebsite(name: "ChatGPT", address: "example.com", existing: bundled)
        }
        assertThrows(.duplicate("ChatGPT")) {
            _ = try CustomTargets.makeWebsite(name: "chat gpt", address: "example.com", existing: bundled)
        }
        assertThrows(.duplicate("ChatGPT")) {
            _ = try CustomTargets.makeWebsite(name: "CHATGPT", address: "example.com", existing: bundled)
        }
    }

    func testMakeWebsiteDuplicateOfCatalogAlias() {
        // "anthropic" is an alias of Claude.
        assertThrows(.duplicate("Claude")) {
            _ = try CustomTargets.makeWebsite(name: "Anthropic", address: "example.com", existing: bundled)
        }
    }

    func testMakeWebsiteDuplicateOfEarlierCustomEntry() throws {
        let first = try CustomTargets.makeWebsite(name: "Mine", address: "example.com", existing: bundled)
        let registry = AppRegistry(targets: bundled.targets + [first])
        assertThrows(.duplicate("Mine")) {
            _ = try CustomTargets.makeWebsite(name: "m i n e", address: "example.org", existing: registry)
        }
    }

    func testMakeWebsiteFullWhenAtCap() {
        let customs = (0..<CustomTargets.maxCustom).map { site("custom-x\($0)", name: "Zed \($0)") }
        let registry = AppRegistry(targets: bundled.targets + customs)
        assertThrows(.full) {
            _ = try CustomTargets.makeWebsite(name: "One More", address: "example.com", existing: registry)
        }
    }

    func testMakeWebsiteWithNonLatinNameProducesValidTarget() throws {
        // Non-ASCII names get an ASCII id ("custom-item"); the display name keeps the original text.
        let t = try CustomTargets.makeWebsite(name: "日本語", address: "example.com", existing: bundled)
        XCTAssertTrue(TargetValidator.isValid(t, source: .user))
        XCTAssertEqual(t.id, "custom-item")
        XCTAssertEqual(t.name, "日本語")
    }

    // MARK: makeId

    func testMakeIdSlugifies() {
        XCTAssertEqual(CustomTargets.makeId("My Cool App!", existing: bundled), "custom-my-cool-app")
        XCTAssertEqual(CustomTargets.makeId("  --Hello__World--  ", existing: bundled), "custom-hello-world")
    }

    func testMakeIdFoldsDiacritics() {
        XCTAssertEqual(CustomTargets.makeId("Café Ünï", existing: bundled), "custom-cafe-uni")
    }

    func testMakeIdFallsBackToItem() {
        XCTAssertEqual(CustomTargets.makeId("!!!", existing: bundled), "custom-item")
        XCTAssertEqual(CustomTargets.makeId("", existing: bundled), "custom-item")
        XCTAssertEqual(CustomTargets.makeId("🙂🙂", existing: bundled), "custom-item")
    }

    func testMakeIdDedupesWithSuffixes() {
        let registry = AppRegistry(targets: [site("custom-foo"), site("custom-foo-2")])
        XCTAssertEqual(CustomTargets.makeId("Foo", existing: registry), "custom-foo-3")
        let one = AppRegistry(targets: [site("custom-foo")])
        XCTAssertEqual(CustomTargets.makeId("Foo", existing: one), "custom-foo-2")
    }

    func testMakeIdFallbackAlsoDedupes() {
        let registry = AppRegistry(targets: [site("custom-item")])
        XCTAssertEqual(CustomTargets.makeId("???", existing: registry), "custom-item-2")
    }

    func testMakeIdTruncatesLongNamesAndStaysValid() {
        let id = CustomTargets.makeId(String(repeating: "abcdefghij", count: 10), existing: bundled)
        XCTAssertEqual(id, "custom-" + String(repeating: "abcdefghij", count: 10).prefix(26))
        XCTAssertLessThanOrEqual(id.count, 40)
    }

    // MARK: makeApp

    func testMakeAppRejectsNonAppURL() {
        let file = tmp.appendingPathComponent("notes.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        assertThrows(.notAnApp) { _ = try CustomTargets.makeApp(at: file, existing: bundled) }
        assertThrows(.notAnApp) { _ = try CustomTargets.makeApp(at: tmp, existing: bundled) }
    }

    func testMakeAppRejectsMissingApp() {
        let url = tmp.appendingPathComponent("Ghost.app")
        assertThrows(.notAnApp) { _ = try CustomTargets.makeApp(at: url, existing: bundled) }
    }

    func testMakeAppRejectsBundleWithoutIdentifier() throws {
        let app = tmp.appendingPathComponent("NoId.app")
        try writeFakeApp(at: app, bundleId: nil)
        assertThrows(.notAnApp) { _ = try CustomTargets.makeApp(at: app, existing: bundled) }
    }

    func testMakeAppRejectsUnsignedApp() throws {
        let app = tmp.appendingPathComponent("Fake.app")
        try writeFakeApp(at: app, bundleId: "com.example.fake")
        assertThrows(.untrusted) { _ = try CustomTargets.makeApp(at: app, existing: bundled) }
    }

    func testMakeAppRejectsAppleSystemAppAsUntrusted() throws {
        // Apple system apps carry Apple's own signature, which is neither Developer ID nor App Store.
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path))
        assertThrows(.untrusted) { _ = try CustomTargets.makeApp(at: url, existing: bundled) }
    }

    func testMakeAppDuplicateOfBundledEntry() throws {
        let url = URL(fileURLWithPath: "/Applications/Claude.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path))
        // Only a duplicate if this really is the Claude desktop app's bundle id.
        try XCTSkipUnless(Bundle(url: url)?.bundleIdentifier == "com.anthropic.claudefordesktop")
        assertThrows(.duplicate("Claude")) { _ = try CustomTargets.makeApp(at: url, existing: bundled) }
    }

    private func writeFakeApp(at app: URL, bundleId: String?) throws {
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        var plist: [String: Any] = ["CFBundleName": "Fake", "CFBundlePackageType": "APPL"]
        if let bundleId { plist["CFBundleIdentifier"] = bundleId }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }

    // MARK: save

    private func permissions(_ url: URL) throws -> Int {
        try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
    }

    func testSaveWritesFileAs0600InDirectory0700() throws {
        let url = tmp.appendingPathComponent("nested/Pip/custom.json")
        try CustomTargets.save([site("custom-one", name: "One")], to: url)
        XCTAssertEqual(try permissions(url), 0o600)
        XCTAssertEqual(try permissions(url.deletingLastPathComponent()), 0o700)
    }

    func testSaveTightensPermissionsOnOverwrite() throws {
        let url = tmp.appendingPathComponent("custom.json")
        try CustomTargets.save([site("custom-one", name: "One")], to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        try CustomTargets.save([site("custom-one", name: "One")], to: url)
        XCTAssertEqual(try permissions(url), 0o600)
    }

    func testSaveRoundTripsThroughRegistryLoad() throws {
        let url = tmp.appendingPathComponent("Pip/custom.json")
        let targets = [
            try CustomTargets.makeWebsite(name: "Alpha Site", address: "alpha.example.com", existing: bundled),
            AITarget(id: "custom-beta", name: "Beta", bundleIds: ["com.example.beta"], teamId: "ABCDE12345",
                     webURL: nil, kind: .app),
        ]
        try CustomTargets.save(targets, to: url)
        let loaded = AppRegistry.load(customURL: url)
        let custom = loaded.targets.filter { $0.id.hasPrefix("custom-") }
        XCTAssertEqual(custom, targets)
        XCTAssertEqual(loaded.targets.count, bundled.targets.count + 2)
    }

    func testSaveEmptyListWritesEmptyArray() throws {
        let url = tmp.appendingPathComponent("custom.json")
        try CustomTargets.save([], to: url)
        XCTAssertEqual(AppRegistry.load(customURL: url).targets.count, bundled.targets.count)
    }

    /// Over the cap is refused outright (never silently truncated), and nothing is written.
    func testSaveRefusesMoreThanMaxCustom() throws {
        let url = tmp.appendingPathComponent("custom.json")
        let many = (0..<(CustomTargets.maxCustom + 10)).map { site("custom-s\($0)", name: "Zed \($0)") }
        XCTAssertThrowsError(try CustomTargets.save(many, to: url)) { error in
            XCTAssertEqual(error as? CustomTargets.AddError, .full)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveAtExactlyMaxCustomSucceeds() throws {
        let url = tmp.appendingPathComponent("custom.json")
        let exact = (0..<CustomTargets.maxCustom).map { site("custom-s\($0)", name: "Zed \($0)") }
        try CustomTargets.save(exact, to: url)
        let loaded = AppRegistry.load(customURL: url).targets.filter { $0.id.hasPrefix("custom-") }
        XCTAssertEqual(loaded.count, CustomTargets.maxCustom)
        XCTAssertEqual(loaded.first?.id, "custom-s0")
    }

    /// The 0600 temp-file-then-rename write leaves no stray temp files behind.
    func testSaveLeavesNoTempFiles() throws {
        let url = tmp.appendingPathComponent("custom.json")
        try CustomTargets.save([site("custom-one")], to: url)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: tmp.path).filter { $0.hasPrefix(".custom-") }
        XCTAssertEqual(leftovers, [])
    }

    func testSaveWithNilURLDoesNothing() {
        XCTAssertNoThrow(try CustomTargets.save([site("custom-one")], to: nil))
    }
}
