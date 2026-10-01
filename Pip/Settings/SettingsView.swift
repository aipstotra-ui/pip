import SwiftUI

/// Which Settings tab is showing. Shared with the window controller so a speech-bubble button
/// ("Change Shortcut") can switch tabs even when the window is already open.
@MainActor
@Observable
final class SettingsNavigation {
    var tab: SettingsView.Tab = .apps
}

/// Pip's Settings content: an Apps tab (what's in the ring, in what order) and a Shortcut tab.
struct SettingsView: View {
    enum Tab: Hashable { case apps, shortcut }

    let store: TargetStore
    @Bindable var navigation: SettingsNavigation

    init(store: TargetStore, navigation: SettingsNavigation = SettingsNavigation()) {
        self.store = store
        self.navigation = navigation
    }

    var body: some View {
        TabView(selection: $navigation.tab) {
            AppsSettingsView(store: store)
                .tabItem { Label("Apps", systemImage: "circle.grid.3x3.fill") }
                .tag(Tab.apps)
            ShortcutSettingsView(store: store)
                .tabItem { Label("Shortcut", systemImage: "command") }
                .tag(Tab.shortcut)
        }
        .frame(minWidth: 560, minHeight: 520)
    }
}
