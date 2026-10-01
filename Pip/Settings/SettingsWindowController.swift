import AppKit
import SwiftUI

/// Owns Pip's Settings window. Pip is a menu-bar app, so it activates itself while the window is shown.
@MainActor
final class SettingsWindowController {
    private let store: TargetStore
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(store: TargetStore) {
        self.store = store
    }

    func show(tab: SettingsView.Tab? = nil) {
        if let tab { navigation.tab = tab }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Pip Settings"
            window.isReleasedWhenClosed = false
            // Reopening from another Space brings the window here instead of switching Spaces.
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.contentView = NSHostingView(rootView: SettingsView(store: store, navigation: navigation))
            window.center()
            window.setFrameAutosaveName("PipSettingsWindow")
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        // macOS 14 activation is cooperative and can be declined; still bring the window above other apps.
        window?.orderFrontRegardless()
    }
}
