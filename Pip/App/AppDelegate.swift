import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow?
    private var menuBar: MenuBarController?
    private var ringMenu: RingMenuController?
    private var cliFlow: CLIFlow?
    private let launcher = Launcher()
    private let bubble = SpeechBubble()
    /// Targets whose summon is still running (the signature check can take seconds); repeats are ignored.
    private var summoning: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if CommandLine.arguments.contains("--qa-plan") { return runQAPlan() }
        #endif
        let pet = PetWindow()
        let ring = RingMenuController(registry: AppRegistry.load()) { [weak self] target in
            self?.summon(target)
        }
        pet.onClick = { [weak ring, weak pet] in
            guard let ring, let pet else { return }
            ring.toggle(around: pet.frame)
        }
        pet.onDragStart = { [weak ring] in ring?.close() }
        pet.orderFrontRegardless()

        petWindow = pet
        ringMenu = ring
        menuBar = MenuBarController(petWindow: pet)
        cliFlow = CLIFlow { [weak self] message in self?.say(message) }
    }

    private func summon(_ target: AITarget) {
        guard summoning.insert(target.id).inserted else { return }
        Task {
            defer { summoning.remove(target.id) }
            switch await launcher.summon(target) {
            case .done(let warning):
                if let warning { say(warning) }
            case .needsFolder(let tool):
                if let pet = petWindow { cliFlow?.start(tool, at: NSPoint(x: pet.frame.midX, y: pet.frame.maxY)) }
            case .failed(let message):
                say(message)
            }
        }
    }

    private func say(_ message: String) {
        guard let pet = petWindow else { return }
        bubble.show(message, above: pet.frame)
    }

    #if DEBUG
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
