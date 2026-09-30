import Foundation
import Observation

/// The one place that holds the AI targets and the user's Settings choices.
/// The ring and quick bar read from it each time they open, so changes apply immediately.
@MainActor
@Observable
final class TargetStore {
    private(set) var registry: AppRegistry
    private(set) var preferences: Preferences
    /// Set by the app to (re)register the global shortcut; returns false if registration failed.
    @ObservationIgnored var applyHotKey: ((HotKey.Combo) -> Bool)?
    /// Set by the app to pause (true) or resume (false) the global shortcut while a new one is being recorded,
    /// so pressing the current combo reaches the recorder instead of opening the quick bar.
    @ObservationIgnored var suspendHotKey: ((Bool) -> Void)?

    @ObservationIgnored private let catalogIds: Set<String>
    @ObservationIgnored private let customURL: URL?
    @ObservationIgnored private let defaults: UserDefaults

    init(bundle: Bundle = .main, customURL: URL? = AppRegistry.defaultCustomURL, defaults: UserDefaults = .standard) {
        self.customURL = customURL
        self.defaults = defaults
        catalogIds = Set(AppRegistry.load(bundle: bundle, customURL: nil).targets.map(\.id))
        registry = AppRegistry.load(bundle: bundle, customURL: customURL)
        preferences = Preferences.load(from: defaults)
    }

    /// Enabled targets in the user's order (quick bar).
    var visible: AppRegistry { TargetArrangement.visible(registry, preferences: preferences) }
    /// What the ring shows (first 10 enabled apps).
    var ring: AppRegistry { TargetArrangement.ring(visible) }
    /// Every top-level target in the user's order, including hidden ones (for the Settings list).
    var allTopLevelOrdered: [AITarget] {
        var everything = preferences
        everything.hidden = []
        return TargetArrangement.visible(registry, preferences: everything).topLevel
    }
    var customTargets: [AITarget] { registry.targets.filter { !catalogIds.contains($0.id) } }
    func isCustom(_ target: AITarget) -> Bool { !catalogIds.contains(target.id) }
    var hotKey: HotKey.Combo { preferences.hotKey ?? HotKey.quickBarDefault }

    // MARK: Preferences

    func setHidden(_ id: String, _ hidden: Bool) {
        update { if hidden { $0.hidden.insert(id) } else { $0.hidden.remove(id) } }
    }

    func setPreferWeb(_ id: String, _ preferWeb: Bool) {
        update { if preferWeb { $0.preferWeb.insert(id) } else { $0.preferWeb.remove(id) } }
    }

    /// Reorders the top-level list shown in Settings (SwiftUI `onMove` semantics).
    func moveTopLevel(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = allTopLevelOrdered.map(\.id)
        let moving = source.sorted().map { ids[$0] }
        ids.removeAll { moving.contains($0) }
        let insertAt = destination - source.filter { $0 < destination }.count
        ids.insert(contentsOf: moving, at: max(0, min(insertAt, ids.count)))
        update { $0.order = ids }
    }

    /// Registers the new shortcut first; only saves it if macOS accepted it.
    @discardableResult
    func setHotKey(_ combo: HotKey.Combo?) -> Bool {
        let target = combo ?? HotKey.quickBarDefault
        guard target.isUsable, applyHotKey?(target) ?? true else { return false }
        update { $0.hotKey = combo }
        return true
    }

    private func update(_ change: (inout Preferences) -> Void) {
        var next = preferences
        change(&next)
        preferences = next.sanitized()
        preferences.save(to: defaults)
    }

    // MARK: Custom entries

    /// Verifies the app's signature off the main thread (it can take seconds for large apps).
    func addApp(at url: URL) async throws {
        guard customTargets.count < CustomTargets.maxCustom else { throw CustomTargets.AddError.full }
        let registry = self.registry
        let target = try await Task.detached(priority: .userInitiated) {
            try CustomTargets.makeApp(at: url, existing: registry)
        }.value
        try saveCustom(customTargets + [target])
    }

    func addWebsite(name: String, address: String) throws {
        guard customTargets.count < CustomTargets.maxCustom else { throw CustomTargets.AddError.full }
        let target = try CustomTargets.makeWebsite(name: name, address: address, existing: registry)
        try saveCustom(customTargets + [target])
    }

    func removeCustom(id: String) throws {
        try saveCustom(customTargets.filter { $0.id != id })
        update { $0.hidden.remove(id); $0.preferWeb.remove(id); $0.order.removeAll { $0 == id } }
    }

    private func saveCustom(_ targets: [AITarget]) throws {
        try CustomTargets.save(targets, to: customURL)
        registry = AppRegistry.load(customURL: customURL)
    }
}
