import AppKit
import SwiftUI

/// Shows and hides the ring menu around Pip. Closes on selection, Esc, or any click outside the ring.
@MainActor
final class RingMenuController {
    private let registry: AppRegistry
    private let onSelect: (AITarget) -> Void
    private var panel: NSPanel?
    private var model: RingMenuModel?
    private var monitors: [Any] = []

    init(registry: AppRegistry, onSelect: @escaping (AITarget) -> Void) {
        self.registry = registry
        self.onSelect = onSelect
    }

    var isOpen: Bool { panel != nil }

    func toggle(around petFrame: NSRect) {
        isOpen ? close() : open(around: petFrame)
    }

    func open(around petFrame: NSRect) {
        close()
        let targets = registry.targets
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: petFrame.midX, y: petFrame.midY)) } ?? NSScreen.main
        guard !targets.isEmpty, let bounds = screen?.visibleFrame else { return }

        let center = NSPoint(x: petFrame.midX, y: petFrame.midY)
        let layout = RingLayout.make(count: targets.count, center: center, bounds: bounds)

        // Panel = bounding box of the icons plus room for hover labels, kept on screen.
        let pad = RingLayout.iconSize / 2 + 24
        let xs = layout.points.map(\.x), ys = layout.points.map(\.y)
        let frame = NSRect(x: xs.min()! - pad, y: ys.min()! - pad,
                           width: xs.max()! - xs.min()! + pad * 2, height: ys.max()! - ys.min()! + pad * 2)
            .intersection(screen?.frame ?? .infinite)

        let items = zip(targets, layout.points).map { target, p in
            RingItem(target: target, icon: Self.icon(for: target),
                     position: CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y))
        }
        let model = RingMenuModel()
        model.configure(items: items)
        self.model = model

        let view = RingMenuView(model: model) { [weak self] target in
            self?.close()
            self?.onSelect(target)
        }

        let panel = RingPanel(contentRect: frame)
        panel.contentView = NSHostingView(rootView: view)
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
        installMonitors()
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
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
                    case 53: self.close(); return true                          // Esc
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
                return false
            }
            return swallow ? nil : event
        }) { monitors.append(local) }
    }

    /// The installed app's own icon, or nil for web/CLI targets and apps that aren't installed.
    private static func icon(for target: AITarget) -> NSImage? {
        guard target.kind == .app else { return nil }
        for id in target.bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
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
