import AppKit
import SwiftUI

/// Sizes shared by the ring view and the controller's panel sizing.
enum RingMetrics {
    /// Circular hit area and hover highlight of each item.
    static let slot: CGFloat = 40
    /// Installed app icons, centered in the slot.
    static let icon: CGFloat = 29
    /// Drawn marks (AISymbols) for targets without an app icon.
    static let symbol: CGFloat = 26
    /// Thickness of the frosted band the slots sit on.
    static let band: CGFloat = slot + 12
    /// Space between the band's outer edge and the hover label.
    static let labelGap: CGFloat = 12
    static let labelFontSize: CGFloat = 12
    static let labelHPadding: CGFloat = 10
    static let labelVPadding: CGFloat = 5
    /// Height of the label capsule, rounded up.
    static let labelHeight: CGFloat = 26

    /// Width of an item's label capsule, used to leave room for it around the ring.
    static func labelWidth(name: String, suffix: String?) -> CGFloat {
        let text = suffix.map { "\(name) · \($0)" } ?? name
        let font = NSFont.systemFont(ofSize: labelFontSize, weight: .medium)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + labelHPadding * 2 + 2
    }
}


/// The ring of AI app buttons shown around Pip: circular slots on one frosted band that follows
/// the ring (or arc), branches that grow out of items with children, and a single name label
/// drawn above everything else.
struct RingMenuView: View {
    let model: RingMenuModel
    /// Ring center in the panel's SwiftUI coordinates (y down).
    let center: CGPoint
    let layout: RingLayout
    let onSelect: (AITarget) -> Void

    @State private var shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `initiallyShown` skips the open animation (used by previews and snapshot tests).
    init(model: RingMenuModel, center: CGPoint, layout: RingLayout,
         initiallyShown: Bool = false, onSelect: @escaping (AITarget) -> Void) {
        self.model = model
        self.center = center
        self.layout = layout
        self.onSelect = onSelect
        _shown = State(initialValue: initiallyShown)
    }

