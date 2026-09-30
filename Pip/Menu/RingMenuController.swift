import AppKit
import SwiftUI

/// Shows and hides the ring menu around Pip. Closes on selection, Esc, or any click outside the ring.
@MainActor
final class RingMenuController {
    /// Read on every open, so Settings changes apply the next time the ring appears.
    private let source: () -> AppRegistry
    private let onSelect: (AITarget) -> Void
    private var panel: NSPanel?
    private var model: RingMenuModel?
    private var monitors: [Any] = []

    init(source: @escaping () -> AppRegistry, onSelect: @escaping (AITarget) -> Void) {
        self.source = source
        self.onSelect = onSelect
    }

    var isOpen: Bool { panel != nil }

    /// `center` is the point the ring circles, normally the middle of Pip's body (screen coordinates).
    func toggle(around center: NSPoint) {
        isOpen ? close() : open(around: center)
    }

    func open(around center: NSPoint) {
        close()
        let registry = source()
        let targets = registry.topLevel
        // Pip can be dragged partly off-screen, so the body center may be on no screen: use the nearest
        // one (not NSScreen.main, which may be another display and would put the ring far from Pip).
        let screen = NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.min { Self.distance(from: center, to: $0.frame) < Self.distance(from: center, to: $1.frame) }
        guard !targets.isEmpty, let screen else { return }

        let entries = targets.map { target in
            RingEntry(target: target, icon: TargetIcon.appIcon(for: target),
                      children: registry.children(of: target).map { ($0, TargetIcon.appIcon(for: $0)) })
        }
        let scene = Self.scene(for: entries, center: center, bounds: screen.visibleFrame, screenFrame: screen.frame)

        let model = RingMenuModel()
        model.configure(items: scene.items, branches: scene.branches)
        self.model = model

        let view = RingMenuView(model: model, center: scene.center, layout: scene.layout) { [weak self] target in
            self?.close()
            self?.onSelect(target)
        }

        let panel = RingPanel(contentRect: scene.frame)
        // The scene fixes the panel's size; positions are measured from its top edge. If SwiftUI were
        // allowed to resize the window to its own preferred size, the top edge would move and the ring
        // would drift up or down. So the host view never sizes the window.
        let host = NSHostingView(rootView: view.frame(width: scene.frame.width, height: scene.frame.height))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
        installMonitors()
    }

