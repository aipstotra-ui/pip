import AppKit
import SwiftUI

/// Drives the shortcut recorder. A local key-down monitor exists only while recording,
/// so Pip never sees keystrokes outside that moment (and only inside its own window).
@MainActor
@Observable
final class ShortcutRecorderModel {
    private(set) var isRecording = false
    private(set) var message: String?
    @ObservationIgnored private var monitor: Any?
    /// Stops recording when the Settings window loses focus or closes (only that window, not any window).
    @ObservationIgnored private var windowObservers: [NSObjectProtocol] = []
    /// The store whose global shortcut is paused while recording.
    @ObservationIgnored private var suspendedStore: TargetStore?

    func toggle(store: TargetStore) {
        isRecording ? stop() : start(store: store)
    }

    func start(store: TargetStore) {
        stop()
        message = nil
        isRecording = true
        // Pause the live shortcut so pressing it (e.g. to re-pick it) reaches the recorder.
        store.suspendHotKey?(true)
        suspendedStore = store
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = event.keyCode
            let combo = HotKey.Combo(event: event)
            let consumed = MainActor.assumeIsolated { self.handle(keyCode: keyCode, combo: combo, store: store) }
            return consumed ? nil : event
        }
        if let window = NSApp.keyWindow {
            for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(
                    forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.stop() }
                })
            }
        }
    }

    /// Safe to call on any exit path (Esc, a recorded key, tab switch, window close); restores the shortcut.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers = []
        suspendedStore?.suspendHotKey?(false)
        suspendedStore = nil
        isRecording = false
    }

    func clearMessage() { message = nil }

    /// Returns true when the event was consumed.
    private func handle(keyCode: UInt16, combo: HotKey.Combo?, store: TargetStore) -> Bool {
        guard isRecording else { return false }
        if keyCode == 53 {   // Esc cancels
            stop()
            return true
        }
        guard let combo, combo.isUsable else {
            message = "Use ⌃, ⌥ or ⌘ with a key"
            return true
        }
        if store.setHotKey(combo) {
            message = nil
        } else {
            message = "That shortcut isn't available"
        }
        stop()
        return true
    }
}

/// A button showing the current shortcut. Click it, then press a new combination.
struct ShortcutRecorderButton: View {
    let store: TargetStore
    let model: ShortcutRecorderModel

    var body: some View {
        Button { model.toggle(store: store) } label: {
            Text(verbatim: model.isRecording ? "Type shortcut…" : store.hotKey.displayString)
                .font(.body.weight(.medium))
                .foregroundStyle(model.isRecording ? .secondary : .primary)
                .frame(minWidth: 130, minHeight: 28)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.primary.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(model.isRecording ? Color.accentColor : Color.primary.opacity(0.15),
                                      lineWidth: model.isRecording ? 2 : 0.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "Quick bar shortcut, \(store.hotKey.displayString)"))
        .accessibilityHint(Text(verbatim: model.isRecording ? "Press the new shortcut, or Escape to cancel"
                                                            : "Activate, then press a new shortcut"))
        .onDisappear { model.stop() }
    }
}
