import SwiftUI

@main
struct PipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Pip has no main window. A Settings scene arrives in M6.
        Settings { EmptyView() }
    }
}
