import SwiftUI

@main
struct PipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Pip has no main window, and its Settings window is SettingsWindowController.
        // The required scene stays empty and its menu command is removed, so ⌘, can't open a blank window.
        Settings { EmptyView() }
            .commandsRemoved()
    }
}
