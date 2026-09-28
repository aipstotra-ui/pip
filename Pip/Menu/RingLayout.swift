import CoreGraphics
import Foundation

/// Places icons around Pip: a full ring when it fits on screen, otherwise an arc facing away from the edge.
/// Screen coordinates (AppKit): y grows upward, and an angle of 90° points up.
struct RingLayout: Equatable {
    let radius: CGFloat
    let points: [CGPoint]

    static let iconSize: CGFloat = 44
    static let gap: CGFloat = 10
    static let minRadius: CGFloat = 84

    /// Candidates in order of preference: (direction the arc faces, span in degrees).
    static let candidates: [(facing: Double, span: Double)] = [
        (90, 360),
        (90, 180), (270, 180), (0, 180), (180, 180),
        (45, 90), (135, 90), (315, 90), (225, 90),
    ]

    static func make(count: Int, center: CGPoint, bounds: CGRect) -> RingLayout {
        guard count > 0 else { return RingLayout(radius: 0, points: []) }
        let safe = bounds.insetBy(dx: iconSize / 2, dy: iconSize / 2)
        for c in candidates {
            let layout = arc(count: count, center: center, facing: c.facing, span: c.span)
            if layout.points.allSatisfy(safe.contains) { return layout }
        }
        // Nothing fits (tiny screen or huge list): use the full ring, pulled onto the screen.
        let ring = arc(count: count, center: center, facing: 90, span: 360)
        let clamped = ring.points.map {
            CGPoint(x: min(max($0.x, safe.minX), safe.maxX), y: min(max($0.y, safe.minY), safe.maxY))
        }
        return RingLayout(radius: ring.radius, points: clamped)
    }

    static func arc(count: Int, center: CGPoint, facing: Double, span: Double) -> RingLayout {
        let spacing = Double(iconSize + gap)
        let isFull = span >= 360
        // Chord length between neighbours is 2r·sin(step/2); solve for r so centers are `spacing` apart.
        // (Arc length r·step would overestimate the straight-line gap.)
        var needed = 0.0
        if count >= 2 {
            let step = (isFull ? 2 * .pi : span * .pi / 180) / Double(isFull ? count : count - 1)
            needed = spacing / (2 * sin(step / 2))
        }
        let radius = max(Double(minRadius), needed)

        let angles: [Double] = (0..<count).map { i in
            if isFull { return facing - 360 * Double(i) / Double(count) }        // clockwise from the top
            if count == 1 { return facing }
            return facing + span / 2 - span * Double(i) / Double(count - 1)      // clockwise across the arc
        }
        let points = angles.map { deg -> CGPoint in
            let rad = deg * .pi / 180
            return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
        }
        return RingLayout(radius: radius, points: points)
    }
}
