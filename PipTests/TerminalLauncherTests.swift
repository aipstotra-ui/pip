import XCTest
@testable import Pip

@MainActor
final class TerminalLauncherTests: XCTestCase {

    func testRejectsRelativePath() {
        XCTAssertFalse(TerminalLauncher.isAcceptablePath("relative/path"))
    }

    func testRejectsNewlineControlCharacter() {
        XCTAssertFalse(TerminalLauncher.isAcceptablePath("/Users/me/folder\ninjected"))
    }

    func testRejectsOtherControlCharacters() {
        XCTAssertFalse(TerminalLauncher.isAcceptablePath("/Users/me/folder\u{0007}bell"))
        XCTAssertFalse(TerminalLauncher.isAcceptablePath("/Users/me/folder\u{001B}esc"))
    }

    func testRejectsOverlongPath() {
        let overlong = "/" + String(repeating: "a", count: 1024)
        XCTAssertFalse(TerminalLauncher.isAcceptablePath(overlong))
    }

    func testAcceptsMaxLengthPath() {
        let maxLength = "/" + String(repeating: "a", count: 1023)
        XCTAssertEqual(maxLength.count, 1024)
        XCTAssertTrue(TerminalLauncher.isAcceptablePath(maxLength))
    }

    func testAcceptsPathWithSpacesQuotesAndShellMetacharacters() {
        XCTAssertTrue(TerminalLauncher.isAcceptablePath("/Users/me/My Projects/\"quoted\"/$(whoami)"))
    }

    // NOTE: run(_:in:) is intentionally not tested here — it opens Terminal.app for real,
    // which is unacceptable side effect for a unit test.
}
