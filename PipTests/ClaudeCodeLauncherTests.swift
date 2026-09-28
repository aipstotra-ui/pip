import XCTest
@testable import Pip

@MainActor
final class ClaudeCodeLauncherTests: XCTestCase {

    func testRejectsRelativePath() {
        XCTAssertFalse(ClaudeCodeLauncher.isAcceptablePath("relative/path"))
    }

    func testRejectsNewlineControlCharacter() {
        XCTAssertFalse(ClaudeCodeLauncher.isAcceptablePath("/Users/me/folder\ninjected"))
    }

    func testRejectsOtherControlCharacters() {
        XCTAssertFalse(ClaudeCodeLauncher.isAcceptablePath("/Users/me/folder\u{0007}bell"))
        XCTAssertFalse(ClaudeCodeLauncher.isAcceptablePath("/Users/me/folder\u{001B}esc"))
    }

    func testRejectsOverlongPath() {
        let overlong = "/" + String(repeating: "a", count: 1024)
        XCTAssertFalse(ClaudeCodeLauncher.isAcceptablePath(overlong))
    }

    func testAcceptsMaxLengthPath() {
        let maxLength = "/" + String(repeating: "a", count: 1023)
        XCTAssertEqual(maxLength.count, 1024)
        XCTAssertTrue(ClaudeCodeLauncher.isAcceptablePath(maxLength))
    }

    func testAcceptsPathWithSpacesQuotesAndShellMetacharacters() {
        XCTAssertTrue(ClaudeCodeLauncher.isAcceptablePath("/Users/me/My Projects/\"quoted\"/$(whoami)"))
    }

    // NOTE: run(in:) is intentionally not tested here — it opens Terminal.app for real,
    // which is unacceptable side effect for a unit test.
}
