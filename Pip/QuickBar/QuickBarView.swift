import SwiftUI

/// Spotlight-style search field with ranked AI targets underneath. Same language as the ring:
/// one frosted card with a hairline edge and a soft shadow, circular icon slots.
struct QuickBarView: View {
    @Bindable var model: QuickBarModel
    let onOpen: (AITarget) -> Void
    let onCancel: () -> Void
    /// Called with the panel height (card plus shadow margin) whenever the content changes size.
    var onHeightChange: (CGFloat) -> Void = { _ in }

    /// Draws the field and list with plain views (ImageRenderer can't draw AppKit-backed
    /// TextField/ScrollView) and skips the appear animation. Snapshot tests only.
    private let isSnapshot: Bool
    @State private var shown: Bool
    @State private var lastRowVisible = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 560
    static let fieldHeight: CGFloat = 52
    static let rowHeight: CGFloat = 44
    static let rowSpacing: CGFloat = 2
    static let listPadding: CGFloat = 6
    static let slot: CGFloat = 32
    static let cornerRadius: CGFloat = 16
    static let dividerHeight: CGFloat = 0.5
    /// Transparent room around the card for its SwiftUI shadow (the panel itself has none).
    static let margin = EdgeInsets(top: 10, leading: 16, bottom: 22, trailing: 16)
    static var panelWidth: CGFloat { width + margin.leading + margin.trailing }

    init(model: QuickBarModel, isSnapshot: Bool = false,
         onOpen: @escaping (AITarget) -> Void, onCancel: @escaping () -> Void,
         onHeightChange: @escaping (CGFloat) -> Void = { _ in }) {
        self.model = model
        self.onOpen = onOpen
        self.onCancel = onCancel
        self.onHeightChange = onHeightChange
        #if DEBUG
        self.isSnapshot = isSnapshot
        #else
        self.isSnapshot = false   // snapshot stand-ins exist for tests only
        #endif
        _shown = State(initialValue: isSnapshot)
    }

    /// Height of the card alone, derived from the model so the panel can hug it exactly.
    static func cardHeight(resultCount: Int, queryIsEmpty: Bool) -> CGFloat {
        if resultCount > 0 { return fieldHeight + dividerHeight + listHeight(rows: resultCount) }
        if !queryIsEmpty { return fieldHeight + dividerHeight + rowHeight + listPadding * 2 }
        return fieldHeight
    }

    static func panelHeight(resultCount: Int, queryIsEmpty: Bool) -> CGFloat {
        cardHeight(resultCount: resultCount, queryIsEmpty: queryIsEmpty) + margin.top + margin.bottom
    }

    /// When more rows exist than fit, half of the next row peeks out under the bottom fade.
    private static func listHeight(rows: Int) -> CGFloat {
        let full = CGFloat(min(rows, QuickBarModel.maxVisibleResults))
        let peek: CGFloat = rows > QuickBarModel.maxVisibleResults ? 0.5 : 0
        return (full + peek) * rowHeight + max(full - 1 + peek * 2, 0) * rowSpacing + listPadding * 2
    }

    private var panelHeight: CGFloat {
        Self.panelHeight(resultCount: model.results.count, queryIsEmpty: model.query.isEmpty)
    }

