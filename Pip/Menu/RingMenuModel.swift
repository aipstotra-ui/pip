import AppKit
import Observation

struct RingItem: Identifiable {
    let target: AITarget
    let icon: NSImage?
    let position: CGPoint   // center, in the panel's SwiftUI coordinates (y down)
    /// The parent's own entry in its branch ("Claude · Chat"): opens the same target as the ring slot.
    let isChatEntry: Bool
    let id: String

    init(target: AITarget, icon: NSImage?, position: CGPoint, isChatEntry: Bool = false, id: String? = nil) {
        self.target = target
        self.icon = icon
        self.position = position
        self.isChatEntry = isChatEntry
        self.id = id ?? target.id
    }

    /// Where the item leads, shown after its name ("Gemini · Website", "Claude · Chat").
    var destinationSuffix: String? {
        isChatEntry ? "Chat" : Self.destinationSuffix(for: target, hasIcon: icon != nil)
    }

    static func destinationSuffix(for target: AITarget, hasIcon: Bool) -> String? {
        switch target.kind {
        case .web: "Website"
        case .cli: "Terminal"
        case .app: hasIcon ? nil : "Website"   // not installed: opens the website
        }
    }
}

/// The items that grow out of one ring item (its chat entry plus its children), already laid out.
struct RingBranch {
    let parentID: String
    let items: [RingItem]
    /// Point on the fan's center line at the branch radius (panel coordinates); the parent's label goes beyond it.
    let fanCenter: CGPoint
    let placement: BranchLayout.Placement
    /// Parent → item curves, one per item (panel coordinates).
    let connectors: [BranchLayout.Connector]
}

/// Shared selection state for the ring. Mouse hover and keyboard navigation both write here,
/// so the two inputs share one highlight instead of fighting over it.
@MainActor
@Observable
final class RingMenuModel {
    enum Hit: Equatable {
        case ring(String)
        case branch(Int)
        case corridor
        case none
    }

    private(set) var items: [RingItem] = []
    private(set) var branches: [String: RingBranch] = [:]
    var selectedID: String?
    /// The parent whose branch is showing. Only one at a time.
    private(set) var openBranchID: String?
    /// Focus inside the open branch; nil while focus is on the ring.
    private(set) var branchFocus: Int?

    @ObservationIgnored var openDelay: Duration = .milliseconds(120)
    @ObservationIgnored var closeDelay: Duration = .milliseconds(250)
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var pendingOpenID: String?
    @ObservationIgnored private var closeTask: Task<Void, Never>?

    func configure(items: [RingItem], branches: [RingBranch] = []) {
        self.items = items
        self.branches = Dictionary(branches.map { ($0.parentID, $0) }, uniquingKeysWith: { a, _ in a })
        selectedID = items.first?.id
        openBranchID = nil
        branchFocus = nil
    }

    var openBranch: RingBranch? { openBranchID.flatMap { branches[$0] } }

    func hasBranch(_ id: String) -> Bool { branches[id] != nil }

    /// The focused branch item, if focus is inside the open branch.
    var focusedBranchItem: RingItem? {
        guard let branch = openBranch, let i = branchFocus, branch.items.indices.contains(i) else { return nil }
        return branch.items[i]
    }

    var selectedItem: RingItem? { items.first { $0.id == selectedID } }

    /// What Return opens: the focused branch item, else the selected ring item.
    var selectedTarget: AITarget? { (focusedBranchItem ?? selectedItem)?.target }

    // MARK: Branches

    /// Shows `id`'s branch right away (keyboard Tab, VoiceOver action, previews).
    func openBranch(_ id: String) {
        cancelTimers()
        guard branches[id] != nil else { return }
        if openBranchID != id { branchFocus = nil }
        openBranchID = id
    }

    func closeBranch() {
        cancelTimers()
        openBranchID = nil
        branchFocus = nil
    }

    /// Tab: move focus into the selected item's branch. Returns false if it has none.
    @discardableResult func enterBranch() -> Bool {
        if branchFocus != nil { moveClockwise(); return true }   // Tab inside a branch: next item
        guard let id = selectedID, hasBranch(id) else { return false }
        openBranch(id)
        branchFocus = 0
        return true
    }

