import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow?
    private var menuBar: MenuBarController?
    private var ringMenu: RingMenuController?
    private var cliFlow: CLIFlow?
    private var quickBar: QuickBarController?
    private var quickBarHotKey: HotKey?
    private let store = TargetStore()
    private var settings: SettingsWindowController?
    private let launcher = Launcher()
    private let bubble = SpeechBubble()
    /// Targets whose summon is still running (the signature check can take seconds); repeats are ignored.
    private var summoning: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if CommandLine.arguments.contains("--qa-plan") { return runQAPlan() }
        if CommandLine.arguments.contains("--qa-ring") { return runQARing() }
        #endif
        let store = self.store
        let pet = PetWindow()
        let ring = RingMenuController(source: { store.ring }) { [weak self] target in
            self?.summon(target)
        }
        pet.onClick = { [weak ring, weak pet] in
            guard let ring, let pet else { return }
            pet.animator.send(.interaction)
            ring.toggle(around: pet.bodyCenter)
        }
        pet.onDragStart = { [weak ring, weak pet] in
            pet?.animator.send(.interaction)
            ring?.close()
        }
        pet.onHover = { [weak pet] in pet?.animator.send(.interaction) }
        pet.orderFrontRegardless()

        petWindow = pet
        ringMenu = ring
        settings = SettingsWindowController(store: store)
        let menuBar = MenuBarController(petWindow: pet) { [weak self] in
            self?.ringMenu?.close()
            self?.settings?.show()
        }
        self.menuBar = menuBar
        pet.onRightClick = { [weak ring, weak pet, weak menuBar] in
            guard let pet else { return }
            ring?.close()
            pet.animator.send(.interaction)
            menuBar?.popUpMenu(at: pet.bodyCenter)
        }
        cliFlow = CLIFlow { [weak self] message in self?.say(message) }

        let quickBar = QuickBarController(source: { store.visible }) { [weak self] target, anchor in
            self?.summon(target, anchor: anchor)
        }
        self.quickBar = quickBar
        store.applyHotKey = { [weak self] combo in self?.registerHotKey(combo) ?? false }
        store.suspendHotKey = { [weak self] suspended in self?.setHotKeySuspended(suspended) }
        if !registerHotKey(store.hotKey) {
            say("I couldn't set up the \(store.hotKey.displayString) shortcut, so the quick bar is off for now.")
        }
    }

    /// Swaps the quick bar shortcut. If the new one can't be registered, the previous one is restored.
    private func registerHotKey(_ combo: HotKey.Combo) -> Bool {
        let previous = currentHotKeyCombo
        quickBarHotKey?.unregister()
        quickBarHotKey = HotKey(combo) { [weak self] in
            self?.ringMenu?.close()
            self?.quickBar?.toggle()
        }
        if quickBarHotKey != nil {
            currentHotKeyCombo = combo
            return true
        }
        if let previous {
            quickBarHotKey = HotKey(previous) { [weak self] in
                self?.ringMenu?.close()
                self?.quickBar?.toggle()
            }
        }
        return false
    }

    private var currentHotKeyCombo: HotKey.Combo?

    /// Recording a new shortcut: drop the live one so its keys reach the recorder; restore it afterwards
    /// unless a new one was registered meanwhile.
    private func setHotKeySuspended(_ suspended: Bool) {
        if suspended {
            quickBarHotKey?.unregister()
            quickBarHotKey = nil
        } else if quickBarHotKey == nil, let combo = currentHotKeyCombo {
            quickBarHotKey = HotKey(combo) { [weak self] in
                self?.ringMenu?.close()
                self?.quickBar?.toggle()
            }
        }
    }

    /// `anchor` is where follow-up menus (the CLI folder menu) appear; defaults to just above Pip.
    private func summon(_ target: AITarget, anchor: NSPoint? = nil) {
        guard summoning.insert(target.id).inserted else { return }
        Task {
            defer { summoning.remove(target.id) }
            switch await launcher.summon(target, preferWeb: store.preferences.preferWeb.contains(target.id)) {
            case .done(let warning):
                petWindow?.animator.send(.summoned)
                if let warning { say(warning) }
            case .needsFolder(let tool):
                guard let point = anchor ?? petWindow.map({ NSPoint(x: $0.bodyFrame.midX, y: $0.bodyFrame.maxY) }) else { return }
                cliFlow?.start(tool, at: point)
            case .failed(let message):
                say(message)
            }
        }
    }

    private func say(_ message: String) {
        guard let pet = petWindow else { return }
        bubble.show(message, above: pet.bodyFrame)
    }

    #if DEBUG
    /// QA hook (Debug builds only): sweeps Pip's position across every screen, opening the ring at each
    /// point, and prints the ring's shape and any gap between where it was placed and where it landed.
    private func runQARing() {
        Task {
            let registry = store.ring
            let entries = registry.topLevel.map { target in
                RingMenuController.RingEntry(target: target, icon: nil, children: registry.children(of: target).map { ($0, nil as NSImage?) })
            }
            for (index, screen) in NSScreen.screens.enumerated() {
                let v = screen.visibleFrame
                print("screen \(index): frame=\(NSStringFromRect(screen.frame)) visible=\(NSStringFromRect(v))")
                for x in stride(from: v.minX + 60, through: v.maxX - 60, by: max(40, (v.width - 120) / 14)) {
                    print("  " + (await RingMenuController.diagnose(center: NSPoint(x: x, y: v.midY), screen: screen, entries: entries)))
                }
                for y in stride(from: v.minY + 60, through: v.maxY - 60, by: max(40, (v.height - 120) / 8)) {
                    print("  " + (await RingMenuController.diagnose(center: NSPoint(x: v.midX, y: y), screen: screen, entries: entries)))
                }
            }
            NSApp.terminate(nil)
        }
    }

    /// QA hook (Debug builds only): prints the launch decision for every target, then quits.
    /// Launches nothing, and prints ids and decision kinds only, no paths.
    private func runQAPlan() {
        Task {
            let registry = AppRegistry.load()
            print("targets: \(registry.targets.count)")
            for target in registry.targets {
                let start = Date()
                let plan = await launcher.plan(for: target)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                let summary: String = switch plan {
                case .activate: "activate running app"
                case .launch: "launch installed app"
                case .openWeb(_, let warning): warning == nil ? "open website" : "open website (UNTRUSTED app found)"
                case .runCLI(let tool): "ask for folder, run `\(tool.command)` in Terminal"
                case .refuse: "refuse"
                }
                let branch = target.parent.map { " (branch of \($0))" } ?? ""
                print("\(target.id)\(branch): \(summary) [\(ms) ms]")
            }
            NSApp.terminate(nil)
        }
    }
    #endif
}
