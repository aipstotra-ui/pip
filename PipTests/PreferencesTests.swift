import XCTest
import Carbon.HIToolbox
@testable import Pip

final class PreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private let key = "pip.preferences"

    override func setUp() {
        super.setUp()
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private let goodCombo = HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))

    func testRoundTripThroughDefaults() {
        let prefs = Preferences(order: ["claude", "chatgpt"], hidden: ["grok"], preferWeb: ["cursor"], hotKey: goodCombo)
        prefs.save(to: defaults)
        XCTAssertEqual(Preferences.load(from: defaults), prefs)
    }

    func testLoadFromEmptyDefaultsGivesDefaults() {
        XCTAssertEqual(Preferences.load(from: defaults), Preferences())
    }

    func testSanitizedDropsMalformedIds() {
        let long = String(repeating: "a", count: 41)
        let prefs = Preferences(
            order: ["ok-id", "Upper", "has space", long, "", "ok2"],
            hidden: ["good", "BAD", "a b", long],
            preferWeb: ["fine", "Fine", "x_y"]
        ).sanitized()
        XCTAssertEqual(prefs.order, ["ok-id", "ok2"])
        XCTAssertEqual(prefs.hidden, ["good"])
        XCTAssertEqual(prefs.preferWeb, ["fine"])
    }

    func testSanitizedAcceptsExactly40CharId() {
        let id = String(repeating: "a", count: 40)
        XCTAssertEqual(Preferences(order: [id]).sanitized().order, [id])
    }

    func testSanitizedDedupesOrderKeepingFirst() {
        let prefs = Preferences(order: ["a", "b", "a", "c", "b"]).sanitized()
        XCTAssertEqual(prefs.order, ["a", "b", "c"])
    }

    func testSanitizedCapsAtMaxIds() {
        let ids = (0..<(Preferences.maxIds + 50)).map { "id-\($0)" }
        let prefs = Preferences(order: ids, hidden: Set(ids), preferWeb: Set(ids)).sanitized()
        XCTAssertEqual(prefs.order.count, Preferences.maxIds)
        XCTAssertEqual(prefs.order, Array(ids.prefix(Preferences.maxIds)))
        XCTAssertEqual(prefs.hidden.count, Preferences.maxIds)
        XCTAssertEqual(prefs.preferWeb.count, Preferences.maxIds)
    }

    func testSanitizedKeepsUsableHotKey() {
        XCTAssertEqual(Preferences(hotKey: goodCombo).sanitized().hotKey, goodCombo)
    }

    func testSanitizedDropsHotKeyWithoutStrongModifier() {
        let noMods = HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: 0)
        let shiftOnly = HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey))
        XCTAssertNil(Preferences(hotKey: noMods).sanitized().hotKey)
        XCTAssertNil(Preferences(hotKey: shiftOnly).sanitized().hotKey)
    }

    func testSanitizedDropsEscapeHotKey() {
        let esc = HotKey.Combo(keyCode: UInt32(kVK_Escape), modifiers: UInt32(controlKey | optionKey | cmdKey))
        XCTAssertNil(Preferences(hotKey: esc).sanitized().hotKey)
    }

    func testSaveSanitizesBeforeWriting() {
        Preferences(order: ["BAD", "good"], hotKey: HotKey.Combo(keyCode: 0, modifiers: 0)).save(to: defaults)
        let loaded = Preferences.load(from: defaults)
        XCTAssertEqual(loaded.order, ["good"])
        XCTAssertNil(loaded.hotKey)
    }

    func testCorruptedDataLoadsDefaults() {
        defaults.set(Data("not json at all {".utf8), forKey: key)
        XCTAssertEqual(Preferences.load(from: defaults), Preferences())
    }

    func testWrongShapeJSONLoadsDefaults() {
        defaults.set(Data(#"{"order": "nope", "hidden": 5}"#.utf8), forKey: key)
        XCTAssertEqual(Preferences.load(from: defaults), Preferences())
    }

    func testOversizedDataLoadsDefaults() throws {
        // Valid JSON, but over the 64 KB cap.
        let ids = (0..<20_000).map { "id-\($0)" }
        let data = try JSONEncoder().encode(Preferences(order: ids))
        XCTAssertGreaterThan(data.count, 64 * 1024)
        defaults.set(data, forKey: key)
        XCTAssertEqual(Preferences.load(from: defaults), Preferences())
    }

    func testWrongTypeStoredUnderKeyLoadsDefaults() {
        defaults.set("a string, not data", forKey: key)
        XCTAssertEqual(Preferences.load(from: defaults), Preferences())
    }

    func testHandEditedDataIsSanitizedOnLoad() {
        defaults.set(Data(#"{"order":["Bad Id","claude"],"hidden":["grok","X"],"preferWeb":[]}"#.utf8), forKey: key)
        let loaded = Preferences.load(from: defaults)
        XCTAssertEqual(loaded.order, ["claude"])
        XCTAssertEqual(loaded.hidden, ["grok"])
    }
}