    /// Shift-Tab / Esc: focus back on the ring (the branch stays open while its parent is selected).
    @discardableResult func leaveBranch() -> Bool {
        guard branchFocus != nil else { return false }
        branchFocus = nil
        return true
    }

    // MARK: Pointer

    /// Mouse entered a ring item: it becomes the shared selection, and its branch (if any) opens after a pause.
    func hover(_ id: String) {
        if selectedID != id { selectedID = id }
        if branchFocus != nil { branchFocus = nil }
        if openBranchID == id { cancelTimers(); return }
        if openBranchID != nil { scheduleClose() }
        if hasBranch(id) { scheduleOpen(id) } else { cancelOpen() }
    }

    /// Pointer moved inside the panel (nil: it left the panel or the menu's shapes).
    func pointerMoved(to point: CGPoint?) {
        switch point.map(hitTest) ?? Hit.none {
        case .branch(let i):
            cancelTimers()
            if branchFocus != i { branchFocus = i }
        case .ring(let id):
            hover(id)
        case .corridor:
            // Heading for the open branch: drop any open queued by grazing a neighbour on the way,
            // and give the selection back to the branch's parent.
            cancelTimers()
            if let open = openBranchID, selectedID != open { selectedID = open }
        case .none:
            cancelOpen()
            if openBranchID != nil { scheduleClose() }
        }
    }

    /// Branch items first (they're drawn on top), then ring slots, then the open branch's corridor.
    func hitTest(_ p: CGPoint) -> Hit {
        if let branch = openBranch,
           let i = branch.items.firstIndex(where: { distance($0.position, p) <= BranchLayout.pad / 2 }) {
            return .branch(i)
        }
        if let item = items.first(where: { distance($0.position, p) <= RingMetrics.slot / 2 + 4 }) {
            return .ring(item.id)
        }
        if let branch = openBranch,
           BranchLayout.corridorContains(p, connectors: branch.connectors, points: branch.items.map(\.position)) {
            return .corridor
        }
        return .none
    }

    /// Whether a click at `p` lands on the menu (band near a slot, open branch, or its connectors).
    /// Anything else in the panel counts as a click outside.
    func isOnMenu(_ p: CGPoint) -> Bool {
        let reach = RingMetrics.band / 2 + 6   // covers the band between neighbours
        if items.contains(where: { distance($0.position, p) <= reach }) { return true }
        switch hitTest(p) {
        case .branch, .corridor: return true
        case .ring, .none: return false
        }
    }

    // MARK: Keyboard

    /// Right/Down: next item clockwise (in the branch when focus is there).
    func moveClockwise() { move(by: 1) }

    /// Left/Up: previous item, counter-clockwise.
    func moveCounterClockwise() { move(by: -1) }

    private func move(by delta: Int) {
        if let branch = openBranch, let i = branchFocus {
            let n = branch.items.count
            branchFocus = ((i + delta) % n + n) % n
            return
        }
        guard !items.isEmpty else { return }
        let count = items.count
        let current = selectedID.flatMap { id in items.firstIndex { $0.id == id } } ?? 0
        let next = items[((current + delta) % count + count) % count].id
        selectedID = next
        // Keyboard moves are deliberate: drop the old branch now, show the new one after the usual pause.
        cancelTimers()
        if openBranchID != next { openBranchID = nil }
        if hasBranch(next) { scheduleOpen(next) }
    }

    // MARK: Timers

    private func scheduleOpen(_ id: String) {
        guard pendingOpenID != id else { return }
        openTask?.cancel()
        pendingOpenID = id
        let delay = openDelay
        openTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.selectedID == id else { return }
            self.openBranch(id)
        }
    }

    private func scheduleClose() {
        guard closeTask == nil else { return }
        let delay = closeDelay
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.closeTask = nil
            self.openBranchID = nil
            self.branchFocus = nil
        }
    }

    private func cancelOpen() {
        openTask?.cancel(); openTask = nil; pendingOpenID = nil
    }

    /// Stops pending open/close timers (also called when the ring closes).
    func cancelTimers() {
        cancelOpen()
        closeTask?.cancel(); closeTask = nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