    #if DEBUG
    /// QA diagnostic (Debug only): opens the ring for `center` exactly like `open(around:)`, then reports
    /// whether AppKit kept the panel at the frame the scene asked for, and the ring's shape.
    static func diagnose(center: NSPoint, screen: NSScreen, entries: [RingEntry]) async -> String {
        let scene = scene(for: entries, center: center, bounds: screen.visibleFrame, screenFrame: screen.frame)
        let view = RingMenuView(model: RingMenuModel(), center: scene.center, layout: scene.layout) { _ in }
        let panel = RingPanel(contentRect: scene.frame)
        let host = NSHostingView(rootView: view.frame(width: scene.frame.width, height: scene.frame.height))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(120))   // let AppKit/SwiftUI lay out
        let actual = panel.frame
        panel.orderOut(nil)
        // Where the ring's center really lands on screen, given the panel's actual frame.
        let ringOnScreen = NSPoint(x: actual.minX + scene.center.x, y: actual.maxY - scene.center.y)
        let drift = NSPoint(x: ringOnScreen.x - center.x, y: ringOnScreen.y - center.y)
        func r(_ v: CGFloat) -> String { String(format: "%.1f", v) }
        return "center=(\(r(center.x)),\(r(center.y))) span=\(Int(scene.layout.span)) radius=\(r(scene.layout.radius)) "
            + "asked=\(NSStringFromRect(scene.frame)) got=\(NSStringFromRect(actual)) "
            + "drift=(\(r(drift.x)),\(r(drift.y)))"
    }
    #endif

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        model?.cancelTimers()
        if let panel {
            panel.orderOut(nil)
            // close() can run inside the panel's own button action; don't free the window mid-event.
            DispatchQueue.main.async { withExtendedLifetime(panel) {} }
        }
        panel = nil
        model = nil
    }

    /// Return/Space: activate whichever item keyboard navigation (or the mouse) last highlighted.
    private func selectHighlighted() {
        guard let target = model?.selectedTarget else { return }
        close()
        onSelect(target)
    }

    private func installMonitors() {
        // Clicks in other apps (global monitors for mouse events need no special permission).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) { monitors.append(global) }

        // Clicks on Pip's other windows, and Esc.
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { [weak self] event in
            // NSEvent isn't Sendable, so it can't be returned as the (Sendable) result of
            // assumeIsolated; decide whether to swallow the event inside, then return it outside.
            let swallow: Bool = MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return false }
                if event.type == .keyDown {
                    switch event.keyCode {
                    case 53:                                                     // Esc: leave branch, then close
                        if self.model?.leaveBranch() != true { self.close() }
                        return true
                    case 48:                                                     // Tab / Shift-Tab: into / out of a branch
                        if event.modifierFlags.contains(.shift) { self.model?.leaveBranch() } else { self.model?.enterBranch() }
                        return true
                    case 123, 126: self.model?.moveCounterClockwise(); return true  // ← / ↑
                    case 124, 125: self.model?.moveClockwise(); return true         // → / ↓
                    case 36, 49: self.selectHighlighted(); return true              // Return / Space
                    default: return false
                    }
                }
                // Left clicks on the pet are handled by its own toggle (on mouseUp, after this runs);
                // anything else outside the ring closes it.
                let petToggles = event.type == .leftMouseDown && event.window is PetWindow
                if event.window !== panel, !petToggles { self.close() }
                // The panel spans the ring's bounding box and covers Pip. Transparent pixels usually
                // pass clicks through, but if one lands on the panel off the band (e.g. on Pip in the
                // middle, or empty label room), treat it as a click outside: close and swallow it.
                if event.window === panel, !self.isOnRing(event.locationInWindow, in: panel) {
                    self.close()
                    return true
                }
                return false
            }
            return swallow ? nil : event
        }) { monitors.append(local) }
    }

    /// Whether a point in the panel (window coordinates, y up) is on the band near a slot, or on the open branch.
    private func isOnRing(_ point: NSPoint, in panel: NSPanel) -> Bool {
        guard let model, let height = panel.contentView?.bounds.height else { return false }
        return model.isOnMenu(CGPoint(x: point.x, y: height - point.y))   // item positions are SwiftUI (y down)
    }

    // MARK: Scene

    struct RingEntry {
        let target: AITarget
        let icon: NSImage?
        let children: [(AITarget, NSImage?)]
    }

    /// Everything the view needs, laid out: the panel frame (screen coordinates) and items,
    /// branches and ring center in the panel's SwiftUI coordinates (y down).
    struct RingScene {
        let frame: CGRect
        let layout: RingLayout
        let center: CGPoint
        let items: [RingItem]
        let branches: [RingBranch]
    }

    /// Lays out the ring and every possible branch (only one is ever shown, but the panel leaves
    /// room for all of them so none needs a resize). Pure apart from label text measurement.
    static func scene(for entries: [RingEntry], center: CGPoint, bounds: CGRect, screenFrame: CGRect) -> RingScene {
        let layout = RingLayout.make(count: entries.count, center: center, bounds: bounds)

        // Branch = the parent's own chat entry, then its children.
        let fans: [(index: Int, members: [(AITarget, NSImage?, Bool)], layout: BranchLayout)] =
            entries.enumerated().compactMap { i, entry in
                guard !entry.children.isEmpty, layout.points.indices.contains(i) else { return nil }
                let members = [(entry.target, entry.icon, true)] + entry.children.map { ($0.0, $0.1, false) }
                let fan = BranchLayout.make(count: members.count, center: center, parent: layout.points[i],
                                            ringRadius: layout.radius, ringPoints: layout.points, bounds: bounds)
                return (i, members, fan)
            }

        let labels = entries.map { RingMetrics.labelWidth(name: $0.target.name,
                                                          suffix: RingItem.destinationSuffix(for: $0.target, hasIcon: $0.icon != nil)) }
            + fans.flatMap { $0.members.map { t, icon, chat in
                RingMetrics.labelWidth(name: t.name, suffix: chat ? "Chat" : RingItem.destinationSuffix(for: t, hasIcon: icon != nil))
            } }
        let branchPoints = fans.flatMap { $0.layout.points + [$0.layout.fanCenter(around: center)] }
        let frame = panelFrame(for: layout, center: center, widestLabel: labels.max() ?? 0, branchPoints: branchPoints)
            // Keep the panel inside the usable area (below the menu bar). macOS won't let a window overlap
            // the menu bar and silently pushes it down, which shifted the whole ring ~30pt below Pip
            // whenever Pip was in the upper part of a screen. The ring's icons always fit in this area.
            // Only the top needs this: the Dock strip (sides/bottom) doesn't push windows, and labels
            // there stay visible beside the Dock, so the other edges clip to the full screen.
            .intersection(CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width,
                                 height: min(bounds.maxY, screenFrame.maxY) - screenFrame.minY))
            .integral   // AppKit keeps window frames on whole points; local() must use the frame the panel really gets

        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y) }

        let items = zip(entries, layout.points).map { entry, p in
            RingItem(target: entry.target, icon: entry.icon, position: local(p))
        }
        let branches = fans.map { fan in
            let parentID = entries[fan.index].target.id
            let members = zip(fan.members, fan.layout.points).map { member, p in
                RingItem(target: member.0, icon: member.1, position: local(p), isChatEntry: member.2,
                         id: "\(parentID)/\(member.2 ? "chat" : member.0.id)")
            }
            // Radial geometry, so computing on screen and mapping each point to the panel is exact.
            let connectors = fan.layout.connectors(center: center, parent: layout.points[fan.index], ringRadius: layout.radius)
                .map { BranchLayout.Connector(start: local($0.start), control: local($0.control), end: local($0.end)) }
            return RingBranch(parentID: parentID, items: members,
                              fanCenter: local(fan.layout.fanCenter(around: center)), placement: fan.layout.placement,
                              connectors: connectors)
        }
        return RingScene(frame: frame, layout: layout, center: local(center), items: items, branches: branches)
    }

    /// The band (its centerline's bounding box, padded by half its thickness) plus room for the
    /// hover label beyond its outer edge. Labels sit radially outside the band, so side items need
    /// the widest label's width horizontally but only a label's height vertically. Screen coordinates.
    /// Branch slots (and each fan's center line point) get the same treatment around their circles.
    static func panelFrame(for layout: RingLayout, center: CGPoint, widestLabel: CGFloat,
                           branchPoints: [CGPoint] = []) -> CGRect {
        func box(_ points: [CGPoint], reach: CGFloat) -> CGRect {
            let padX = reach + widestLabel, padY = reach + RingMetrics.labelHeight
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min()! - padX, y: ys.min()! - padY,
                          width: xs.max()! - xs.min()! + padX * 2, height: ys.max()! - ys.min()! + padY * 2)
        }
        let ring = box(centerline(of: layout, around: center), reach: RingMetrics.band / 2 + RingMetrics.labelGap + 4)
        guard !branchPoints.isEmpty else { return ring }
        return ring.union(box(branchPoints, reach: BranchLayout.pad / 2 + RingMetrics.labelGap + 4))
    }

    private static func distance(from p: CGPoint, to rect: CGRect) -> CGFloat {
        hypot(max(rect.minX - p.x, 0, p.x - rect.maxX), max(rect.minY - p.y, 0, p.y - rect.maxY))
    }

    /// Points along the ring's centerline (screen coordinates): the arc sampled every few degrees,
    /// plus the icon positions themselves (which the edge fallback may have pulled off the arc).
    private static func centerline(of layout: RingLayout, around center: CGPoint) -> [CGPoint] {
        let start = layout.facing - layout.span / 2
        let samples = stride(from: 0.0, through: layout.span, by: 3).map { offset -> CGPoint in
            let rad = (start + offset) * .pi / 180
            return CGPoint(x: center.x + layout.radius * cos(rad), y: center.y + layout.radius * sin(rad))
        }
        return samples + layout.points
    }
}

private final class RingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
