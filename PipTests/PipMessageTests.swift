import XCTest
@testable import Pip

final class PipMessageTests: XCTestCase {

    func testButtonTitles() {
        XCTAssertEqual(PipMessage.Action.openAutomationSettings.title, "Open System Settings")
        XCTAssertEqual(PipMessage.Action.openPipSettings(.shortcut).title, "Change Shortcut")
        XCTAssertEqual(PipMessage.Action.openPipSettings(.apps).title, "Settings")
        XCTAssertEqual(PipMessage.Action.retry(targetID: "claude").title, "Try Again")
    }

    func testRetryTitleIgnoresTargetID() {
        XCTAssertEqual(PipMessage.Action.retry(targetID: "a").title, PipMessage.Action.retry(targetID: "b").title)
    }

    func testAutomationSettingsURL() {
        let url = PipMessage.automationSettingsURL
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
        XCTAssertTrue(url.absoluteString.contains("Privacy_Automation"))
    }

    func testDefaultActionIsNil() {
        XCTAssertNil(PipMessage("Hello.").action)
    }

    func testEquatableComparesTextAndAction() {
        XCTAssertEqual(PipMessage("Hi."), PipMessage("Hi."))
        XCTAssertEqual(PipMessage("Hi.", action: .openAutomationSettings), PipMessage("Hi.", action: .openAutomationSettings))
        XCTAssertNotEqual(PipMessage("Hi."), PipMessage("Bye."))
        XCTAssertNotEqual(PipMessage("Hi."), PipMessage("Hi.", action: .openAutomationSettings))
        XCTAssertNotEqual(PipMessage("Hi.", action: .openPipSettings(.apps)), PipMessage("Hi.", action: .openPipSettings(.shortcut)))
        XCTAssertNotEqual(PipMessage("Hi.", action: .retry(targetID: "a")), PipMessage("Hi.", action: .retry(targetID: "b")))
        XCTAssertEqual(PipMessage("Hi.", action: .retry(targetID: "a")), PipMessage("Hi.", action: .retry(targetID: "a")))
    }
}
