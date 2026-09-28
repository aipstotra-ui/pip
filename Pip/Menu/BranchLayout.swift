import CoreGraphics
import Foundation

/// Places a parent's branch items (e.g. "Claude · Chat" and "Claude Code") in a small fan just outside
/// the ring, centered on the parent's angle. Near screen edges the fan rotates, flips inside the ring,
/// or (last resort) is pulled onto the screen. Screen coordinates (AppKit): y up, 90° points up.
struct BranchLayout: Equatable {
    enum Placement: Equatable { case outward, inward, clamped }

    /// Branch slot centers, in clockwise order (the same order the ring uses).
    let points: [CGPoint]
    /// Angle of the fan's center line from the ring center, in degrees.
    let fanAngle: Double
    /// Distance of the branch slots from the ring center.
    let radius: CGFloat
    let placement: Placement

    /// How far beyond the ring's centerline the branch slots sit.
    static let offset: CGFloat = 62
    /// Farther offset tried before rotating more, when a connector would graze the band or a neighbour.
    static let pushedOffset: CGFloat = 86
    /// Connectors leave the parent radially and bend around a control point this far past the centerline.
    static let controlOffset: CGFloat = 40
    /// Diameter of each branch item's frosted circle.
    static let pad: CGFloat = 48
    /// Minimum gap between neighbouring branch circles.
    static let padGap: CGFloat = 8
    /// Preferred angle between neighbouring branch items (two items sit at ±18°).
    static let preferredStep: Double = 36
    /// Branch circles never go closer to the ring center than this (keeps them off Pip).
    static let minInnerRadius: CGFloat = 76
    /// Rotations tried (in degrees, each in both directions) when the fan doesn't fit as is.
    static let rotations: [Double] = stride(from: 0.0, through: 48, by: 4).map { $0 }

    /// The point on the fan's center line at the branch radius (screen coordinates).
    func fanCenter(around center: CGPoint) -> CGPoint {
        Self.point(center: center, angle: fanAngle, radius: radius)
    }

    /// - Parameters:
    ///   - center: ring center.
    ///   - parent: the parent's slot center on the ring.
    ///   - ringRadius: the ring's radius.
    ///   - ringPoints: every ring slot center, so branch circles can be kept off them.
    ///   - bounds: the area branch circles must stay inside (the screen's visible frame).
    static func make(count: Int, center: CGPoint, parent: CGPoint, ringRadius: CGFloat,
                     ringPoints: [CGPoint], bounds: CGRect) -> BranchLayout {
        let parentAngle = atan2(parent.y - center.y, parent.x - center.x) * 180 / .pi
        guard count > 0 else {
            return BranchLayout(points: [], fanAngle: parentAngle, radius: ringRadius + offset, placement: .outward)
        }
        let safe = bounds.insetBy(dx: pad / 2 + 2, dy: pad / 2 + 2)

        func candidate(radius: CGFloat, rotation: Double, placement: Placement) -> BranchLayout {
            let angle = parentAngle + rotation
            return BranchLayout(points: fan(count: count, center: center, angle: angle, radius: radius),
                                fanAngle: angle, radius: radius, placement: placement)
        }
        func fits(_ l: BranchLayout) -> Bool {
            l.points.allSatisfy(safe.contains) && !overlapsRing(l.points, ringPoints: ringPoints)
                && connectorsAreClear(l, center: center, parent: parent, ringRadius: ringRadius, ringPoints: ringPoints)
        }
        /// Smallest rotation that fits (at each rotation the normal distance first, then pushed out);
        /// with both directions fitting, the one further from the edges.
        func firstFit(radii: [CGFloat], placement: Placement) -> BranchLayout? {
            for r in rotations {
                for radius in radii {
                    let options = (r == 0 ? [0] : [r, -r])
                        .map { candidate(radius: radius, rotation: $0, placement: placement) }
                        .filter(fits)
                    if let best = options.max(by: { margin($0.points, safe) < margin($1.points, safe) }) {
                        return best
                    }
                }
            }
            return nil
        }

        if let out = firstFit(radii: [ringRadius + offset, ringRadius + pushedOffset], placement: .outward) { return out }
        let inner = ringRadius - offset
        if inner >= minInnerRadius, let inward = firstFit(radii: [inner], placement: .inward) { return inward }

        // Nothing fits: keep the outward fan, pulled onto the screen.
        let fallback = candidate(radius: ringRadius + offset, rotation: 0, placement: .clamped)
        let clamped = fallback.points.map {
            CGPoint(x: min(max($0.x, safe.minX), safe.maxX), y: min(max($0.y, safe.minY), safe.maxY))
        }
        return BranchLayout(points: clamped, fanAngle: fallback.fanAngle, radius: fallback.radius, placement: .clamped)
    }

    /// `count` points at `radius`, spread symmetrically around `angle`, clockwise.
    static func fan(count: Int, center: CGPoint, angle: Double, radius: CGFloat) -> [CGPoint] {
        let step = self.step(radius: radius)
        return (0..<count).map { i in
            let a = angle + step * (Double(count - 1) / 2 - Double(i))
            return point(center: center, angle: a, radius: radius)
        }
    }

