import AppKit
import SwiftUI

/// Transparent, borderless, always-on-top panel that hosts Pip on every Space.
final class PetWindow: NSPanel {
    static let petSize = NSSize(width: 96, height: 96)
    private static let autosaveName = "PipPetWindow"

    /// Called on a click that didn't turn into a drag.
    var onClick: (() -> Void)?
    /// Called when a drag starts, e.g. to close the ring menu.
    var onDragStart: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.petSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentView = PetHostingView(rootView: PetView())

        // Restore before setting the autosave name, which would otherwise overwrite the saved frame.
        if setFrameUsingName(Self.autosaveName) {
            // Keep the saved origin but not a stale size from an older build.
            setFrame(NSRect(origin: frame.origin, size: Self.petSize), display: false)
            // Borderless windows aren't constrained to a screen; recover if the saved screen is gone.
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                placeAtDefaultPosition()
            }
        } else {
            placeAtDefaultPosition()
        }
        setFrameAutosaveName(Self.autosaveName)
    }

    // Key status is needed later for the ring menu's keyboard handling.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Bottom-right of the main screen, just above the Dock.
    private func placeAtDefaultPosition() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: visible.maxX - frame.width - 40, y: visible.minY + 8))
    }
}

/// A press that moves less than `dragThreshold` is a click (opens the ring menu); more than that drags Pip.
private final class PetHostingView: NSHostingView<PetView> {
    private static let dragThreshold: CGFloat = 4
    private var pressMouse: NSPoint?
    private var pressOrigin: NSPoint?
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        pressMouse = NSEvent.mouseLocation
        pressOrigin = window?.frame.origin
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressMouse, let pressOrigin, let window = window as? PetWindow else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - pressMouse.x, dy = now.y - pressMouse.y
        if !isDragging {
            guard hypot(dx, dy) >= Self.dragThreshold else { return }
            isDragging = true
            window.onDragStart?()
        }
        window.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressMouse = nil; pressOrigin = nil; isDragging = false }
        if !isDragging, pressMouse != nil { (window as? PetWindow)?.onClick?() }
    }

    // Pip lives in a background app; the first click must reach it without activating anything.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // We move the window ourselves so clicks and drags can be told apart.
    override var mouseDownCanMoveWindow: Bool { false }
}
