import XCTest
@testable import Pip

final class TargetValidatorTests: XCTestCase {

    // MARK: - isSafeWebURL

    func testAcceptsHTTPSWithHost() {
        XCTAssertTrue(TargetValidator.isSafeWebURL(URL(string: "https://chatgpt.com")!))
    }

    func testRejectsHTTP() {
        XCTAssertFalse(TargetValidator.isSafeWebURL(URL(string: "http://chatgpt.com")!))
    }

    func testRejectsFileScheme() {
        XCTAssertFalse(TargetValidator.isSafeWebURL(URL(string: "file:///etc/passwd")!))
    }

    func testRejectsJavascriptScheme() {
        XCTAssertFalse(TargetValidator.isSafeWebURL(URL(string: "javascript:alert(1)")!))
    }

    func testRejectsMissingHost() {
        // "https:///path" parses with scheme https and an empty/nil host.
        XCTAssertFalse(TargetValidator.isSafeWebURL(URL(string: "https:///path")!))
    }

    func testRejectsUserinfoHostLookalike() {
        XCTAssertFalse(TargetValidator.isSafeWebURL(URL(string: "https://chatgpt.com@evil.example")!))
    }

    func testRejectsUserinfoWithPassword() {
        XCTAssertFalse(TargetValidator.isSafeWebURL(URL(string: "https://u:p@x.com")!))
    }

    // MARK: - isValid: id / name / aliases / bundleIds / teamId

    func testRejectsBadIdCharacters() {
        let t = makeTarget(id: "Bad_ID!", kind: .web)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testRejectsOverLongName() {
        let t = makeTarget(name: String(repeating: "a", count: 61), kind: .web)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testAcceptsMaxLengthName() {
        let t = makeTarget(name: String(repeating: "a", count: 60), kind: .web)
        XCTAssertTrue(TargetValidator.isValid(t, source: .bundled))
    }

    func testRejectsTooManyAliases() {
        let aliases = (0..<(TargetValidator.maxAliases + 1)).map { "alias\($0)" }
        let t = makeTarget(aliases: aliases, kind: .web)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testAcceptsMaxAliases() {
        let aliases = (0..<TargetValidator.maxAliases).map { "alias\($0)" }
        let t = makeTarget(aliases: aliases, kind: .web)
        XCTAssertTrue(TargetValidator.isValid(t, source: .bundled))
    }

    func testRejectsControlCharactersInName() {
        let t = makeTarget(name: "Bad\u{0007}Name", kind: .web)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testRejectsBidiOverrideInName() {
        let t = makeTarget(name: "Claude\u{202E}edualC", kind: .web)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testRejectsBadBundleIdCharacters() {
        let t = makeTarget(bundleIds: ["com.evil;rm -rf"], kind: .app)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testRejectsMalformedTeamId() {
        let t = makeTarget(bundleIds: ["com.example.app"], teamId: "short", kind: .app)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testAcceptsWellFormedTeamId() {
        let t = makeTarget(bundleIds: ["com.example.app"], teamId: "ABCDE12345", kind: .app)
        XCTAssertTrue(TargetValidator.isValid(t, source: .bundled))
    }

    // MARK: - isValid: kind rules

    func testRejectsAppKindWithNoBundleIds() {
        let t = makeTarget(bundleIds: [], kind: .app)
        XCTAssertFalse(TargetValidator.isValid(t, source: .bundled))
    }

    func testAcceptsAppKindWithBundleIds() {
        let t = makeTarget(bundleIds: ["com.example.app"], kind: .app)
        XCTAssertTrue(TargetValidator.isValid(t, source: .bundled))
    }

    func testCLIAllowedOnlyForBundledSource() {
        let t = makeTarget(kind: .cli)
        XCTAssertTrue(TargetValidator.isValid(t, source: .bundled))
        XCTAssertFalse(TargetValidator.isValid(t, source: .user))
    }

    func testWebKindNeedsNoBundleIds() {
        let t = makeTarget(bundleIds: [], kind: .web)
        XCTAssertTrue(TargetValidator.isValid(t, source: .bundled))
    }

    // MARK: - helpers

    private func makeTarget(
        id: String = "test-app",
        name: String = "Test App",
        aliases: [String] = [],
        bundleIds: [String] = [],
        teamId: String? = nil,
        webURL: URL = URL(string: "https://example.com")!,
        kind: AITarget.Kind
    ) -> AITarget {
        AITarget(id: id, name: name, aliases: aliases, bundleIds: bundleIds,
                 teamId: teamId, webURL: webURL, kind: kind)
    }
}
