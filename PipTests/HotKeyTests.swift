import XCTest
import Carbon.HIToolbox
@testable import Pip

@MainActor
final class HotKeyTests: XCTestCase {

    /// An unusual combo unlikely to collide with a real system or app shortcut, so registration
    /// (and later re-registration) reliably succeeds in CI.
    private var unusualCombo: HotKey.Combo {
        HotKey.Combo(keyCode: UInt32(kVK_F19), modifiers: UInt32(controlKey | optionKey | shiftKey))
    }

    func testRegisteringUnusualComboReturnsNonNil() {
        let hotKey = HotKey(unusualCombo) {}
        XCTAssertNotNil(hotKey)
        hotKey?.unregister()
    }

    func testUnregisterAllowsReRegisteringSameCombo() {
        let combo = unusualCombo
        let first = HotKey(combo) {}
        XCTAssertNotNil(first)
        first?.unregister()

        let second = HotKey(combo) {}
        XCTAssertNotNil(second)
        second?.unregister()
    }

    func testQuickBarDefaultIsControlOptionSpace() {
        XCTAssertEqual(HotKey.quickBarDefault.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(HotKey.quickBarDefault.modifiers, UInt32(controlKey | optionKey))
    }
}
