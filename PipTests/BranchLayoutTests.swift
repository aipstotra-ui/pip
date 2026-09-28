import XCTest
@testable import Pip

final class BranchLayoutTests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func branch(parentIndex: Int, count: Int = 2, ringCount: Int = 7,
                        center: CGPoint) -> (RingLayout, BranchLayout) {
        let ring = RingLayout.make(count: ringCount, center: center, bounds: screen)
        let fan = BranchLayout.make(count: count, center: center, parent: ring.points[parentIndex],
                                    ringRadius: ring.radius, ringPoints: ring.points, bounds: screen)
        return (ring, fan)
    }

    private func angle(of p: CGPoint, around c: CGPoint) -> Double {
        atan2(p.y - c.y, p.x - c.x) * 180 / .pi
    }

    private func assertClear(_ ring: RingLayout, _ fan: BranchLayout, file: StaticString = #filePath, line: UInt = #line) {
        let safe = screen.insetBy(dx: BranchLayout.pad / 2, dy: BranchLayout.pad / 2)
        for p in fan.points {
            XCTAssertTrue(safe.contains(p), "\(p) should be fully on screen", file: file, line: line)
            for r in ring.points {
                XCTAssertGreaterThanOrEqual(hypot(p.x - r.x, p.y - r.y), BranchLayout.pad / 2 + RingMetrics.slot / 2,
                                            "branch \(p) overlaps ring slot \(r)", file: file, line: line)
            }
        }
        for i in fan.points.indices {
            for j in fan.points.indices where j > i {
                let d = hypot(fan.points[i].x - fan.points[j].x, fan.points[i].y - fan.points[j].y)
                XCTAssertGreaterThanOrEqual(d, BranchLayout.pad, "branch circles overlap", file: file, line: line)
            }
        }
    }

    func testMidScreenFanIsOutwardAndSymmetricAroundParent() {
        let center = CGPoint(x: 720, y: 450)
        let (ring, fan) = branch(parentIndex: 1, center: center)
        XCTAssertEqual(fan.placement, .outward)
        XCTAssertEqual(fan.radius, ring.radius + BranchLayout.offset, accuracy: 0.001)

        let parentAngle = angle(of: ring.points[1], around: center)
        XCTAssertEqual(fan.fanAngle, parentAngle, accuracy: 0.001)
        let offsets = fan.points.map { angle(of: $0, around: center) - parentAngle }
        XCTAssertEqual(offsets[0], -offsets[1], accuracy: 0.001, "fan must be symmetric around the parent")
        XCTAssertEqual(abs(offsets[0]), 18, accuracy: 2.1, "two items sit about ±16–20° from the parent")
        for p in fan.points {
            XCTAssertEqual(hypot(p.x - center.x, p.y - center.y), fan.radius, accuracy: 0.001)
        }
        assertClear(ring, fan)
    }

    func testFanIsOutsideTheBand() {
        let center = CGPoint(x: 720, y: 450)
        let (ring, fan) = branch(parentIndex: 0, center: center)
        for p in fan.points {
            let inner = hypot(p.x - center.x, p.y - center.y) - BranchLayout.pad / 2
            XCTAssertGreaterThan(inner, ring.radius + RingMetrics.band / 2, "branch circle must clear the band")
        }
    }

    func testThreeItemsStaySymmetricWithMiddleOnParentAngle() {
        let center = CGPoint(x: 720, y: 450)
        let (ring, fan) = branch(parentIndex: 3, count: 3, center: center)
        let parentAngle = angle(of: ring.points[3], around: center)
        XCTAssertEqual(angle(of: fan.points[1], around: center), parentAngle, accuracy: 0.001)
        assertClear(ring, fan)
    }

    /// Mid-screen, the four edges and the four corners.
    private static let petPositions = [
        CGPoint(x: 720, y: 40), CGPoint(x: 720, y: 860), CGPoint(x: 40, y: 450), CGPoint(x: 1400, y: 450),
        CGPoint(x: 40, y: 40), CGPoint(x: 1400, y: 860), CGPoint(x: 40, y: 860), CGPoint(x: 1400, y: 40),
        CGPoint(x: 720, y: 450),
    ]

    func testEveryParentOnEveryEdgeFitsOnScreen() {
        for center in Self.petPositions {
            let ring = RingLayout.make(count: 7, center: center, bounds: screen)
            for i in ring.points.indices {
                let fan = BranchLayout.make(count: 2, center: center, parent: ring.points[i],
                                            ringRadius: ring.radius, ringPoints: ring.points, bounds: screen)
                XCTAssertNotEqual(fan.placement, .clamped, "center \(center), parent \(i)")
                assertClear(ring, fan)
                // Rotated fans are still symmetric around their own center line.
                let offsets = fan.points.map { angle(of: $0, around: center) - fan.fanAngle }
                    .map { ($0 + 540).truncatingRemainder(dividingBy: 360) - 180 }
                XCTAssertEqual(offsets[0], -offsets[1], accuracy: 0.001)
            }
        }
    }

    func testEdgeArcEndRotatesFanAwayFromEdge() {
        // Bottom edge: upward arc; its left end (the first item) sits level with Pip, near the bottom.
        let center = CGPoint(x: 720, y: 40)
        let (ring, fan) = branch(parentIndex: 0, center: center)
        XCTAssertEqual(ring.span, 180)
        XCTAssertEqual(fan.placement, .outward)
        let parentAngle = angle(of: ring.points[0], around: center)
        XCTAssertNotEqual(fan.fanAngle, parentAngle, "fan should rotate to stay on screen")
        XCTAssertLessThanOrEqual(abs(fan.fanAngle - parentAngle), 48)
        assertClear(ring, fan)
    }

    func testCorridorCoversParentConnectorsAndBranchButNotFarAway() {
        let parent = CGPoint(x: 0, y: 0)
        let points = [CGPoint(x: 60, y: 40), CGPoint(x: 60, y: -40)]
        let connectors = points.map {
            BranchLayout.Connector(start: parent, control: CGPoint(x: $0.x / 2, y: $0.y / 2), end: $0)
        }
        func inside(_ p: CGPoint) -> Bool { BranchLayout.corridorContains(p, connectors: connectors, points: points) }
        XCTAssertTrue(inside(parent))
        XCTAssertTrue(inside(CGPoint(x: 30, y: 20)))
        XCTAssertTrue(inside(CGPoint(x: 60, y: 40)))
        XCTAssertFalse(inside(CGPoint(x: -80, y: 0)))
        XCTAssertFalse(inside(CGPoint(x: 150, y: 0)))
    }

    func testConnectorLeavesParentRadiallyAndEndsAtBranchEdge() {
        let center = CGPoint(x: 720, y: 450)
        let (ring, fan) = branch(parentIndex: 1, center: center)
        let parent = ring.points[1]
        for (c, p) in zip(fan.connectors(center: center, parent: parent, ringRadius: ring.radius), fan.points) {
            // start, control and ring center are collinear (the curve leaves along the radius)
            let cross = (c.start.x - center.x) * (c.control.y - center.y) - (c.start.y - center.y) * (c.control.x - center.x)
            XCTAssertEqual(cross, 0, accuracy: 0.01)
            XCTAssertEqual(hypot(c.start.x - parent.x, c.start.y - parent.y), RingMetrics.slot / 2 + 2, accuracy: 0.01)
            XCTAssertEqual(hypot(c.end.x - p.x, c.end.y - p.y), BranchLayout.pad / 2, accuracy: 0.01)
        }
    }

    /// The reviewer's rule: a connector never passes within slot radius + 4pt of another slot, and
    /// once it has left the parent's patch of band it stays outside the band's outer edge.
    func testConnectorsKeepClearOfOtherSlotsAndTheBandAtAllPetPositions() {
        for center in Self.petPositions {
            let ring = RingLayout.make(count: 7, center: center, bounds: screen)
            for (i, parent) in ring.points.enumerated() {
                let fan = BranchLayout.make(count: 2, center: center, parent: parent,
                                            ringRadius: ring.radius, ringPoints: ring.points, bounds: screen)
                let others = ring.points.enumerated().filter { $0.offset != i }.map(\.element)
                for c in fan.connectors(center: center, parent: parent, ringRadius: ring.radius) {
                    for q in c.samples(60) {
                        for o in others {
                            XCTAssertGreaterThanOrEqual(hypot(q.x - o.x, q.y - o.y), RingMetrics.slot / 2 + 4,
                                                        "center \(center), parent \(i): connector grazes slot \(o)")
                        }
                        guard hypot(q.x - parent.x, q.y - parent.y) > RingMetrics.band / 2 + 4 else { continue }
                        let r = hypot(q.x - center.x, q.y - center.y)
                        if fan.placement == .inward {
                            XCTAssertLessThanOrEqual(r, ring.radius - RingMetrics.band / 2)
                        } else {
                            XCTAssertGreaterThanOrEqual(r, ring.radius + RingMetrics.band / 2,
                                                        "center \(center), parent \(i): connector runs over the band")
                        }
                    }
                }
            }
        }
    }

    func testZeroCountIsEmpty() {
        let fan = BranchLayout.make(count: 0, center: .zero, parent: CGPoint(x: 0, y: 84),
                                    ringRadius: 84, ringPoints: [], bounds: screen)
        XCTAssertTrue(fan.points.isEmpty)
    }
}
