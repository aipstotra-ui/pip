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

    // MARK: Combo

    func testDisplayStringForDefaultIsControlOptionSpace() {
        XCTAssertEqual(HotKey.quickBarDefault.displayString, "⌃⌥Space")
    }

    func testDisplayStringOrdersModifiersControlOptionShiftCommand() {
        let all = HotKey.Combo(keyCode: UInt32(kVK_Return),
                               modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey))
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘↩")
    }

    func testDisplayStringForSpecialKeys() {
        XCTAssertEqual(HotKey.Combo(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey)).displayString, "⌘F5")
        XCTAssertEqual(HotKey.Combo(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(optionKey)).displayString, "⌥←")
    }

    func testIsUsableTrueCases() {
        XCTAssertTrue(HotKey.quickBarDefault.isUsable)
        XCTAssertTrue(HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)).isUsable)
        XCTAssertTrue(HotKey.Combo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)).isUsable)
        XCTAssertTrue(HotKey.Combo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey | shiftKey)).isUsable)
    }

    func testIsUsableFalseWithoutStrongModifier() {
        XCTAssertFalse(HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: 0).isUsable)
        XCTAssertFalse(HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey)).isUsable)
    }

    func testIsUsableFalseForEscape() {
        XCTAssertFalse(HotKey.Combo(keyCode: UInt32(kVK_Escape), modifiers: UInt32(controlKey | optionKey | cmdKey)).isUsable)
    }

    func testIsUsableFalseForOutOfRangeKeyCode() {
        XCTAssertTrue(HotKey.Combo(keyCode: 0x7F, modifiers: UInt32(cmdKey)).isUsable)
        XCTAssertFalse(HotKey.Combo(keyCode: 0x80, modifiers: UInt32(cmdKey)).isUsable)
    }

    func testComboCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(HotKey.quickBarDefault)
        XCTAssertEqual(try JSONDecoder().decode(HotKey.Combo.self, from: data), HotKey.quickBarDefault)
    }
}
