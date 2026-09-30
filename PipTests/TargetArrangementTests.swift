import XCTest
@testable import Pip

final class TargetArrangementTests: XCTestCase {

    private func site(_ id: String, parent: String? = nil) -> AITarget {
        AITarget(id: id, name: id.capitalized, webURL: URL(string: "https://\(id).example.com")!,
                 kind: .web, parent: parent)
    }

    private func ids(_ registry: AppRegistry) -> [String] { registry.targets.map(\.id) }

    private var basic: AppRegistry {
        AppRegistry(targets: [site("a"), site("b"), site("c")])
    }

    func testEmptyPreferencesGivesCatalogOrder() {
        let result = TargetArrangement.visible(basic, preferences: Preferences())
        XCTAssertEqual(ids(result), ["a", "b", "c"])
    }

    func testEmptyRegistryGivesEmpty() {
        let result = TargetArrangement.visible(AppRegistry(targets: []), preferences: Preferences(order: ["a"]))
        XCTAssertTrue(result.targets.isEmpty)
    }

    func testOrderIsApplied() {
        let result = TargetArrangement.visible(basic, preferences: Preferences(order: ["c", "a", "b"]))
        XCTAssertEqual(ids(result), ["c", "a", "b"])
    }

    func testUnknownIdsInOrderAreIgnored() {
        let result = TargetArrangement.visible(basic, preferences: Preferences(order: ["zzz", "c", "ghost"]))
        XCTAssertEqual(ids(result), ["c", "a", "b"])
    }

    func testNewTargetsGoLastInCatalogOrder() {
        // "b" is ranked; "a" and "c" are new to the saved order.
        let result = TargetArrangement.visible(basic, preferences: Preferences(order: ["b"]))
        XCTAssertEqual(ids(result), ["b", "a", "c"])
    }

    func testPartialOrderKeepsRankedFirst() {
        let registry = AppRegistry(targets: ["a", "b", "c", "d", "e"].map { site($0) })
        let result = TargetArrangement.visible(registry, preferences: Preferences(order: ["d", "b"]))
        XCTAssertEqual(ids(result), ["d", "b", "a", "c", "e"])
    }

    func testChildrenFollowTheirParentWhenReordered() {
        let registry = AppRegistry(targets: [site("a"), site("a-kid", parent: "a"), site("b"), site("b-kid", parent: "b")])
        let result = TargetArrangement.visible(registry, preferences: Preferences(order: ["b", "a"]))
        XCTAssertEqual(ids(result), ["b", "b-kid", "a", "a-kid"])
    }

    func testHiddenParentHidesItsChildren() {
        let registry = AppRegistry(targets: [site("a"), site("a-kid", parent: "a"), site("b")])
        let result = TargetArrangement.visible(registry, preferences: Preferences(hidden: ["a"]))
        XCTAssertEqual(ids(result), ["b"])
    }

    func testHiddenChildOnlyRemovesThatChild() {
        let registry = AppRegistry(targets: [
            site("a"), site("a-one", parent: "a"), site("a-two", parent: "a"), site("b"), site("b-kid", parent: "b"),
        ])
        let result = TargetArrangement.visible(registry, preferences: Preferences(hidden: ["a-one"]))
        XCTAssertEqual(ids(result), ["a", "a-two", "b", "b-kid"])
    }

    func testHiddenUnknownIdChangesNothing() {
        let result = TargetArrangement.visible(basic, preferences: Preferences(hidden: ["nope"]))
        XCTAssertEqual(ids(result), ["a", "b", "c"])
    }

    func testChildIdInOrderDoesNotPromoteChildToTopLevel() {
        let registry = AppRegistry(targets: [site("a"), site("a-kid", parent: "a"), site("b")])
        let result = TargetArrangement.visible(registry, preferences: Preferences(order: ["a-kid", "b", "a"]))
        XCTAssertEqual(ids(result), ["b", "a", "a-kid"])
    }

    // MARK: ring

    private var twelve: AppRegistry {
        var targets: [AITarget] = []
        for i in 1...12 {
            targets.append(site("app-\(i)"))
            if i == 1 || i == 10 || i == 11 || i == 12 { targets.append(site("kid-\(i)", parent: "app-\(i)")) }
        }
        return AppRegistry(targets: targets)
    }

    func testRingKeepsFirstTenTopLevelAndTheirChildren() {
        let ring = TargetArrangement.ring(twelve)
        XCTAssertEqual(ring.topLevel.map(\.id), (1...10).map { "app-\($0)" })
        XCTAssertTrue(ids(ring).contains("kid-1"))
        XCTAssertTrue(ids(ring).contains("kid-10"))
    }

    func testRingDropsEleventhAndBeyondWithTheirChildren() {
        let result = ids(TargetArrangement.ring(twelve))
        for dropped in ["app-11", "kid-11", "app-12", "kid-12"] {
            XCTAssertFalse(result.contains(dropped), "\(dropped) should be dropped")
        }
        XCTAssertEqual(result.count, 12)   // 10 apps + kid-1 + kid-10
    }

    func testRingWithFewerThanLimitKeepsEverything() {
        XCTAssertEqual(ids(TargetArrangement.ring(basic)), ["a", "b", "c"])
    }

    func testRingPreservesRegistryOrder() {
        let ring = TargetArrangement.ring(twelve)
        XCTAssertEqual(Array(ids(ring).prefix(3)), ["app-1", "kid-1", "app-2"])
    }

    func testRingCustomLimit() {
        XCTAssertEqual(ids(TargetArrangement.ring(basic, limit: 2)), ["a", "b"])
        XCTAssertTrue(TargetArrangement.ring(basic, limit: 0).targets.isEmpty)
    }

    func testRingAfterHidingUsesNextApps() {
        // Hiding app-1 lets app-11 into the ring, along with its child.
        let visible = TargetArrangement.visible(twelve, preferences: Preferences(hidden: ["app-1"]))
        let ring = ids(TargetArrangement.ring(visible))
        XCTAssertFalse(ring.contains("app-1"))
        XCTAssertFalse(ring.contains("kid-1"))
        XCTAssertTrue(ring.contains("app-11"))
        XCTAssertTrue(ring.contains("kid-11"))
        XCTAssertFalse(ring.contains("app-12"))
    }
}
