import AppKit
import SwiftUI
import XCTest
@testable import Pip

/// Renders the Settings tabs to PNGs for visual review. Uses a real (off-screen) window because
/// List and TabView are AppKit-backed and come out blank under ImageRenderer. The Apps tab is
/// rendered taller than the real window so every row (and the ring divider) is visible. No pixel assertions.
@MainActor
final class SettingsSnapshotTests: XCTestCase {

    private static let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("pip-settings-preview", isDirectory: true)

    func testRenderSettingsPreviews() throws {
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)
        let suite = "pip.settings.snapshot.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let customURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pip-settings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: customURL) }

        let store = TargetStore(customURL: customURL, defaults: defaults)
        // Enough custom sites to pass the ring limit, plus one switched-off app.
        for (name, address) in [("Perplexity Labs", "labs.example.com"), ("Poe Chat", "poe.example.com"),
                                ("You Search", "you.example.org"), ("Mistral Chat", "mistral.example.net"),
                                ("Pi Talk", "pi.example.io"), ("Kagi Assistant", "kagi.example.dev")] {
            try store.addWebsite(name: name, address: address)
        }
        if let second = store.allTopLevelOrdered.dropFirst().first { store.setHidden(second.id, true) }

        for (tab, name) in [(SettingsView.Tab.apps, "apps"), (.shortcut, "shortcut")] {
            for scheme in [NSAppearance.Name.aqua, .darkAqua] {
                let url = Self.outputDir.appendingPathComponent("settings-\(name)-\(scheme == .darkAqua ? "dark" : "light").png")
                try render(SettingsView(store: store, navigation: { let n = SettingsNavigation(); n.tab = tab; return n }()), appearance: scheme, height: tab == .apps ? 900 : 520, to: url)
                print("Settings preview: \(url.path)")
            }
        }
    }

    private func render(_ view: SettingsView, appearance: NSAppearance.Name, height: CGFloat, to url: URL) throws {
        let size = NSSize(width: 560, height: height)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))   // let List/TabView populate
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: url)
        window.orderOut(nil)
    }
}
