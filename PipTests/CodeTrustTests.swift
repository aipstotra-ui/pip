import XCTest
@testable import Pip

final class CodeTrustTests: XCTestCase {

    private let calculatorURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")

    // MARK: - requirementString

    func testRequirementStringWithoutTeamRequiresDeveloperIDOrAppStore() {
        let req = CodeTrust.requirementString(bundleId: "com.example.app", teamId: nil)
        XCTAssertTrue(req.contains("identifier \"com.example.app\""))
        XCTAssertTrue(req.contains("anchor apple generic"))
        XCTAssertFalse(req.contains("certificate leaf[subject.OU]"))
        XCTAssertTrue(req.contains("1.2.840.113635.100.6.2.6"))   // Developer ID intermediate
        XCTAssertTrue(req.contains("1.2.840.113635.100.6.1.13"))  // Developer ID leaf
        XCTAssertTrue(req.contains("1.2.840.113635.100.6.1.9"))   // Mac App Store leaf
    }

    func testRequirementStringCompiles() {
        for team in [nil, "ABCDE12345"] {
            var req: SecRequirement?
            let s = CodeTrust.requirementString(bundleId: "com.example.app", teamId: team)
            XCTAssertEqual(SecRequirementCreateWithString(s as CFString, [], &req), errSecSuccess, s)
        }
    }

    func testRequirementStringWithTeamContainsIdentifierTeamAndAppStoreMarker() {
        let req = CodeTrust.requirementString(bundleId: "com.example.app", teamId: "ABCDE12345")
        XCTAssertTrue(req.contains("identifier \"com.example.app\""))
        XCTAssertTrue(req.contains("certificate leaf[subject.OU] = \"ABCDE12345\""))
        XCTAssertTrue(req.contains("1.2.840.113635.100.6.1.9")) // App Store marker OID
    }

    // MARK: - isTrusted

    /// Apple's own system apps are neither Developer ID nor App Store signed, so they don't qualify.
    func testIsTrustedFalseForAppleSystemApp() throws {
        try skipIfCalculatorMissing()
        XCTAssertFalse(CodeTrust.isTrusted(appAt: calculatorURL, bundleId: "com.apple.calculator", teamId: nil))
    }

    /// Developer ID path: Claude.app, when installed on the test machine.
    func testIsTrustedForInstalledDeveloperIDApp() throws {
        let url = URL(fileURLWithPath: "/Applications/Claude.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Claude.app not installed")
        XCTAssertTrue(CodeTrust.isTrusted(appAt: url, bundleId: "com.anthropic.claudefordesktop", teamId: "Q6L2SF6YDW"))
        XCTAssertTrue(CodeTrust.isTrusted(appAt: url, bundleId: "com.anthropic.claudefordesktop", teamId: nil))
        XCTAssertFalse(CodeTrust.isTrusted(appAt: url, bundleId: "com.anthropic.claudefordesktop", teamId: "UBF8T346G9"))
    }

    /// Mac App Store path: Copilot.app, when installed. The sealed team ID must still match.
    func testIsTrustedForInstalledAppStoreApp() throws {
        let url = URL(fileURLWithPath: "/Applications/Copilot.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Copilot.app not installed")
        XCTAssertTrue(CodeTrust.isTrusted(appAt: url, bundleId: "com.microsoft.copilot-mac", teamId: "UBF8T346G9"))
        XCTAssertFalse(CodeTrust.isTrusted(appAt: url, bundleId: "com.microsoft.copilot-mac", teamId: "Q6L2SF6YDW"))
    }

    func testIsTrustedFalseForWrongBundleId() throws {
        try skipIfCalculatorMissing()
        XCTAssertFalse(CodeTrust.isTrusted(appAt: calculatorURL, bundleId: "com.apple.definitely.not.calculator", teamId: nil))
    }

    func testIsTrustedFalseForWrongTeamId() throws {
        try skipIfCalculatorMissing()
        XCTAssertFalse(CodeTrust.isTrusted(appAt: calculatorURL, bundleId: "com.apple.calculator", teamId: "ABCDE12345"))
    }

    func testIsTrustedFalseForNonexistentPath() {
        let missing = URL(fileURLWithPath: "/nonexistent/path/DoesNotExist.app")
        XCTAssertFalse(CodeTrust.isTrusted(appAt: missing, bundleId: "com.apple.calculator", teamId: nil))
    }

    private func skipIfCalculatorMissing() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: calculatorURL.path),
                           "Calculator.app not present at expected path on this machine")
    }
}
