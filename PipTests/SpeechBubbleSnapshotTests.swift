import AppKit
import SwiftUI
import XCTest
@testable import Pip

/// Renders BubbleView states to PNGs for visual review (temp dir `pip-bubble-preview/`). No pixel assertions;
/// only checks that the hosting view's fitting size includes the button and stays within the width cap.
@MainActor
final class SpeechBubbleSnapshotTests: XCTestCase {

    private static let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("pip-bubble-preview", isDirectory: true)

    private static let long = "Pip couldn't open Terminal for this app because Automation permission is turned off. "
        + "Turn it on in System Settings, then try again."

    private var cases: [(name: String, message: PipMessage, down: Bool)] {
        [("text-only", PipMessage("Opening ChatGPT…"), true),
         ("action-system-settings", PipMessage("Terminal access is off.", action: .openAutomationSettings), true),
         ("action-change-shortcut", PipMessage("That shortcut is taken.", action: .openPipSettings(.shortcut)), true),
         ("action-settings", PipMessage("No apps are on the ring.", action: .openPipSettings(.apps)), true),
         ("action-try-again", PipMessage("Couldn't open Claude.", action: .retry(targetID: "claude")), true),
         ("long-with-button", PipMessage(Self.long, action: .openAutomationSettings), true),
         ("tail-up", PipMessage("Couldn't open Claude.", action: .retry(targetID: "claude")), false)]
    }

    func testRenderBubblePreviews() throws {
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)
        for c in cases {
            let host = NSHostingView(rootView: bubble(c.message, down: c.down))
            let size = host.fittingSize
            XCTAssertLessThanOrEqual(size.width, BubbleView.maxPanelWidth, c.name)
            if c.message.action != nil {
                // text + gap + 28pt button + bubble padding + margins
                XCTAssertGreaterThanOrEqual(size.height, 28 + 20 + 16 + 14, c.name)
            }
            for scheme in [NSAppearance.Name.aqua, .darkAqua] {
                let url = Self.outputDir.appendingPathComponent("bubble-\(c.name)-\(scheme == .darkAqua ? "dark" : "light").png")
                try render(c.message, down: c.down, appearance: scheme, to: url)
                print("Bubble preview: \(url.path)")
            }
        }
    }

    private func bubble(_ m: PipMessage, down: Bool) -> BubbleView {
        BubbleView(message: m, tailPointsDown: down, tailOffsetX: 0, onAction: { _ in }, onHover: { _ in })
    }

    private func render(_ m: PipMessage, down: Bool, appearance: NSAppearance.Name, to url: URL) throws {
        let dark = appearance == .darkAqua
        // A stand-in desktop behind the bubble plus a dot for Pip, so the material and tail read in context.
        let scene = VStack(spacing: 0) {
            if down { bubble(m, down: true); Circle().fill(.orange).frame(width: 20, height: 20) }
            else { Circle().fill(.orange).frame(width: 20, height: 20); bubble(m, down: false) }
        }
        .padding(16)
        .background(LinearGradient(colors: dark ? [.indigo.opacity(0.6), .black] : [.cyan.opacity(0.5), .white],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        let host = NSHostingView(rootView: scene)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: url)
        window.orderOut(nil)
    }
}
