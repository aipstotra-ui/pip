import SwiftUI

/// Pip's Settings content: an Apps tab (what's in the ring, in what order) and a Shortcut tab.
struct SettingsView: View {
    enum Tab: Hashable { case apps, shortcut }

    let store: TargetStore
    @State private var tab: Tab

    init(store: TargetStore, initialTab: Tab = .apps) {
        self.store = store
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $tab) {
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
