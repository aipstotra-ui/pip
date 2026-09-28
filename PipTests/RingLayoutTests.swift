import XCTest
@testable import Pip

final class RingLayoutTests: XCTestCase {

    private let bigScreen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testCountZeroIsEmpty() {
        let layout = RingLayout.make(count: 0, center: CGPoint(x: 960, y: 540), bounds: bigScreen)
        XCTAssertTrue(layout.points.isEmpty)
    }

    func testTenInMiddleOfBigScreenFormsFullRingInsideBounds() {
        let center = CGPoint(x: 960, y: 540)
        let layout = RingLayout.make(count: 10, center: center, bounds: bigScreen)
        XCTAssertEqual(layout.points.count, 10)
        for p in layout.points {
            XCTAssertTrue(bigScreen.contains(p), "\(p) should be inside \(bigScreen)")
        }
    }

    func testPetNearBottomEdgeKeepsPointsInsideAndAboveCenter() {
        let center = CGPoint(x: 960, y: 20) // near the bottom edge (y grows upward, so low y = near bottom)
        let layout = RingLayout.make(count: 8, center: center, bounds: bigScreen)
        XCTAssertEqual(layout.points.count, 8)
        let epsilon = 0.001
        for p in layout.points {
            XCTAssertTrue(bigScreen.contains(p), "\(p) should be inside \(bigScreen)")
            XCTAssertGreaterThanOrEqual(p.y, center.y - epsilon, "point should not be below the center (further from the edge)")
        }
    }

    func testPetInCornerKeepsAllPointsInside() {
        let center = CGPoint(x: 10, y: 10)
        let layout = RingLayout.make(count: 8, center: center, bounds: bigScreen)
        XCTAssertEqual(layout.points.count, 8)
        for p in layout.points {
            XCTAssertTrue(bigScreen.contains(p), "\(p) should be inside \(bigScreen)")
        }
    }

    func testAdjacentPointsAreAtLeastIconSizeApart() {
        let center = CGPoint(x: 960, y: 540)
        let layout = RingLayout.make(count: 10, center: center, bounds: bigScreen)
        for i in 0..<layout.points.count {
            let a = layout.points[i]
            let b = layout.points[(i + 1) % layout.points.count]
            let dist = hypot(a.x - b.x, a.y - b.y)
            XCTAssertGreaterThanOrEqual(dist, RingLayout.iconSize - 0.5,
                                        "adjacent points \(a) and \(b) are only \(dist) apart")
        }
    }
}
