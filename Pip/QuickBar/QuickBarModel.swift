import AppKit
import Observation

/// One row in the quick bar.
struct QuickBarResult: Identifiable {
    let target: AITarget
    let icon: NSImage?
    /// Where this opens, shown under the name: "App", "Website", "Terminal · Claude".
    let destination: String
    var id: String { target.id }
}

/// State for the quick bar: query, ranked results and the keyboard selection.
@MainActor
@Observable
final class QuickBarModel {
    static let maxVisibleResults = 6

    private let all: [QuickBarResult]
    private(set) var results: [QuickBarResult]
    private(set) var selectedIndex = 0

    var query = "" {
        didSet {
            if query.count > FuzzyMatcher.maxQueryLength { query = String(query.prefix(FuzzyMatcher.maxQueryLength)) }
            refresh()
        }
    }

    init(results: [QuickBarResult]) {
        all = results
        self.results = results
    }

    var selected: QuickBarResult? { results.indices.contains(selectedIndex) ? results[selectedIndex] : nil }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + results.count) % results.count
    }

    func select(_ id: String) {
        if let index = results.firstIndex(where: { $0.id == id }) { selectedIndex = index }
    }

    private func refresh() {
        let ranked = FuzzyMatcher.rank(all.map(\.target), query: query)
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        results = ranked.compactMap { byId[$0.id] }
        selectedIndex = 0
    }
}

extension QuickBarModel {
    /// Builds rows for every target in the registry, including branch tools like Claude Code.
    static func make(from registry: AppRegistry) -> QuickBarModel {
        let names = Dictionary(uniqueKeysWithValues: registry.targets.map { ($0.id, $0.name) })
        let rows = registry.targets.map { target -> QuickBarResult in
            let icon = TargetIcon.appIcon(for: target)
            let destination: String = switch target.kind {
            case .app: icon == nil ? "Website" : "App"
            case .web: "Website"
            case .cli: target.parent.flatMap { names[$0] }.map { "Terminal · \($0)" } ?? "Terminal"
            }
            return QuickBarResult(target: target, icon: icon, destination: destination)
        }
        return QuickBarModel(results: rows)
    }
}
