import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Apps tab: every top-level target in the user's order, drag to reorder, switch off what you don't use.
struct AppsSettingsView: View {
    let store: TargetStore

    @State private var pendingRemoval: AITarget?
    @State private var errorMessage: String?
    @State private var showingWebsiteSheet = false

    private var targets: [AITarget] { store.allTopLevelOrdered }

    /// Id of the last app that still fits on the ring, when more enabled apps follow it.
    private var ringBoundaryId: String? {
        let enabled = targets.filter { !store.preferences.hidden.contains($0.id) }
        guard enabled.count > TargetArrangement.ringLimit else { return nil }
        return enabled[TargetArrangement.ringLimit - 1].id
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Drag to reorder. The ring shows the first \(TargetArrangement.ringLimit) apps that are turned on.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            List {
                ForEach(targets) { target in
                    AppSettingsRow(
                        store: store,
                        target: target,
                        showsRingBoundary: target.id == ringBoundaryId,
                        onRemove: { pendingRemoval = target }
                    )
                    .listRowSeparator(.hidden)
                }
                .onMove { store.moveTopLevel(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset)

            Divider()
            HStack {
                addMenu
                Spacer()
            }
            .padding(12)
        }
        .alert(Text(verbatim: "Remove \(pendingRemoval?.name ?? "")?"), isPresented: removalBinding, presenting: pendingRemoval) { target in
            Button("Remove", role: .destructive) { remove(target) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It will disappear from the ring and quick bar. You can add it again later.")
        }
        .alert("Couldn't add that", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
        .sheet(isPresented: $showingWebsiteSheet) {
            AddWebsiteSheet(store: store)
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Installed App…") { chooseApp() }
            Button("Website…") { showingWebsiteSheet = true }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .menuIndicator(.visible)
        .fixedSize()
        .frame(minHeight: 28)
        .accessibilityLabel("Add an app or website")
    }

    private var removalBinding: Binding<Bool> {
        Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func remove(_ target: AITarget) {
        do { try store.removeCustom(id: target.id) } catch { errorMessage = error.localizedDescription }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do { try await store.addApp(at: url) } catch { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Row

/// One top-level target, with its branch tools (Claude Code, Codex) indented underneath.
/// Branch tools live inside their parent's row so dragging the parent moves them along.
struct AppSettingsRow: View {
    let store: TargetStore
    let target: AITarget
    var showsRingBoundary = false
    var onRemove: () -> Void = {}

    private var isEnabled: Bool { !store.preferences.hidden.contains(target.id) }
    private var isInstalled: Bool { TargetIcon.appIcon(for: target) != nil }
    private var opensWeb: Bool { store.preferences.preferWeb.contains(target.id) }

    private var destination: String {
        switch target.kind {
        case .web: "Website"
        case .cli: "Terminal"
        case .app:
            if isInstalled { opensWeb && target.webURL != nil ? "Website" : "App" }
            else { target.webURL != nil ? "Not installed · opens website" : "Not installed" }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            main
            ForEach(store.registry.children(of: target)) { child in
                BranchToolRow(store: store, target: child, parentEnabled: isEnabled)
            }
            if showsRingBoundary { RingBoundary(hotKey: store.hotKey.displayString) }
        }
        .padding(.vertical, 4)
    }

    private var main: some View {
        HStack(spacing: 10) {
            SettingsSlot(target: target)
                .opacity(isEnabled ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: target.name)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                Text(verbatim: destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if target.kind == .app, target.webURL != nil { openAsPicker }
            if store.isCustom(target) {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove")
                .accessibilityLabel(Text(verbatim: "Remove \(target.name)"))
            }
            Toggle(isOn: enabledBinding) { Text(verbatim: "Show \(target.name)") }
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(minWidth: 28, minHeight: 28)
        }
    }

    private var openAsPicker: some View {
        Picker(selection: preferWebBinding) {
            Text("App").tag(false)
            Text("Website").tag(true)
        } label: {
            Text(verbatim: "Open \(target.name) as")
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
        .disabled(!isInstalled || !isEnabled)
        .help("Open as")
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { isEnabled }, set: { store.setHidden(target.id, !$0) })
    }

    private var preferWebBinding: Binding<Bool> {
        Binding(get: { opensWeb }, set: { store.setPreferWeb(target.id, $0) })
    }
}

/// A branch tool: show or hide only. Greyed out while its parent is off.
private struct BranchToolRow: View {
    let store: TargetStore
    let target: AITarget
    let parentEnabled: Bool

    private var isEnabled: Bool { !store.preferences.hidden.contains(target.id) }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(verbatim: target.name)
                .font(.callout)
            Text("Terminal")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Toggle(isOn: Binding(get: { isEnabled }, set: { store.setHidden(target.id, !$0) })) {
                Text(verbatim: "Show \(target.name)")
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .frame(minWidth: 28, minHeight: 28)
        }
        .padding(.leading, 42)
        .opacity(parentEnabled ? 1 : 0.4)
        .disabled(!parentEnabled)
    }
}

/// Subtle marker between the apps on the ring and the ones only the quick bar shows.
private struct RingBoundary: View {
    let hotKey: String

    var body: some View {
        HStack(spacing: 8) {
            line
            Text(verbatim: "Below here: quick bar only (\(hotKey))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            line
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var line: some View {
        Rectangle().fill(.primary.opacity(0.15)).frame(height: 0.5)
    }
}

/// 32pt circle like the ring's slots: the installed app's icon, else the drawn AISymbol.
struct SettingsSlot: View {
    let target: AITarget

    var body: some View {
        ZStack {
            Circle().fill(.primary.opacity(0.05))
            Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
            if let icon = TargetIcon.appIcon(for: target) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            } else {
                AISymbol(id: target.id, name: target.name, size: 20)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}