    private var openAnimation: Animation { .easeOut(duration: reduceMotion ? 0.12 : 0.17) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    RingBackdrop(band: band)
                        .opacity(shown ? 1 : 0)
                        .animation(openAnimation, value: shown)
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        button(for: item)
                            .position(item.position)
                            .opacity(shown ? 1 : 0)
                            .animation(openAnimation.delay(reduceMotion ? 0 : Double(index) * 0.004), value: shown)
                    }
                    affordanceDots
                        .opacity(shown ? 1 : 0)
                        .animation(openAnimation, value: shown)
                }
                .scaleEffect(shown || reduceMotion ? 1 : 0.9, anchor: anchor(in: geo.size))
                .animation(openAnimation, value: shown)

                branchLayer

                // One label, last in the stack, so no icon or branch can draw over it.
                labelLayer
                    .opacity(shown ? 1 : 0)
                    .animation(openAnimation, value: shown)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            // Hover is resolved geometrically for the whole panel, so the parent, the connectors
            // and the branch circles act as one region (see RingMenuModel.pointerMoved).
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p): model.pointerMoved(to: p)
                case .ended: model.pointerMoved(to: nil)
                }
            }
        }
        .onAppear { shown = true }
    }

    // MARK: Band

    private var band: RingBand {
        // A single item gets a round pad instead of a long arc with one icon on it.
        // (The lone item sits at `facing` for both full rings and arcs.)
        let span = model.items.count == 1 ? 0 : layout.span
        return RingBand(center: center, radius: layout.radius, facing: layout.facing, span: span,
                        thickness: RingMetrics.band)
    }

    private func anchor(in size: CGSize) -> UnitPoint {
        guard size.width > 0, size.height > 0 else { return .center }
        return UnitPoint(x: center.x / size.width, y: center.y / size.height)
    }

    // MARK: Items

    private func button(for item: RingItem) -> some View {
        let isSelected = model.selectedID == item.id && model.branchFocus == nil
        let hasBranch = model.hasBranch(item.id)
        return Button { onSelect(item.target) } label: {
            RingSlot(item: item, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.target.name)
        .accessibilityHint(accessibilityHint(for: item) + (hasBranch ? ". Press Tab for more options" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Show more options") { model.openBranch(item.id) }
    }

    /// Says what activating the item will do, since the kind (and whether the app is installed)
    /// decides whether it opens the app, falls back to the website, or opens Terminal.
    private func accessibilityHint(for item: RingItem) -> String {
        switch item.target.kind {
        case .cli: return "Opens Terminal"
        case .web: return "Opens the website"
        case .app: return item.icon == nil ? "Opens the website" : "Opens the app"
        }
    }

    /// A tiny dot on the band just outside each slot that has a branch, toward where it grows.
    private var affordanceDots: some View {
        ForEach(model.items.filter { model.hasBranch($0.id) }) { item in
            let inward = model.branches[item.id]?.placement == .inward
            let v = unit(from: center, to: item.position)
            let d = (RingMetrics.slot / 2 + 3.5) * (inward ? -1 : 1)
            Circle()
                .fill(QuietInk(opacity: 0.7))
                .frame(width: 3.5, height: 3.5)
                .position(x: item.position.x + v.dx * d, y: item.position.y + v.dy * d)
                .opacity(model.openBranchID == item.id ? 0 : 1)
                .animation(.easeOut(duration: 0.12), value: model.openBranchID)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Branch

    private var branchAnimation: Animation { .easeOut(duration: reduceMotion ? 0.12 : 0.16) }

    /// Connectors and branch circles of the open branch. Each piece is its own ForEach element,
    /// so each gets its own insertion transition (growing out of the parent).
    @ViewBuilder private var branchLayer: some View {
        let branch = model.openBranch
        let parent = branch.flatMap { b in model.items.first { $0.id == b.parentID } }
        let entries = parent == nil ? [] : branch?.items ?? []
        ZStack(alignment: .topLeading) {
            if let branch, let parent {
                // Near-invisible fill: keeps the pointer "on" the panel between the connectors.
                BranchCorridor(parent: parent.position, connectors: branch.connectors)
                    .fill(Color.black.opacity(0.008))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            ForEach(Array(zip(entries, branch?.connectors ?? [])), id: \.0.id) { _, connector in
                BranchConnector(connector: connector)
                    .stroke(QuietInk(opacity: 0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, item in
                branchButton(item, index: index)
                    .transition(growTransition(from: parent?.position ?? item.position, to: item.position))
            }
        }
        .animation(branchAnimation, value: model.openBranchID)
    }

    private func branchButton(_ item: RingItem, index: Int) -> some View {
        let isSelected = model.branchFocus == index
        return Button { onSelect(item.target) } label: {
            RingSlot(item: item, isSelected: isSelected)
                .background { BranchPad() }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isChatEntry ? "\(item.target.name) chat" : item.target.name)
        .accessibilityHint(item.isChatEntry ? "Opens the chat" : accessibilityHint(for: item))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func growTransition(from parent: CGPoint, to point: CGPoint) -> AnyTransition {
        .modifier(active: BranchGrow(progress: 0, from: parent, to: point, grows: !reduceMotion),
                  identity: BranchGrow(progress: 1, from: parent, to: point, grows: !reduceMotion))
    }

    // MARK: Label

    /// The highlighted item, where its label goes (a direction from the ring center), and how far
    /// out it must stay: beyond the band for ring items, beyond the branch for branch items and for
    /// parents whose branch grows outward.
    private var labelPlacement: (item: RingItem, key: String, direction: CGVector, clearance: CGFloat)? {
        let gap = RingMetrics.labelGap
        if let branch = model.openBranch, let item = model.focusedBranchItem {
            let clearance = branch.placement == .inward
                ? layout.radius + RingMetrics.band / 2 + gap
                : distance(to: item.position) + BranchLayout.pad / 2 + gap
            return (item, "branch-\(item.id)", unit(from: center, to: item.position), clearance)
        }
        guard let item = model.selectedItem else { return nil }
        if let branch = model.openBranch, branch.parentID == item.id, branch.placement != .inward {
            // The branch now fills the space next to the parent: its label moves out past the fan.
            return (item, "\(item.id)-open", unit(from: center, to: branch.fanCenter),
                    distance(to: branch.fanCenter) + BranchLayout.pad / 2 + gap)
        }
        return (item, item.id, unit(from: center, to: item.position),
                distance(to: item.position) + RingMetrics.band / 2 + gap)
    }

    @ViewBuilder private var labelLayer: some View {
        ZStack {
            if let placement = labelPlacement {
                RadialLabelLayout(ringCenter: center, clearance: placement.clearance,
                                  direction: placement.direction) {
                    RingLabel(item: placement.item)
                }
                .id(placement.key)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.11), value: labelPlacement?.key)
        .allowsHitTesting(false)
        .accessibilityHidden(true)   // each button already carries its name
    }

    private func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - center.x, point.y - center.y)
    }

    /// Unit vector from `a` toward `b` (straight up if they coincide).
    private func unit(from a: CGPoint, to b: CGPoint) -> CGVector {
        let d = hypot(b.x - a.x, b.y - a.y)
        guard d > 0.5 else { return CGVector(dx: 0, dy: -1) }
        return CGVector(dx: (b.x - a.x) / d, dy: (b.y - a.y) / d)
    }
}

// MARK: - Pieces

/// The ring's centerline stroked into a band with round caps: an annulus for a full ring,
/// or an arc segment matching the layout's facing/span. Angles are AppKit's (90° = up).
struct RingBand: Shape {
    var center: CGPoint     // SwiftUI coordinates (y down)
    var radius: CGFloat
    var facing: Double
    var span: Double
    var thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        // y is flipped relative to AppKit, so AppKit angle `a` is `-a` here.
        if span <= 0 {
            let rad = facing * .pi / 180
            let p = CGPoint(x: center.x + radius * cos(rad), y: center.y - radius * sin(rad))
            return Path(ellipseIn: CGRect(x: p.x - thickness / 2, y: p.y - thickness / 2,
                                          width: thickness, height: thickness))
        }
        var line = Path()
        if span >= 360 {
            line.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2))
        } else {
            line.addRelativeArc(center: center, radius: radius,
                                startAngle: .degrees(-(facing + span / 2)), delta: .degrees(span))
        }
        return line.strokedPath(StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}

/// Roughly `.secondary` at a given strength, as a plain color that reads the same over the band
/// and over the desktop (connectors and the branch dot cross both).
private struct QuietInk: ShapeStyle {
    var opacity: Double
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? .white.opacity(0.55 * opacity) : .black.opacity(0.5 * opacity)
    }
}

/// Hairline edge used on the band and the label so they hold their shape on any wallpaper.
private struct Hairline: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? .white.opacity(0.25) : .black.opacity(0.08)
    }
}

private struct RingBackdrop: View {
    let band: RingBand

    var body: some View {
        band
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .overlay(band.stroke(Hairline(), lineWidth: 0.5))
            .allowsHitTesting(false)
    }
}

private struct RingSlot: View {
    let item: RingItem
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(.primary.opacity(isSelected ? 0.12 : 0))
            glyph
        }
        .frame(width: RingMetrics.slot, height: RingMetrics.slot)
        .scaleEffect(isSelected && !reduceMotion ? 1.07 : 1)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .contentShape(Circle())
    }

    @ViewBuilder private var glyph: some View {
        if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: RingMetrics.icon, height: RingMetrics.icon)
        } else {
            // A drawn mark when there is one, else a monogram, so websites stay tellable apart.
            AISymbol(id: item.target.id, name: item.target.name, size: RingMetrics.symbol)
        }
    }
}

