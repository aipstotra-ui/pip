import Foundation

/// Applies the user's order and on/off choices to the registry. Pure, so it's easy to test.
enum TargetArrangement {
    static let ringLimit = 10

    /// Enabled targets: top-level ones in the user's order (unknown/new ones keep catalog order at the end),
    /// each followed by its enabled branch tools. Hiding a parent hides its branch tools too.
    static func visible(_ registry: AppRegistry, preferences: Preferences) -> AppRegistry {
        let top = registry.topLevel
        let rank = Dictionary(preferences.order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = top.enumerated().sorted { lhs, rhs in
            switch (rank[lhs.element.id], rank[rhs.element.id]) {
            case let (l?, r?): l < r
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): lhs.offset < rhs.offset
            }
        }.map(\.element)

        var result: [AITarget] = []
        for parent in ordered where !preferences.hidden.contains(parent.id) {
            result.append(parent)
            result += registry.children(of: parent).filter { !preferences.hidden.contains($0.id) }
        }
        return AppRegistry(targets: result)
    }

    /// What the ring shows: the first `ringLimit` enabled top-level apps and their branch tools.
    static func ring(_ visible: AppRegistry, limit: Int = ringLimit) -> AppRegistry {
        let keep = Set(visible.topLevel.prefix(limit).map(\.id))
        return AppRegistry(targets: visible.targets.filter { keep.contains($0.parent ?? $0.id) })
    }
}
