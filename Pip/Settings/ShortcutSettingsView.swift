import SwiftUI

/// The Shortcut tab: which key combination opens the quick bar.
struct ShortcutSettingsView: View {
    let store: TargetStore
    @State private var recorder = ShortcutRecorderModel()

    private var isDefault: Bool { store.hotKey == HotKey.quickBarDefault }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Text("Open the quick bar")
                    Spacer(minLength: 12)
                    ShortcutRecorderButton(store: store, model: recorder)
                    Button("Reset to \(HotKey.quickBarDefault.displayString)") {
                        recorder.stop()
                        recorder.clearMessage()
                        store.setHotKey(nil)
                    }
                    .disabled(isDefault)
                    .frame(minHeight: 28)
                }
                if let message = recorder.message {
                    Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Click the shortcut, then press the keys you want. Esc cancels.")
                    Text("⌃⌥Space is also macOS's “next input source” shortcut, which is off by default on many Macs. ⌥Space is ChatGPT's shortcut, so Pip avoids it.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }
        }
        .formStyle(.grouped)
    }
}
