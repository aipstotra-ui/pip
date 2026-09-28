import Foundation

/// Security gate for catalog entries. Anything that fails is dropped before Pip can act on it.
enum TargetValidator {
    enum Source { case bundled, user }

    static let maxAliases = 10
    static let maxBundleIds = 5

    static func isValid(_ t: AITarget, source: Source) -> Bool {
        guard matches(t.id, #"^[a-z0-9-]{1,40}$"#),
              isSafeLabel(t.name, maxLength: 60),
              t.aliases.count <= maxAliases,
              t.aliases.allSatisfy({ isSafeLabel($0, maxLength: 40) }),
              t.bundleIds.count <= maxBundleIds,
              t.bundleIds.allSatisfy({ matches($0, #"^[A-Za-z0-9][A-Za-z0-9.-]{0,154}$"#) }),
              t.teamId.map({ matches($0, #"^[A-Z0-9]{10}$"#) }) ?? true,
              isSafeWebURL(t.webURL)
        else { return false }

        // Grouping is a bundled-catalog feature; user files can't attach entries under built-in ones.
        if let parent = t.parent {
            guard source == .bundled, parent != t.id, matches(parent, #"^[a-z0-9-]{1,40}$"#) else { return false }
        }

        switch t.kind {
        case .cli: return source == .bundled && t.cli != nil   // user files can never define commands
        case .app: return !t.bundleIds.isEmpty && t.cli == nil
        case .web: return t.cli == nil
        }
    }

    /// https only, with a real host and no embedded credentials (blocks `https://chatgpt.com@evil.example`).
    static func isSafeWebURL(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == "https",
              let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil
        else { return false }
        return true
    }

    /// Bidi overrides/isolates can make a name display as something else (e.g. "Claude" hiding another label).
    private static let bidiControls = CharacterSet(charactersIn: "\u{200E}\u{200F}\u{061C}")
        .union(CharacterSet(charactersIn: UnicodeScalar(0x202A)!...UnicodeScalar(0x202E)!))
        .union(CharacterSet(charactersIn: UnicodeScalar(0x2066)!...UnicodeScalar(0x2069)!))

    private static func isSafeLabel(_ s: String, maxLength: Int) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && s.count <= maxLength
            && s.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0) && !bidiControls.contains($0)
            }
    }

    private static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }
}
