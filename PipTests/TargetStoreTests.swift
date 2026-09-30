import XCTest
import Carbon.HIToolbox
@testable import Pip

@MainActor
final class TargetStoreTests: XCTestCase {
    private var tmp: URL!
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pip-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tmp)
        super.tearDown()
    }

    private func makeStore() -> TargetStore {
        TargetStore(customURL: tmp.appendingPathComponent("custom.json"), defaults: defaults)
    }

    private var persisted: Preferences { Preferences.load(from: defaults) }
    private let altCombo = HotKey.Combo(keyCode: UInt32(kVK_F19), modifiers: UInt32(controlKey | optionKey | shiftKey))

    // MARK: preferences

    func testStartsWithCatalogOrderAndNothingHidden() {
        let store = makeStore()
        XCTAssertEqual(store.allTopLevelOrdered.map(\.id), store.registry.topLevel.map(\.id))
        XCTAssertEqual(store.visible.targets.count, store.registry.targets.count)
        XCTAssertTrue(store.customTargets.isEmpty)
        XCTAssertEqual(store.hotKey, HotKey.quickBarDefault)
    }

    func testSetHiddenPersistsAndTogglesBack() {
        let store = makeStore()
        store.setHidden("grok", true)
        XCTAssertEqual(persisted.hidden, ["grok"])
        XCTAssertFalse(store.visible.targets.contains { $0.id == "grok" })
        XCTAssertTrue(store.allTopLevelOrdered.contains { $0.id == "grok" })
        store.setHidden("grok", false)
        XCTAssertTrue(persisted.hidden.isEmpty)
        XCTAssertTrue(store.visible.targets.contains { $0.id == "grok" })
    }

    func testSetPreferWebPersists() {
        let store = makeStore()
        store.setPreferWeb("cursor", true)
        XCTAssertEqual(persisted.preferWeb, ["cursor"])
        XCTAssertEqual(store.preferences.preferWeb, ["cursor"])
        store.setPreferWeb("cursor", false)
        XCTAssertTrue(persisted.preferWeb.isEmpty)
    }

    func testSetHiddenIgnoresMalformedId() {
        let store = makeStore()
        store.setHidden("Bad Id", true)
        XCTAssertTrue(store.preferences.hidden.isEmpty)
    }

    func testNewStoreReadsPersistedPreferences() {
        let store = makeStore()
        store.setHidden("grok", true)
        XCTAssertEqual(makeStore().preferences.hidden, ["grok"])
    }

    func testHidingParentHidesBranchInVisible() {
        let store = makeStore()
        store.setHidden("claude", true)
        let ids = store.visible.targets.map(\.id)
        XCTAssertFalse(ids.contains("claude"))
        XCTAssertFalse(ids.contains("claude-code"))
    }

    // MARK: moving

    func testMoveFirstToEnd() {
        let store = makeStore()
        let before = store.allTopLevelOrdered.map(\.id)
        store.moveTopLevel(fromOffsets: IndexSet(integer: 0), toOffset: before.count)
        XCTAssertEqual(store.allTopLevelOrdered.map(\.id), Array(before.dropFirst()) + [before[0]])
        XCTAssertEqual(persisted.order, store.allTopLevelOrdered.map(\.id))
    }

    func testMoveLastToFront() {
        let store = makeStore()
        let before = store.allTopLevelOrdered.map(\.id)
        store.moveTopLevel(fromOffsets: IndexSet(integer: before.count - 1), toOffset: 0)
        XCTAssertEqual(store.allTopLevelOrdered.map(\.id), [before.last!] + Array(before.dropLast()))
    }

    func testMoveUsesOnMoveSemantics() {
        let store = makeStore()
        let before = store.allTopLevelOrdered.map(\.id)
        // Insert before the element originally at index 2, so item 0 lands at index 1.
        store.moveTopLevel(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        var expected = before
        expected.swapAt(0, 1)
        XCTAssertEqual(store.allTopLevelOrdered.map(\.id), expected)
    }

    func testMoveIncludesHiddenItemsAndKeepsThemHidden() {
        let store = makeStore()
        store.setHidden("claude", true)
        let before = store.allTopLevelOrdered.map(\.id)
        XCTAssertTrue(before.contains("claude"))
        store.moveTopLevel(fromOffsets: IndexSet(integer: 0), toOffset: before.count)
        XCTAssertTrue(store.allTopLevelOrdered.contains { $0.id == "claude" })
        XCTAssertTrue(store.preferences.hidden.contains("claude"))
    }

    func testMoveOutOfRangeDoesNotCrash() {
        let store = makeStore()
        let before = store.allTopLevelOrdered.map(\.id)
        store.moveTopLevel(fromOffsets: IndexSet(integer: 0), toOffset: 999)
        XCTAssertEqual(store.allTopLevelOrdered.map(\.id), Array(before.dropFirst()) + [before[0]])
    }

    func testMoveAffectsVisibleOrder() {
        let store = makeStore()
        let last = store.allTopLevelOrdered.last!.id
        store.moveTopLevel(fromOffsets: IndexSet(integer: store.allTopLevelOrdered.count - 1), toOffset: 0)
        XCTAssertEqual(store.visible.topLevel.first?.id, last)
    }

    // MARK: custom entries

    func testAddWebsiteAppearsEverywhere() throws {
        let store = makeStore()
        try store.addWebsite(name: "My Site", address: "mysite.example.com")
        let added = try XCTUnwrap(store.customTargets.first)
        XCTAssertEqual(added.name, "My Site")
        XCTAssertEqual(added.id, "custom-my-site")
        XCTAssertTrue(store.isCustom(added))
        XCTAssertTrue(store.visible.targets.contains(added))
        XCTAssertEqual(store.allTopLevelOrdered.last, added)
        XCTAssertFalse(store.isCustom(store.registry.targets[0]))
    }

    func testAddWebsitePersistsToDisk() throws {
        let store = makeStore()
        try store.addWebsite(name: "My Site", address: "mysite.example.com")
        XCTAssertEqual(makeStore().customTargets.map(\.id), ["custom-my-site"])
    }

    func testAddWebsiteErrorLeavesStoreUnchanged() {
        let store = makeStore()
        XCTAssertThrowsError(try store.addWebsite(name: "ChatGPT", address: "example.com"))
        XCTAssertThrowsError(try store.addWebsite(name: "Ok", address: "http://example.com"))
        XCTAssertTrue(store.customTargets.isEmpty)
    }

    func testAddSeveralWebsitesKeepsAll() throws {
        let store = makeStore()
        try store.addWebsite(name: "First", address: "a.example.com")
        try store.addWebsite(name: "Second", address: "b.example.com")
        XCTAssertEqual(store.customTargets.map(\.id), ["custom-first", "custom-second"])
    }

    func testRemoveCustomRemovesItAndCleansPrefs() throws {
        let store = makeStore()
        try store.addWebsite(name: "My Site", address: "mysite.example.com")
        try store.addWebsite(name: "Other", address: "other.example.com")
        store.setHidden("custom-my-site", true)
        store.setPreferWeb("custom-my-site", true)
        store.moveTopLevel(fromOffsets: IndexSet(integer: store.allTopLevelOrdered.count - 1), toOffset: 0)
        XCTAssertTrue(store.preferences.order.contains("custom-my-site"))

        try store.removeCustom(id: "custom-my-site")

        XCTAssertEqual(store.customTargets.map(\.id), ["custom-other"])
        XCTAssertFalse(store.visible.targets.contains { $0.id == "custom-my-site" })
        XCTAssertFalse(store.preferences.hidden.contains("custom-my-site"))
        XCTAssertFalse(store.preferences.preferWeb.contains("custom-my-site"))
        XCTAssertFalse(store.preferences.order.contains("custom-my-site"))
        XCTAssertFalse(persisted.order.contains("custom-my-site"))
        XCTAssertEqual(makeStore().customTargets.map(\.id), ["custom-other"])
    }

    func testRemoveUnknownIdIsHarmless() throws {
        let store = makeStore()
        try store.addWebsite(name: "Keep", address: "keep.example.com")
        try store.removeCustom(id: "custom-nope")
        XCTAssertEqual(store.customTargets.count, 1)
    }

    func testRemoveCannotDeleteCatalogEntry() throws {
        let store = makeStore()
        let count = store.registry.targets.count
        try store.removeCustom(id: "chatgpt")
        XCTAssertEqual(store.registry.targets.count, count)
    }

    // MARK: hotkey

    func testSetHotKeyAppliesThenSaves() {
        let store = makeStore()
        var applied: [HotKey.Combo] = []
        store.applyHotKey = { applied.append($0); return true }
        XCTAssertTrue(store.setHotKey(altCombo))
        XCTAssertEqual(applied, [altCombo])
        XCTAssertEqual(store.hotKey, altCombo)
        XCTAssertEqual(persisted.hotKey, altCombo)
    }

    func testSetHotKeyNotSavedWhenApplyFails() {
        let store = makeStore()
        store.applyHotKey = { _ in false }
        XCTAssertFalse(store.setHotKey(altCombo))
        XCTAssertNil(store.preferences.hotKey)
        XCTAssertNil(persisted.hotKey)
        XCTAssertEqual(store.hotKey, HotKey.quickBarDefault)
    }

    func testFailedSetHotKeyKeepsPreviousSavedOne() {
        let store = makeStore()
        var accept = true
        store.applyHotKey = { _ in accept }
        XCTAssertTrue(store.setHotKey(altCombo))
        accept = false
        let other = HotKey.Combo(keyCode: UInt32(kVK_F18), modifiers: UInt32(cmdKey))
        XCTAssertFalse(store.setHotKey(other))
        XCTAssertEqual(store.hotKey, altCombo)
        XCTAssertEqual(persisted.hotKey, altCombo)
    }

    func testSetHotKeyNilResetsToDefault() {
        let store = makeStore()
        var applied: [HotKey.Combo] = []
        store.applyHotKey = { applied.append($0); return true }
        store.setHotKey(altCombo)
        XCTAssertTrue(store.setHotKey(nil))
        XCTAssertEqual(applied.last, HotKey.quickBarDefault)
        XCTAssertNil(store.preferences.hotKey)
        XCTAssertNil(persisted.hotKey)
        XCTAssertEqual(store.hotKey, HotKey.quickBarDefault)
    }

    func testSetHotKeyNilNotResetWhenApplyFails() {
        let store = makeStore()
        var accept = true
        store.applyHotKey = { _ in accept }
        store.setHotKey(altCombo)
        accept = false
        XCTAssertFalse(store.setHotKey(nil))
        XCTAssertEqual(store.hotKey, altCombo)
    }

    func testSetHotKeyRejectsUnusableWithoutCallingApply() {
        let store = makeStore()
        var called = false
        store.applyHotKey = { _ in called = true; return true }
        let unusable = HotKey.Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey))
        XCTAssertFalse(store.setHotKey(unusable))
        XCTAssertFalse(called)
        XCTAssertNil(persisted.hotKey)
    }

    func testSetHotKeyWithoutApplyHandlerStillSaves() {
        let store = makeStore()
        XCTAssertTrue(store.setHotKey(altCombo))
        XCTAssertEqual(persisted.hotKey, altCombo)
    }

    // MARK: ring

    func testRingCapsAtTenTopLevelApps() throws {
        let store = makeStore()
        for i in 1...12 { try store.addWebsite(name: "Site \(i)", address: "s\(i).example.com") }
        XCTAssertEqual(store.visible.topLevel.count, store.registry.topLevel.count)
        XCTAssertGreaterThan(store.visible.topLevel.count, 10)
        XCTAssertEqual(store.ring.topLevel.count, TargetArrangement.ringLimit)
        // Branch tools of ring apps stay with them.
        XCTAssertTrue(store.ring.targets.contains { $0.id == "claude-code" })
        XCTAssertFalse(store.ring.targets.contains { $0.id == "custom-site-12" })
    }

    func testHidingRingAppPullsNextIntoRing() throws {
        let store = makeStore()
        for i in 1...12 { try store.addWebsite(name: "Site \(i)", address: "s\(i).example.com") }
        XCTAssertFalse(store.ring.targets.contains { $0.id == "custom-site-4" })
        store.setHidden("gemini", true)
        XCTAssertTrue(store.ring.targets.contains { $0.id == "custom-site-4" })
        XCTAssertEqual(store.ring.topLevel.count, TargetArrangement.ringLimit)
    }

    // MARK: shortcut recorder

    func testRecorderSuspendsShortcutWhileRecordingAndRestoresOnEveryStop() {
        let store = makeStore()
        var calls: [Bool] = []
        store.suspendHotKey = { calls.append($0) }
        let recorder = ShortcutRecorderModel()
        recorder.start(store: store)
        XCTAssertTrue(recorder.isRecording)
        recorder.stop()
        recorder.stop()   // extra stops (onDisappear, Reset) must not resume twice
        XCTAssertFalse(recorder.isRecording)
        recorder.toggle(store: store)
        recorder.toggle(store: store)
        XCTAssertEqual(calls, [true, false, true, false])
    }
}
