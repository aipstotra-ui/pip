import XCTest
@testable import Pip

/// Full-ring placement: the ring must stay centered on the given point, with the same size wherever it
/// fits (the user saw it at different heights around the slime). Edge/corner arcs are unchanged.
final class RingPositionTests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    /// Small deterministic generator so the "random" centers are reproducible.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }

    // MARK: 1. Consistency mid-screen

    func testMidScreenRingIsFullSameRadiusAndCenteredOnTheGivenPoint() {
        var rng = SeededGenerator(state: 42)
        var radii: [CGFloat] = []
        for _ in 0..<20 {
            let center = CGPoint(x: Double.random(in: 200...1720, using: &rng),
                                 y: Double.random(in: 200...880, using: &rng))
            let layout = RingLayout.make(count: 7, center: center, bounds: screen)
            XCTAssertEqual(layout.span, 360, "center \(center)")
            XCTAssertTrue(layout.isFullRing)
            XCTAssertEqual(layout.points.count, 7)
            radii.append(layout.radius)
            for p in layout.points {
                XCTAssertEqual(distance(p, center), Double(layout.radius), accuracy: 1e-6, "point \(p) around \(center)")
            }
            // Centroid of a full ring of equally spaced points is the center itself.
            let cx = layout.points.map(\.x).reduce(0, +) / 7
            let cy = layout.points.map(\.y).reduce(0, +) / 7
            XCTAssertEqual(cx, center.x, accuracy: 1e-6)
            XCTAssertEqual(cy, center.y, accuracy: 1e-6)
        }
        XCTAssertEqual(Set(radii).count, 1, "radius must not vary with position mid-screen: \(radii)")
    }


    // MARK: bodyCenter

    // Constructing a PetWindow in tests would restore and then overwrite the saved "PipPetWindow" frame
    // (setFrameAutosaveName), moving the real pet, so we pin the constants that bodyCenter is built from.
    func testBodyCenterOffsetMatchesSpritePlacement() {
        XCTAssertEqual(PetWindow.bodyCenterOffset, -17.5)
        XCTAssertEqual(PetWindow.petSize, NSSize(width: 100, height: 100))
        // 3.5 sprite pixels at 5pt each: body center sits below the canvas center.
        XCTAssertEqual(PetWindow.bodyCenterOffset, -3.5 * PetWindow.petSize.width / 20)
        // bodyCenter is (frame.midX, frame.midY + offset); for a window at the origin that is (50, 32.5).
        let frame = NSRect(origin: .zero, size: PetWindow.petSize)
        XCTAssertEqual(frame.midX, 50)
        XCTAssertEqual(frame.midY + PetWindow.bodyCenterOffset, 32.5)
    }
}
