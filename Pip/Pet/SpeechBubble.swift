import AppKit
import SwiftUI

/// A short message Pip "says" above itself: what happened, plus at most one button for what to do.
/// Auto-hides (later when there's a button, and never while the pointer is over it).
@MainActor
final class SpeechBubble {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    /// Bumped on every show/hide so late callbacks from a replaced bubble (e.g. a hover-exit fired
    /// while its view is torn down) can't cancel or reschedule the hide of the current one.
    private var generation = 0
    /// Runs a bubble's button action; set by the app.
    var onAction: ((PipMessage.Action) -> Void)?

    func show(_ message: PipMessage, above petFrame: NSRect) {
        hide()
        let token = generation
        let seconds: Double = message.action == nil ? 5 : 9
        let tap: (PipMessage.Action) -> Void = { [weak self] action in
            guard let self, self.generation == token else { return }
            self.hide()
            self.onAction?(action)
        }
        let hover: (Bool) -> Void = { [weak self] inside in
            guard let self, self.generation == token, self.panel != nil else { return }
            if inside { self.hideTask?.cancel() } else { self.scheduleHide(after: 3) }
        }
        // Hover comes from an AppKit tracking area (see BubbleHostingView): SwiftUI's onHover can stay
        // silent while Pip (an LSUIElement app) isn't active, which would leave the hover pause dead.
        let host = BubbleHostingView(rootView: BubbleView(message: message, tailPointsDown: true, tailOffsetX: 0,
                                                          onAction: tap, onHover: { _ in }))
        host.onHover = hover
        let size = host.fittingSize
        let center = NSPoint(x: petFrame.midX, y: petFrame.midY)
        let screen = (NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.frame.intersects(petFrame) })?.visibleFrame ?? .infinite

        var origin = NSPoint(x: petFrame.midX - size.width / 2, y: petFrame.maxY + 4)
        var tailPointsDown = true   // bubble above Pip (the usual case): tail points down at it
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
        if origin.y + size.height > screen.maxY {
            origin.y = petFrame.minY - size.height - 4
            tailPointsDown = false  // no room above: bubble sits below Pip, tail points up at it
        }

        // Keep the tail pointed at Pip's center even though the bubble itself got clamped to stay on screen.
        let maxTailOffset = max(size.width / 2 - 27, 0)
        let tailOffsetX = min(max(petFrame.midX - (origin.x + size.width / 2), -maxTailOffset), maxTailOffset)
        host.rootView = BubbleView(message: message, tailPointsDown: tailPointsDown, tailOffsetX: tailOffsetX,
                                   onAction: tap, onHover: { _ in })

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Only a bubble with a button takes clicks; plain bubbles let clicks pass through to what's behind.
        // Clicks pass through at first, so a click already on its way to the window behind can't land
        // on a bubble that just popped up. A bubble with a button starts taking clicks shortly after.
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel

        // Bubble text is decorative to VoiceOver until announced (the panel never becomes key),
        // so post an explicit announcement for warnings and other messages that need to be heard.
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [.announcement: message.text,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])

        scheduleHide(after: seconds)
        if message.action != nil {
            Task { [weak self, weak panel] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, let panel, self.generation == token, self.panel === panel else { return }
                panel.ignoresMouseEvents = false
            }
        }
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        generation += 1
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

/// The bubble never becomes key and Pip is usually inactive, so: take the first click (no
/// activate-first click), and track hover even when the app isn't active.
private final class BubbleHostingView: NSHostingView<BubbleView> {
    var onHover: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }
}

/// internal for snapshot tests
struct BubbleView: View {
    /// Widest the whole bubble panel gets (including the transparent margin around it).
    static let maxPanelWidth: CGFloat = 260
    private static let margin: CGFloat = 8        // room for the tail and the hover area around the bubble
    private static let padX: CGFloat = 14
    private static let padY: CGFloat = 10

    let message: PipMessage
    let tailPointsDown: Bool
    let tailOffsetX: CGFloat
    let onAction: (PipMessage.Action) -> Void
    let onHover: (Bool) -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12) }

    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: message.text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action = message.action {
                Button(action.title) { onAction(action) }
                    .buttonStyle(BubbleButtonStyle())
                    .accessibilityHint("Runs this action and dismisses the message")
            }
        }
        .frame(maxWidth: Self.maxPanelWidth - 2 * (Self.margin + Self.padX))
        .padding(.horizontal, Self.padX).padding(.vertical, Self.padY)
        .background(.regularMaterial, in: shape)
        .overlay(shape.strokeBorder(.primary.opacity(0.14)))
        .overlay(alignment: tailPointsDown ? .bottom : .top) {
            BubbleTail()
                .fill(.regularMaterial)
                .overlay(BubbleTail().sides.stroke(.primary.opacity(0.14), lineWidth: 1))
                .frame(width: 14, height: 7)
                .rotationEffect(.degrees(tailPointsDown ? 0 : 180))
                .offset(x: tailOffsetX, y: tailPointsDown ? 6 : -6)
        }
        .padding(Self.margin)
        // One solid hover region (bubble + tail + margin) so crossing the tail or gaps can't flicker.
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pip says")
    }
}

/// Small tinted button for the frosted bubble: at least 28pt tall, whole area clickable.
private struct BubbleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    /// Accent, lightened in dark mode so the label stays readable on the dark frosted material.
    private var tint: Color {
        scheme == .dark
            ? Color(nsColor: NSColor.controlAccentColor.blended(withFraction: 0.45, of: .white) ?? .controlAccentColor)
            : Color.accentColor
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minWidth: 56, minHeight: 28)
            .background(shape.fill(tint.opacity(configuration.isPressed ? 0.30 : 0.16)))
            .overlay(shape.strokeBorder(tint.opacity(0.45)))
            .contentShape(shape)
    }
}

/// A small downward-pointing triangle; rotate 180° for an upward-pointing tail.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    /// Just the two slanted edges, so the stroke doesn't draw a seam across the bubble's own border.
    var sides: Path {
        var path = Path()
        let rect = CGRect(x: 0, y: 0, width: 14, height: 7)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
