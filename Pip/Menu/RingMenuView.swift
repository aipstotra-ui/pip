import Observation
import SwiftUI

struct RingItem: Identifiable {
    let target: AITarget
    let icon: NSImage?
    let position: CGPoint   // center, in the panel's SwiftUI coordinates (y down)
    var id: String { target.id }
}

/// Shared selection state for the ring. Mouse hover and keyboard navigation both write
/// `selectedID` here, so the two inputs share one highlight instead of fighting over it.
@MainActor
@Observable
final class RingMenuModel {
    private(set) var items: [RingItem] = []
    var selectedID: String?

    func configure(items: [RingItem]) {
        self.items = items
        selectedID = items.first?.id
    }

    var selectedTarget: AITarget? {
        items.first { $0.id == selectedID }?.target
    }

    /// Mouse entered an item: it becomes the shared selection.
    func hover(_ id: String) {
        selectedID = id
    }

    /// Right/Down: next item, clockwise (the order `RingLayout` already lays out items in).
    func moveClockwise() { move(by: 1) }

    /// Left/Up: previous item, counter-clockwise.
    func moveCounterClockwise() { move(by: -1) }

    private func move(by delta: Int) {
        guard !items.isEmpty else { return }
        let count = items.count
        let current = selectedID.flatMap { id in items.firstIndex { $0.id == id } } ?? 0
        let next = ((current + delta) % count + count) % count
        selectedID = items[next].id
    }
}

/// The ring of AI app buttons shown around Pip.
struct RingMenuView: View {
    let model: RingMenuModel
    let onSelect: (AITarget) -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                button(for: item)
                    .position(item.position)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.4, anchor: .center)
                    .opacity(shown ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16).delay(Double(index) * 0.015), value: shown)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { shown = true }
    }

    private func button(for item: RingItem) -> some View {
        let isSelected = model.selectedID == item.id
        return Button { onSelect(item.target) } label: {
            RingIcon(item: item, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in if hovering { model.hover(item.id) } }
        .overlay(alignment: .top) {
            if isSelected {
                Text(item.target.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.75), in: Capsule())
                    .foregroundStyle(.white)
                    .fixedSize()
                    .offset(y: -20)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(item.target.name)
        .accessibilityHint(accessibilityHint(for: item))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Says what activating the item will do, since the kind (and whether the app is installed)
    /// decides whether it opens the app, falls back to the website, or opens Terminal.
    private func accessibilityHint(for item: RingItem) -> String {
        switch item.target.kind {
        case .cli: return "Opens Terminal"
        case .web: return "Opens the website"
        case .app: return item.icon == nil ? "Opens the website" : "Opens the app"
        }
    }
}

private struct RingIcon: View {
    let item: RingItem
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10, style: .continuous) }

    var body: some View {
        ZStack {
            shape.fill(.background)
            if let icon = item.icon {
                Image(nsImage: icon).resizable().interpolation(.high).padding(6)
            } else {
                Text(String(item.target.name.prefix(1)))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: RingLayout.iconSize, height: RingLayout.iconSize)
        .clipShape(shape)
        // Crisp pixel-art outline instead of a soft shadow; a fixed dark line reads the same in light and dark mode.
        .overlay(shape.strokeBorder(Color.black.opacity(0.85), lineWidth: 2))
        // Selected/hovered: a small accent ring just outside the icon, plus a scale-up.
        .overlay(
            shape
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-3)
                .opacity(isSelected ? 1 : 0)
        )
        .overlay(alignment: .bottomTrailing) { badge }
        .scaleEffect(isSelected ? 1.1 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        .contentShape(shape)
    }

    @ViewBuilder private var badge: some View {
        let symbol: String? = switch item.target.kind {
        case .web: "globe"
        case .cli: "terminal"
        case .app: item.icon == nil ? "globe" : nil   // not installed: opens the website
        }
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .padding(3)
                .background(.thinMaterial, in: Circle())
                .offset(x: 3, y: 3)
        }
    }
}
