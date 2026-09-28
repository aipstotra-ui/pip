import Foundation

/// Recently used Claude Code folders, stored as app-scoped security bookmarks (required by the sandbox).
/// Only folders the user explicitly picked in the open panel ever get here.
@MainActor
final class RecentFolders {
    static let maxCount = 5
    private let defaultsKey: String
    private let defaults: UserDefaults

    /// Each tool keeps its own list. Claude Code keeps its original key so existing recents survive.
    init(tool: CLITool, defaults: UserDefaults = .standard) {
        self.defaultsKey = tool == .claude ? "claudeCodeRecentFolderBookmarks" : "\(tool.rawValue)RecentFolderBookmarks"
        self.defaults = defaults
    }

    /// Existing directories only. Missing folders are pruned from storage; stale bookmarks
    /// (folder renamed or moved) still resolve and are refreshed in place.
    var folders: [URL] {
        let stored = defaults.array(forKey: defaultsKey) as? [Data] ?? []
        let resolved = stored.compactMap(resolve)
        let bookmarks = resolved.map(\.bookmark)
        if bookmarks != stored { defaults.set(bookmarks, forKey: defaultsKey) }
        return resolved.map(\.url)
    }

    func add(_ url: URL) {
        guard let data = Self.bookmark(for: url) else { return }
        let key = Self.identity(of: url)
        // Unresolvable entries are dropped here too, so dead bookmarks can't hold slots forever.
        let others = (defaults.array(forKey: defaultsKey) as? [Data] ?? [])
            .compactMap(resolve)
            .filter { Self.identity(of: $0.url) != key }
            .map(\.bookmark)
        defaults.set(Array(([data] + others).prefix(Self.maxCount)), forKey: defaultsKey)
    }

    private static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                              includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Compares folders by real path, ignoring trailing slashes and symlinks (e.g. /tmp vs /private/tmp).
    private static func identity(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func resolve(_ data: Data) -> (url: URL, bookmark: Data)? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        // Re-create a stale bookmark while we hold access; keep the old one if that fails (it still resolves).
        let bookmark = stale ? (Self.bookmark(for: url) ?? data) : data
        return (url, bookmark)
    }
}
