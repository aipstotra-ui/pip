import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut, registered with Carbon's `RegisterEventHotKey`.
///
/// Privacy: macOS delivers only the registered key combination to Pip. No other keystrokes are
/// observed, and no Accessibility or Input Monitoring permission is needed (works in the sandbox).
@MainActor
final class HotKey {
    struct Combo: Equatable, Sendable, Codable {
        let keyCode: UInt32     // virtual key code, e.g. kVK_Space
        let modifiers: UInt32   // Carbon modifier mask, e.g. controlKey | optionKey

        /// Needs ⌃, ⌥ or ⌘ (Shift alone would steal ordinary typing), and a key that isn't Esc.
        var isUsable: Bool {
            let strong = UInt32(controlKey | optionKey | cmdKey)
            return modifiers & strong != 0 && keyCode != UInt32(kVK_Escape) && keyCode <= 0x7F
        }

        /// From a key press in the shortcut recorder.
        init?(event: NSEvent) {
            guard event.type == .keyDown else { return nil }
            var mods: UInt32 = 0
            let flags = event.modifierFlags
            if flags.contains(.control) { mods |= UInt32(controlKey) }
            if flags.contains(.option) { mods |= UInt32(optionKey) }
            if flags.contains(.shift) { mods |= UInt32(shiftKey) }
            if flags.contains(.command) { mods |= UInt32(cmdKey) }
            self.init(keyCode: UInt32(event.keyCode), modifiers: mods)
        }

        init(keyCode: UInt32, modifiers: UInt32) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }

        /// e.g. "⌃⌥Space".
        var displayString: String {
            var s = ""
            if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
            if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
            if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
            if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
            return s + HotKey.keyName(for: keyCode)
        }
    }

    /// A readable name for a virtual key code, using the current keyboard layout for character keys.
    nonisolated static func keyName(for keyCode: UInt32) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
            kVK_F19: "F19", kVK_F20: "F20",
        ]
        if let name = special[Int(keyCode)] { return name }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }
        let layout = unsafeBitCast(raw, to: CFData.self) as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layout.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(base, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
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