/// The small frosted circle each branch item sits on, matching the band's material and edge.
private struct BranchPad: View {
    var body: some View {
        Circle()
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .overlay(Circle().stroke(Hairline(), lineWidth: 0.5))
            .frame(width: BranchLayout.pad, height: BranchLayout.pad)
    }
}

/// Thin curve from the parent slot's edge to a branch circle's edge (see `BranchLayout.connector`).
private struct BranchConnector: Shape {
    var connector: BranchLayout.Connector

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: connector.start)
        p.addQuadCurve(to: connector.end, control: connector.control)
        return p
    }
}

/// The hover corridor of an open branch: a wide stroke from the parent along each connector.
private struct BranchCorridor: Shape {
    var parent: CGPoint
    var connectors: [BranchLayout.Connector]

    func path(in rect: CGRect) -> Path {
        var line = Path()
        for c in connectors {
            line.move(to: parent)
            line.addLine(to: c.start)
            line.addQuadCurve(to: c.end, control: c.control)
        }
        return line.strokedPath(StrokeStyle(lineWidth: BranchLayout.pad + 8, lineCap: .round, lineJoin: .round))
    }
}

/// Branch items grow out of the parent: from its center at 60% size and transparent, to their spot.
/// With Reduce Motion (`grows == false`) they only fade.
private struct BranchGrow: ViewModifier {
    let progress: CGFloat
    let from: CGPoint
    let to: CGPoint
    let grows: Bool

