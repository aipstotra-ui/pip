import Foundation

/// The user's choices from Settings. Stored as JSON in UserDefaults and validated on load,
/// so a hand-edited or corrupted value can never smuggle in anything but known-shape data.
struct Preferences: Codable, Equatable, Sendable {
    /// Top-level target ids in the user's order. Unknown ids are ignored; missing ones go last.
    var order: [String] = []
    /// Ids the user turned off (top-level apps or branch tools).
    var hidden: Set<String> = []
    /// App ids the user wants opened as their website instead of the app.
    var preferWeb: Set<String> = []
    /// Quick bar shortcut; nil means the default ⌃⌥Space.
    var hotKey: HotKey.Combo?

    static let maxIds = 200
    private static let defaultsKey = "pip.preferences"

    static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: defaultsKey), data.count <= 64 * 1024,
              let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return Preferences() }
        return decoded.sanitized()
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(sanitized()) { defaults.set(data, forKey: Self.defaultsKey) }
    }

    /// Keeps only well-formed ids (same rule as catalog ids), caps sizes, and drops unusable shortcuts.
    func sanitized() -> Preferences {
        func valid(_ id: String) -> Bool { id.range(of: #"^[a-z0-9-]{1,40}$"#, options: .regularExpression) != nil }
        var seen = Set<String>()
        return Preferences(
            order: Array(order.filter { valid($0) && seen.insert($0).inserted }.prefix(Self.maxIds)),
            hidden: Set(hidden.filter(valid).prefix(Self.maxIds)),
            preferWeb: Set(preferWeb.filter(valid).prefix(Self.maxIds)),
            hotKey: hotKey.flatMap { $0.isUsable ? $0 : nil }
        )
    }
}
