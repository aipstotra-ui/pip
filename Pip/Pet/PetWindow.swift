import AppKit
import QuartzCore

/// Transparent, borderless, always-on-top panel that hosts Pip on every Space.
final class PetWindow: NSPanel {
    /// 20×20 sprite at 5× = 100pt.
    static let petSize = NSSize(width: 100, height: 100)

    /// The slime sits low in its 20×20 canvas (idle body spans rows 7–19, center ≈ row 13.5 vs. the
    /// canvas center at row 10), so the body's center is 3.5 pixels × 5pt below the window's center.
    static let bodyCenterOffset: CGFloat = -17.5

    /// Middle of Pip's body in screen coordinates: what the ring circles around.
    var bodyCenter: NSPoint { NSPoint(x: frame.midX, y: frame.midY + Self.bodyCenterOffset) }

    /// The slime's visible body (idle frame: columns 3–16, rows 7–19 of the 20×20 canvas at 5pt),
    /// in screen coordinates. Speech bubbles and follow-up menus sit just above it.
    var bodyFrame: NSRect {
        NSRect(x: frame.minX + 15, y: frame.minY, width: 70, height: 65)
    }
    private static let autosaveName = "PipPetWindow"

    /// Called on a click that didn't turn into a drag.
    var onClick: (() -> Void)?
    /// Called when a drag starts, e.g. to close the ring menu.
    var onDragStart: (() -> Void)?
    /// Called when the pointer moves onto Pip.
    var onHover: (() -> Void)?
    /// Called on a right-click (or Control-click) on Pip.
    var onRightClick: (() -> Void)?

    let animator = PetAnimator()
    private let petView = PetPixelView(frame: NSRect(origin: .zero, size: PetWindow.petSize))
    private var observers: [NSObjectProtocol] = []

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
        contentView = petView

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
        observeVisibility()

        petView.render(animator.frame, label: Self.accessibilityLabel(for: animator.state))
        animator.onFrameChange = { [weak self] in
            guard let self else { return }
            self.petView.render(self.animator.frame, label: Self.accessibilityLabel(for: self.animator.state))
        }
        animator.start()
    }

    private static func accessibilityLabel(for state: PetState) -> String {
        switch state {
        case .idle, .happy: "Pip"
        case .sleeping: "Pip, sleeping"
        case .listening: "Pip, listening"
        }
    }

    /// Pause the animation whenever nobody can see Pip: hidden, fully covered, or displays asleep.
    private func observeVisibility() {
        var screensAsleep = false
        let update: @MainActor (PetWindow) -> Void = { window in
            window.animator.setPaused(screensAsleep || !window.occlusionState.contains(.visible))
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: self, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { if let self { update(self) } }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for (name, asleep) in [(NSWorkspace.screensDidSleepNotification, true), (NSWorkspace.screensDidWakeNotification, false)] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    screensAsleep = asleep
                    if let self { update(self) }
                }
            })
        }
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

/// Draws Pip's current frame via a layer-backed CALayer content swap (no SwiftUI in the redraw
/// path), and tells clicks/drags/hovers on Pip apart.
/// A press that moves less than `dragThreshold` is a click (opens the ring menu); more than that drags Pip.
private final class PetPixelView: NSView {
    private static let dragThreshold: CGFloat = 4
    private var pressMouse: NSPoint?
    private var pressOrigin: NSPoint?
    private var isDragging = false

    private var hoverArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resizeAspect
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Swaps in the frame's cached image and updates the accessibility label. Wrapped in a
    /// disabled-actions transaction so the layer content swap isn't animated.
    func render(_ art: PixelArt, label: String) {
        setAccessibilityLabel(label)
        guard let image = PixelArtImageCache.shared.image(for: art) else { return }
        currentImage = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = image
        CATransaction.commit()
    }

    private var currentImage: CGImage?

    // AppKit may redisplay the view (e.g. on a backing-scale change when moving between
    // displays); supply the contents here so that redisplay doesn't blank the layer.
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { layer?.contents = currentImage }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        (window as? PetWindow)?.onHover?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard pressMouse == nil else { return }   // mid-drag: ignore, the menu would swallow the mouse-up
        (window as? PetWindow)?.onRightClick?()
    }

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
        if !isDragging, pressMouse != nil {
            if event.modifierFlags.contains(.control) { (window as? PetWindow)?.onRightClick?() }
            else { (window as? PetWindow)?.onClick?() }
        }
    }

    // Pip lives in a background app; the first click must reach it without activating anything.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // We move the window ourselves so clicks and drags can be told apart.
    override var mouseDownCanMoveWindow: Bool { false }
}
