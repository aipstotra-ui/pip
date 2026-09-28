import Foundation
import os

/// The list of AI targets Pip offers: bundled catalog.json merged with the user's optional custom.json.
struct AppRegistry: Sendable {
    static let maxFileBytes = 256 * 1024
    static let maxEntries = 100
    private static let log = Logger(subsystem: "com.pipapp.Pip", category: "registry")

    let targets: [AITarget]

    init(targets: [AITarget]) {
        // A child needs an existing top-level parent; anything else is dropped (no deeper nesting).
        let topLevelIds = Set(targets.filter { $0.parent == nil }.map(\.id))
        self.targets = targets.filter { $0.parent.map(topLevelIds.contains) ?? true }
    }

    /// Items shown on the ring itself.
    var topLevel: [AITarget] { targets.filter { $0.parent == nil } }

    /// Items that branch out of `parent` when it's hovered, in catalog order.
    func children(of parent: AITarget) -> [AITarget] {
        targets.filter { $0.parent == parent.id }
    }

    static var defaultCustomURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Pip/custom.json")
    }

    static func load(bundle: Bundle = .main, customURL: URL? = defaultCustomURL) -> AppRegistry {
        let catalog = bundle.url(forResource: "catalog", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .map { decode($0, source: .bundled) } ?? []
        let custom = customURL.flatMap(readUserFile).map { decode($0, source: .user) } ?? []
        return AppRegistry(targets: merge(catalog: catalog, custom: custom))
    }

    /// Decodes and validates entries. Invalid entries are dropped. Only counts are logged, never contents.
    static func decode(_ data: Data, source: TargetValidator.Source) -> [AITarget] {
        // Decode entry by entry so one bad entry doesn't discard the whole file.
        guard data.count <= maxFileBytes,
              let lenient = try? JSONDecoder().decode([Lenient].self, from: data)
        else {
            log.error("Ignored unreadable \(source == .bundled ? "catalog" : "custom", privacy: .public) file")
            return []
        }
        let all = lenient.compactMap(\.target)
        var seen = Set<String>()
        let valid = all.prefix(maxEntries).filter {
            TargetValidator.isValid($0, source: source) && seen.insert($0.id).inserted
        }
        if valid.count != lenient.count {
            log.notice("Dropped \(lenient.count - valid.count, privacy: .public) invalid or duplicate entries")
        }
        return valid
    }

    /// User entries are added after the catalog. They can't replace built-in entries, so a user file
    /// can never swap a pinned app or the Claude Code command for something else.
    /// They also can't reuse a built-in name or alias, so a custom "ChatGPT" can't point somewhere else.
    static func merge(catalog: [AITarget], custom: [AITarget]) -> [AITarget] {
        let catalogIds = Set(catalog.map(\.id))
        let catalogLabels = Set(catalog.flatMap(labels))
        return catalog + custom.filter {
            !catalogIds.contains($0.id) && catalogLabels.isDisjoint(with: labels(of: $0))
        }
    }

    /// Case-, width- and diacritic-folded names and aliases without spaces, used to detect look-alike entries.
    static func labels(of target: AITarget) -> [String] {
        ([target.name] + target.aliases).map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .filter { !$0.isWhitespace }
        }
    }

    /// Decodes one array element without failing the whole array.
    private struct Lenient: Decodable {
        let target: AITarget?
        init(from decoder: Decoder) throws {
            target = try? AITarget(from: decoder)
        }
    }

    /// Reads custom.json only if it's a regular file (not a symlink), owned by this user,
    /// not writable by group or others, and small enough. The checks and the read use one
    /// file descriptor opened with O_NOFOLLOW, so the file can't be swapped in between.
    static func readUserFile(at url: URL) -> Data? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var st = stat()
        guard fstat(fd, &st) == 0,
              st.st_mode & S_IFMT == S_IFREG,
              st.st_uid == getuid(),
              st.st_mode & 0o022 == 0,
              st.st_size <= maxFileBytes
        else { return nil }
        guard let data = try? handle.read(upToCount: maxFileBytes + 1), data.count <= maxFileBytes else { return nil }
        return data
    }
}