    var body: some View {
        let card = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        VStack(spacing: 0) {
            field
            if !model.results.isEmpty {
                QuickBarDivider()
                list
            } else if !model.query.isEmpty {
                QuickBarDivider()
                emptyState
            }
        }
        .frame(width: Self.width)
        // A filled shape rather than `.background(_:in:)`, so text keeps plain primary/secondary
        // colors instead of material vibrancy (same fix as the ring label).
        .background { card.fill(.regularMaterial) }
        .clipShape(card)
        .overlay(card.strokeBorder(QuickBarHairline(), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown || reduceMotion ? 1 : 0.98, anchor: .top)
        .padding(Self.margin)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            fieldFocused = true
            // onAppear can run before the field is in the (just-keyed) panel; retry once it is.
            DispatchQueue.main.async { fieldFocused = true }
            withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.14)) { shown = true }
            onHeightChange(panelHeight)
        }
        .onChange(of: panelHeight) { _, height in onHeightChange(height) }
    }

    private var field: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: Self.slot)
                .accessibilityHidden(true)
            if isSnapshot {
                Text(model.query.isEmpty ? "Open an AI app…" : model.query)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(model.query.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                textField
            }
        }
        // Lines the field icon up with the row slots below it.
        .padding(.horizontal, Self.listPadding + 8)
        .frame(height: Self.fieldHeight)
    }

    private var textField: some View {
        TextField("Open an AI app…", text: $model.query)
            .textFieldStyle(.plain)
            .font(.system(size: 20, weight: .regular))
            .focused($fieldFocused)
            .onSubmit { if let target = model.selected?.target { onOpen(target) } }
            .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
            .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
            .onKeyPress(.escape) { onCancel(); return .handled }
            .accessibilityLabel("Search AI apps")
    }

    private var emptyState: some View {
        Text(verbatim: "No AI app matches “\(model.query)”")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
            .padding(.vertical, Self.listPadding)
    }

    @ViewBuilder private var list: some View {
        if isSnapshot {
            rows
                .padding(Self.listPadding)
                .frame(height: Self.listHeight(rows: model.results.count), alignment: .top)
                .clipped()
                .mask(bottomFade(active: hasMoreBelow))
        } else {
            scrollingList
        }
    }

    /// More rows exist below the visible ones (the last row hasn't scrolled into view).
    private var hasMoreBelow: Bool {
        model.results.count > QuickBarModel.maxVisibleResults && !lastRowVisible
    }

    /// Fades the bottom edge of the list to hint that it scrolls.
    private func bottomFade(active: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .black.opacity(active ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fadeHeight)
        }
        .animation(.easeOut(duration: 0.15), value: active)
    }

    static let fadeHeight: CGFloat = 28
    private static let listSpace = "quickBarList"

    /// Reports whether the last row's bottom edge is inside the visible list area.
    private var lastRowTracker: some View {
        GeometryReader { geo in
            let visibleHeight = Self.listHeight(rows: model.results.count)
            Color.clear.onChange(of: geo.frame(in: .named(Self.listSpace)).maxY, initial: true) { _, maxY in
                lastRowVisible = maxY <= visibleHeight + 1
            }
        }
    }

    private var rows: some View {
        LazyVStack(spacing: Self.rowSpacing) {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                row(result, isSelected: index == model.selectedIndex)
                    .id(result.id)
                    .background {
                        if index == model.results.count - 1 { lastRowTracker }
                    }
            }
        }
    }

    private var scrollingList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                rows.padding(Self.listPadding)
            }
            .coordinateSpace(.named(Self.listSpace))
            .frame(height: Self.listHeight(rows: model.results.count))
            .mask(bottomFade(active: hasMoreBelow))
            .onChange(of: model.selectedIndex) { _, _ in
                if let id = model.selected?.id { proxy.scrollTo(id) }
            }
        }
    }

    private func row(_ result: QuickBarResult, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            QuickBarSlot(result: result)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: result.target.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(verbatim: result.destination)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            ReturnHint().opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.primary.opacity(isSelected ? 0.10 : 0))
        }
        .contentShape(Rectangle())
        .onHover { if $0 { model.select(result.id) } }
        .onTapGesture { onOpen(result.target) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(result.target.name), \(result.destination)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onOpen(result.target) }
    }
}

// MARK: - Pieces

/// 32pt circle like the ring's slots: the installed app's icon, else the drawn AISymbol.
private struct QuickBarSlot: View {
    let result: QuickBarResult

    var body: some View {
        ZStack {
            Circle().fill(.primary.opacity(0.05))
            Circle().strokeBorder(QuickBarHairline(darkOpacity: 0.14), lineWidth: 0.5)
            if let icon = result.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            } else {
                AISymbol(id: result.target.id, name: result.target.name, size: 20)
            }
        }
        .frame(width: QuickBarView.slot, height: QuickBarView.slot)
    }
}

/// Small keycap with ⏎, shown on the selected row.
private struct ReturnHint: View {
    var body: some View {
        Image(systemName: "return")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 20)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.primary.opacity(0.06))
            }
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(QuickBarHairline(), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

private struct QuickBarDivider: View {
    var body: some View {
        Rectangle().fill(QuickBarHairline(darkOpacity: 0.12)).frame(height: QuickBarView.dividerHeight)
    }
}

/// Hairline edge matching the ring's band and labels.
private struct QuickBarHairline: ShapeStyle {
    var darkOpacity = 0.25
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? .white.opacity(darkOpacity) : .black.opacity(0.08)
    }
}
