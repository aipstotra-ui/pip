import XCTest
@testable import Pip

@MainActor
final class RingMenuModelTests: XCTestCase {

    private func target(_ id: String, kind: AITarget.Kind = .web) -> AITarget {
        AITarget(id: id, name: id, webURL: URL(string: "https://example.com")!, kind: kind)
    }

    /// Ring: a (with branch a-chat, a-kid) at (100,100), b at (200,100). Branch circles at (100,20)/(160,20).
    private func makeModel() -> RingMenuModel {
        let model = RingMenuModel()
        let a = target("a"), b = target("b"), kid = target("kid", kind: .cli)
        let branch = RingBranch(parentID: "a", items: [
            RingItem(target: a, icon: nil, position: CGPoint(x: 100, y: 20), isChatEntry: true, id: "a/chat"),
            RingItem(target: kid, icon: nil, position: CGPoint(x: 160, y: 20), id: "a/kid"),
        ], fanCenter: CGPoint(x: 130, y: 20), placement: .outward, connectors: [
            // Straight lines (control at the midpoint) keep the corridor easy to reason about here.
            .init(start: CGPoint(x: 100, y: 100), control: CGPoint(x: 100, y: 60), end: CGPoint(x: 100, y: 20)),
            .init(start: CGPoint(x: 100, y: 100), control: CGPoint(x: 130, y: 60), end: CGPoint(x: 160, y: 20)),
        ])
        model.configure(items: [
            RingItem(target: a, icon: nil, position: CGPoint(x: 100, y: 100)),
            RingItem(target: b, icon: nil, position: CGPoint(x: 200, y: 100)),
        ], branches: [branch])
        return model
    }

    func testTabEntersBranchArrowsMoveEscReturns() {
        let model = makeModel()
        XCTAssertEqual(model.selectedID, "a")
        XCTAssertTrue(model.enterBranch())
        XCTAssertEqual(model.openBranchID, "a")
        XCTAssertEqual(model.selectedTarget?.id, "a")          // chat entry opens the parent
        model.moveClockwise()
        XCTAssertEqual(model.selectedTarget?.id, "kid")
        model.moveClockwise()
        XCTAssertEqual(model.branchFocus, 0, "arrows wrap within the branch")
        XCTAssertTrue(model.leaveBranch())
        XCTAssertNil(model.branchFocus)
        XCTAssertFalse(model.leaveBranch(), "second Esc falls through to closing the ring")
    }

    func testTabOnItemWithoutBranchDoesNothing() {
        let model = makeModel()
        model.moveClockwise()
        XCTAssertEqual(model.selectedID, "b")
        XCTAssertFalse(model.enterBranch())
        XCTAssertNil(model.openBranchID)
    }

    func testKeyboardMoveAwayClosesBranchImmediately() {
        let model = makeModel()
        model.openBranch("a")
        model.moveClockwise()
        XCTAssertNil(model.openBranchID)
    }

    func testHitTestPrefersBranchThenRingThenCorridor() {
        let model = makeModel()
        XCTAssertEqual(model.hitTest(CGPoint(x: 160, y: 20)), .none, "closed branch isn't hittable")
        model.openBranch("a")
        XCTAssertEqual(model.hitTest(CGPoint(x: 160, y: 22)), .branch(1))
        XCTAssertEqual(model.hitTest(CGPoint(x: 102, y: 98)), .ring("a"))
        XCTAssertEqual(model.hitTest(CGPoint(x: 130, y: 60)), .corridor)
        XCTAssertEqual(model.hitTest(CGPoint(x: 400, y: 400)), .none)
        XCTAssertTrue(model.isOnMenu(CGPoint(x: 130, y: 60)), "clicks on connectors don't close the ring")
        XCTAssertFalse(model.isOnMenu(CGPoint(x: 400, y: 400)))
    }

    func testHoverOpensAfterDelayAndLeavingClosesAfterDelay() async throws {
        let model = makeModel()
        model.openDelay = .milliseconds(10)
        model.closeDelay = .milliseconds(10)
        model.pointerMoved(to: CGPoint(x: 100, y: 100))
        XCTAssertNil(model.openBranchID, "opens after a pause, not instantly")
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(model.openBranchID, "a")

        model.pointerMoved(to: CGPoint(x: 130, y: 60))          // corridor keeps it open
        model.pointerMoved(to: CGPoint(x: 160, y: 20))          // onto a branch item
        XCTAssertEqual(model.selectedTarget?.id, "kid")
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(model.openBranchID, "a")

        model.pointerMoved(to: nil)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertNil(model.openBranchID)
        XCTAssertNil(model.branchFocus)
    }

    /// Grazing another parent on the way into the open branch's corridor must not swap branches.
    func testCorridorCancelsOpenQueuedByGrazingNeighbour() async throws {
        let model = RingMenuModel()
        let a = target("a"), b = target("b")
        let branchA = RingBranch(parentID: "a", items: [
            RingItem(target: a, icon: nil, position: CGPoint(x: 100, y: 20), isChatEntry: true, id: "a/chat"),
        ], fanCenter: CGPoint(x: 100, y: 20), placement: .outward, connectors: [
            .init(start: CGPoint(x: 100, y: 100), control: CGPoint(x: 100, y: 60), end: CGPoint(x: 100, y: 20)),
        ])
        let branchB = RingBranch(parentID: "b", items: [
            RingItem(target: b, icon: nil, position: CGPoint(x: 280, y: 100), isChatEntry: true, id: "b/chat"),
        ], fanCenter: CGPoint(x: 280, y: 100), placement: .outward, connectors: [
            .init(start: CGPoint(x: 200, y: 100), control: CGPoint(x: 240, y: 100), end: CGPoint(x: 280, y: 100)),
        ])
        model.configure(items: [
            RingItem(target: a, icon: nil, position: CGPoint(x: 100, y: 100)),
            RingItem(target: b, icon: nil, position: CGPoint(x: 200, y: 100)),
        ], branches: [branchA, branchB])
        model.openDelay = .milliseconds(10)
        model.closeDelay = .milliseconds(10)
        model.openBranch("a")
        model.pointerMoved(to: CGPoint(x: 200, y: 100))   // grazes b: queues b's branch
        model.pointerMoved(to: CGPoint(x: 100, y: 60))    // back in a's corridor
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(model.openBranchID, "a")
        XCTAssertEqual(model.selectedID, "a")
    }
}