    /// Angle between neighbours: the preferred spread, widened when the circles would touch.
    static func step(radius: CGFloat) -> Double {
        guard radius > 0 else { return preferredStep }
        let chord = Double(pad + padGap)
        let needed = chord >= 2 * Double(radius) ? 180 : 2 * asin(chord / (2 * Double(radius))) * 180 / .pi
        return max(preferredStep, needed)
    }

    // MARK: Connectors

    /// A gentle quadratic curve from the parent slot's edge to a branch circle's edge. It leaves the
    /// parent radially (away from the ring center, or toward it for inward fans), then bends to the item.
    /// Radial geometry only, so it works in screen or panel coordinates alike.
    struct Connector: Equatable {
        let start: CGPoint
        let control: CGPoint
        let end: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                           y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
        }

        func samples(_ n: Int = 24) -> [CGPoint] {
            (0...n).map { point(at: CGFloat($0) / CGFloat(n)) }
        }
    }

    static func connector(center: CGPoint, parent: CGPoint, to item: CGPoint,
                          ringRadius: CGFloat, inward: Bool) -> Connector {
        let d = hypot(parent.x - center.x, parent.y - center.y)
        let v = d > 0.5 ? CGVector(dx: (parent.x - center.x) / d, dy: (parent.y - center.y) / d) : CGVector(dx: 0, dy: 1)
        let s: CGFloat = inward ? -1 : 1
        let lead = RingMetrics.slot / 2 + 2
        let start = CGPoint(x: parent.x + v.dx * s * lead, y: parent.y + v.dy * s * lead)
        let reach = ringRadius + s * controlOffset
        let control = CGPoint(x: center.x + v.dx * reach, y: center.y + v.dy * reach)
        let toItem = hypot(item.x - control.x, item.y - control.y)
        let back = toItem > 0.5 ? pad / 2 / toItem : 0
        let end = CGPoint(x: item.x - (item.x - control.x) * back, y: item.y - (item.y - control.y) * back)
        return Connector(start: start, control: control, end: end)
    }

    func connectors(center: CGPoint, parent: CGPoint, ringRadius: CGFloat) -> [Connector] {
        points.map { Self.connector(center: center, parent: parent, to: $0, ringRadius: ringRadius,
                                    inward: placement == .inward) }
    }

    /// Connectors never cross another slot's circle (slot radius + 4pt), and once clear of the parent's
    /// own patch of band they stay off the band (outside it, or inside it for inward fans).
    static func connectorsAreClear(_ l: BranchLayout, center: CGPoint, parent: CGPoint,
                                   ringRadius: CGFloat, ringPoints: [CGPoint]) -> Bool {
        let others = ringPoints.filter { hypot($0.x - parent.x, $0.y - parent.y) > 0.5 }
        let slotClearance = RingMetrics.slot / 2 + 4
        let parentPatch = RingMetrics.band / 2 + 4
        for c in l.connectors(center: center, parent: parent, ringRadius: ringRadius) {
            for q in c.samples() {
                if others.contains(where: { hypot(q.x - $0.x, q.y - $0.y) < slotClearance }) { return false }
                guard hypot(q.x - parent.x, q.y - parent.y) > parentPatch else { continue }
                let r = hypot(q.x - center.x, q.y - center.y)
                if l.placement == .inward ? r > ringRadius - RingMetrics.band / 2 : r < ringRadius + RingMetrics.band / 2 {
                    return false
                }
            }
        }
        return true
    }

    /// Whether `p` is on a branch's hover corridor: along any connector (which includes the parent's
    /// edge and the branch circle's edge), or on a branch circle. Any coordinate system shared by all inputs.
    static func corridorContains(_ p: CGPoint, connectors: [Connector], points: [CGPoint],
                                 halfWidth: CGFloat = pad / 2 + 4) -> Bool {
        if points.contains(where: { hypot(p.x - $0.x, p.y - $0.y) <= halfWidth }) { return true }
        return connectors.contains { c in
            let s = c.samples(12)
            return zip(s, s.dropFirst()).contains { distance(from: p, toSegment: $0, $1) <= halfWidth }
        }
    }

    // MARK: Helpers

    static func point(center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
        let rad = angle * .pi / 180
        return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
    }

    /// Branch circles must clear every ring slot's band footprint.
    private static func overlapsRing(_ points: [CGPoint], ringPoints: [CGPoint]) -> Bool {
        let minDistance = pad / 2 + RingLayout.iconSize / 2 + 4
        return points.contains { p in ringPoints.contains { hypot(p.x - $0.x, p.y - $0.y) < minDistance } }
    }

    private static func margin(_ points: [CGPoint], _ rect: CGRect) -> CGFloat {
        points.map { min($0.x - rect.minX, rect.maxX - $0.x, $0.y - rect.minY, rect.maxY - $0.y) }.min() ?? 0
    }

    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        let t = len2 > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2)) : 0
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
