import Foundation

/// Creates, saves and removes the user's own entries in custom.json.
/// Everything is validated with the same rules as the catalog before it's written.
enum CustomTargets {
    enum AddError: LocalizedError, Equatable {
        case notAnApp, untrusted, duplicate(String), invalidName, invalidURL, full

        var errorDescription: String? {
            switch self {
            case .notAnApp: "That doesn't look like a Mac app."
            case .untrusted: "That app isn't signed by an identified developer or the App Store, so Pip won't launch it."
            case .duplicate(let name): "Pip already has \(name)."
            case .invalidName: "Please use a shorter name without special characters."
            case .invalidURL: "Use a full https:// address, like https://example.com."
            case .full: "You've reached the limit of custom entries."
            }
        }
    }

    static let maxCustom = 50

    /// An installed app the user picked. Its bundle id and signing team are recorded now, so later
    /// launches only accept that exact signed app.
    static func makeApp(at url: URL, existing registry: AppRegistry) throws -> AITarget {
        guard url.pathExtension == "app", let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else {
            throw AddError.notAnApp
        }
        if let taken = registry.targets.first(where: { $0.bundleIds.contains { $0.caseInsensitiveCompare(bundleId) == .orderedSame } }) {
            throw AddError.duplicate(taken.name)
        }
        guard let team = CodeTrust.pinnedTeam(forAppAt: url, bundleId: bundleId) else { throw AddError.untrusted }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let target = AITarget(id: makeId(name, existing: registry), name: String(name.prefix(60)),
                              bundleIds: [bundleId], teamId: team, webURL: nil, kind: .app)
        try check(target, against: registry)
        return target
    }

    /// A website the user typed in.
    static func makeWebsite(name rawName: String, address rawAddress: String, existing registry: AppRegistry) throws -> AITarget {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        var address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") { address = "https://" + address }
        guard let url = URL(string: address), TargetValidator.isSafeWebURL(url) else { throw AddError.invalidURL }
        guard !name.isEmpty else { throw AddError.invalidName }
        let target = AITarget(id: makeId(name, existing: registry), name: name, webURL: url, kind: .web)
        try check(target, against: registry)
        return target
    }

    private static func check(_ target: AITarget, against registry: AppRegistry) throws {
        guard registry.targets.filter({ $0.id.hasPrefix("custom-") }).count < maxCustom else { throw AddError.full }
        guard TargetValidator.isValid(target, source: .user) else { throw AddError.invalidName }
        // Same look-alike rule as AppRegistry.merge: no reusing any existing name or alias.
        let newLabels = Set(AppRegistry.labels(of: target))
        if let clash = registry.targets.first(where: { !newLabels.isDisjoint(with: AppRegistry.labels(of: $0)) }) {
            throw AddError.duplicate(clash.name)
        }
    }

    /// "custom-<slug>", made unique against existing ids.
    static func makeId(_ name: String, existing registry: AppRegistry) -> String {
        let slug = name.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .map { ($0.isASCII && ($0.isLetter || $0.isNumber)) ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        let base = "custom-" + String((slug.isEmpty ? "item" : slug).prefix(26))
        let ids = Set(registry.targets.map(\.id))
        var candidate = base
        var n = 2
        while ids.contains(candidate) { candidate = "\(base)-\(n)"; n += 1 }
        return candidate
    }

    /// Writes the user's entries atomically, readable only by this user (0600) in Pip's container.
    static func save(_ targets: [AITarget], to url: URL? = AppRegistry.defaultCustomURL) throws {
        guard let url else { return }
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard targets.count <= maxCustom else { throw AddError.full }
        let data = try encoder.encode(targets)
        guard data.count <= AppRegistry.maxFileBytes else { throw AddError.full }
        // Write a 0600 temp file next to the target, then rename over it: the file is never
        // visible at its final path with looser permissions, and readers never see a half write.
        let temp = dir.appendingPathComponent(".custom-\(UUID().uuidString).json")
        guard FileManager.default.createFile(atPath: temp.path, contents: data,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        guard rename(temp.path, url.path) == 0 else {
            try? FileManager.default.removeItem(at: temp)
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
