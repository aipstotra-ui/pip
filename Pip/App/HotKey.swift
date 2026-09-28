import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut, registered with Carbon's `RegisterEventHotKey`.
///
/// Privacy: macOS delivers only the registered key combination to Pip. No other keystrokes are
/// observed, and no Accessibility or Input Monitoring permission is needed (works in the sandbox).
@MainActor
final class HotKey {
    struct Combo: Equatable, Sendable {
        let keyCode: UInt32     // virtual key code, e.g. kVK_Space
        let modifiers: UInt32   // Carbon modifier mask, e.g. controlKey | optionKey
    }

    /// ⌃⌥Space. (⌥Space is the ChatGPT desktop app's default, so Pip avoids it.)
    static let quickBarDefault = Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))

    private static let signature: OSType = 0x5049_5030   // 'PIP0'
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private var ref: EventHotKeyRef?

    /// Returns nil if the combination couldn't be registered. Note: Carbon only rejects duplicates
    /// within this process; if another app (or a system shortcut) owns the combo, registration
    /// still succeeds and whichever grabs it first wins, so a non-nil result isn't proof it works.
    init?(_ combo: Combo, action: @escaping () -> Void) {
        // Without the handler the key would be grabbed system-wide but never acted on.
        guard Self.installHandlerIfNeeded() else { return nil }
        id = Self.nextID
        Self.nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers,
                                         EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        self.ref = ref
        Self.actions[id] = action
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.actions[id] = nil
    }

    private static func installHandlerIfNeeded() -> Bool {
        guard !handlerInstalled else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, hotKeyID.signature == HotKey.signature else { return OSStatus(eventNotHandledErr) }
            let id = hotKeyID.id
            DispatchQueue.main.async {
                MainActor.assumeIsolated { HotKey.actions[id]?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = (status == noErr)
        return handlerInstalled
    }
}