    func body(content: Content) -> some View {
        let t = grows ? progress : 1
        content
            .scaleEffect(0.6 + 0.4 * t)
            .opacity(progress)
            .position(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
    }
}

private struct RingLabel: View {
    let item: RingItem

    var body: some View {
        HStack(spacing: 0) {
            Text(item.target.name).foregroundStyle(.primary)
            if let suffix = item.destinationSuffix {
                Text(" · \(suffix)").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: RingMetrics.labelFontSize, weight: .medium))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, RingMetrics.labelHPadding)
        .padding(.vertical, RingMetrics.labelVPadding)
        // A filled shape rather than `.background(_:in:)`, so the text keeps plain primary/secondary
        // colors instead of material vibrancy (which inverted their contrast in light mode).
        .background { Capsule().fill(.regularMaterial) }
        .overlay(Capsule().strokeBorder(Hairline(), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

/// Places its (single) child along `direction` from the ring center, as close as it can go while
/// every point of it stays at least `clearance` from the center (so it clears the band evenly at
/// any angle), then clamps it inside the container.
private struct RadialLabelLayout: Layout {
    var ringCenter: CGPoint
    var clearance: CGFloat
    var direction: CGVector
    var margin: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let d = distanceAlongDirection(for: size)
            let x = clamp(ringCenter.x + direction.dx * d, size.width, bounds.width)
            let y = clamp(ringCenter.y + direction.dy * d, size.height, bounds.height)
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                          anchor: .center, proposal: ProposedViewSize(size))
        }
    }

    /// Smallest center distance at which a box of `size` is entirely `clearance` away from the ring center.
    private func distanceAlongDirection(for size: CGSize) -> CGFloat {
        func gap(_ d: CGFloat) -> CGFloat {
            // Nearest point of the box (centered d along `direction`) to the ring center.
            let dx = max(abs(direction.dx * d) - size.width / 2, 0)
            let dy = max(abs(direction.dy * d) - size.height / 2, 0)
            return hypot(dx, dy)
        }
        var lo = clearance, hi = clearance + size.width + size.height
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if gap(mid) >= clearance { hi = mid } else { lo = mid }
        }
        return hi
    }

    private func clamp(_ value: CGFloat, _ length: CGFloat, _ container: CGFloat) -> CGFloat {
        let lo = margin + length / 2, hi = container - margin - length / 2
        return lo <= hi ? min(max(value, lo), hi) : container / 2
    }
}
