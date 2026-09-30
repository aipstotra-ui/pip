import AppKit
import SwiftUI

/// Shows the quick bar on the screen with the mouse. Closes on Esc, selection, the hotkey again,
/// or when it loses focus (e.g. a click elsewhere).
@MainActor
final class QuickBarController {
    /// Read on every open, so Settings changes apply the next time the bar appears.
    private let source: () -> AppRegistry
    /// Called with the chosen target and a screen point near the bar (for follow-up menus).
    private let onSelect: (AITarget, NSPoint) -> Void
    private var panel: QuickBarPanel?
    private var resignObserver: NSObjectProtocol?

    init(source: @escaping () -> AppRegistry, onSelect: @escaping (AITarget, NSPoint) -> Void) {
        self.source = source
        self.onSelect = onSelect
    }

    var isOpen: Bool { panel != nil }

    func toggle() {
        isOpen ? close() : open()
    }

    func open() {
        close()
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }

        let model = QuickBarModel.make(from: source())
        let visible = screen.visibleFrame
        // The card's top edge stays put at ~22% from the top; the panel grows and shrinks below it.
        let top = visible.maxY - visible.height * 0.22 + QuickBarView.margin.top
        let height = QuickBarView.panelHeight(resultCount: model.results.count, queryIsEmpty: model.query.isEmpty)
        let frame = NSRect(x: visible.midX - QuickBarView.panelWidth / 2, y: top - height,
                           width: QuickBarView.panelWidth, height: height)

        let panel = QuickBarPanel(contentRect: frame)
        let view = QuickBarView(
            model: model,
            onOpen: { [weak self, weak panel] target in
                let anchor = panel.map {
                    NSPoint(x: $0.frame.midX, y: $0.frame.maxY - QuickBarView.margin.top - QuickBarView.fieldHeight)
                } ?? mouse
                self?.close()
                self?.onSelect(target, anchor)
            },
            onCancel: { [weak self] in self?.close() },
            onHeightChange: { [weak panel] height in
                // Hug the content so no transparent area is left below the card to swallow clicks.
                guard let panel, abs(panel.frame.height - height) > 0.5 else { return }
                panel.setFrame(NSRect(x: panel.frame.minX, y: top - height,
                                      width: panel.frame.width, height: height), display: true)
            }
        )
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []   // the controller owns the panel size
        panel.contentView = host
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    func close() {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        if let panel {
            panel.orderOut(nil)
            // close() runs inside the panel's own SwiftUI actions (Return, Esc, row tap) and its
            // didResignKey notification; don't free the window and hosting view mid-event.
            DispatchQueue.main.async { withExtendedLifetime(panel) {} }
        }
        panel = nil
    }
}

/// Borderless, non-activating panel that can still take keyboard focus (like Spotlight),
/// so typing works without pulling the user out of their current app.
private final class QuickBarPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        // The card draws its own soft SwiftUI shadow (matching the ring); a window shadow on a
        // clear, animating panel would be computed from the wrong alpha and look boxy.
        hasShadow = false
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
