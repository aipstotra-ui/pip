import AppKit
import SwiftUI

/// A short message Pip "says" above itself, e.g. a security warning or a failed launch. Auto-hides.
@MainActor
final class SpeechBubble {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, above petFrame: NSRect, for seconds: Double = 5) {
        hide()
        let host = NSHostingView(rootView: BubbleView(message: message, tailPointsDown: true, tailOffsetX: 0))
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
        let maxTailOffset = max(size.width / 2 - 14, 0)
        let tailOffsetX = min(max(petFrame.midX - (origin.x + size.width / 2), -maxTailOffset), maxTailOffset)
        host.rootView = BubbleView(message: message, tailPointsDown: tailPointsDown, tailOffsetX: tailOffsetX)

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
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
                             userInfo: [.announcement: message,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct BubbleView: View {
    let message: String
    let tailPointsDown: Bool
    let tailOffsetX: CGFloat

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10) }

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 240)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(.black.opacity(0.15)))
            .overlay(alignment: tailPointsDown ? .bottom : .top) {
                BubbleTail()
                    .fill(.regularMaterial)
                    .overlay(BubbleTail().stroke(.black.opacity(0.15), lineWidth: 1))
                    .frame(width: 14, height: 7)
                    .rotationEffect(.degrees(tailPointsDown ? 0 : 180))
                    .offset(x: tailOffsetX, y: tailPointsDown ? 6 : -6)
            }
            .padding(4)
            .accessibilityAddTraits(.updatesFrequently)
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
}
