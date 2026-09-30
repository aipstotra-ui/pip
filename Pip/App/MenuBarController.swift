import AppKit

/// Menu-bar item: Settings, show/hide Pip and quit. Pip is an LSUIElement app, so this is its only persistent UI.
/// The same menu also pops up when you right-click Pip.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Hide Pip", action: #selector(togglePet), keyEquivalent: "")
    private weak var petWindow: PetWindow?
    private let onSettings: () -> Void

    init(petWindow: PetWindow, onSettings: @escaping () -> Void) {
        self.petWindow = petWindow
        self.onSettings = onSettings
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Pip")
        statusItem.menu = makeMenu(toggle: toggleItem)
    }

    /// Shows the same menu next to Pip (right-click).
    func popUpMenu(at point: NSPoint) {
        let toggle = NSMenuItem(title: "", action: #selector(togglePet), keyEquivalent: "")
        makeMenu(toggle: toggle).popUp(positioning: nil, at: point, in: nil)
    }

    private func makeMenu(toggle: NSMenuItem) -> NSMenu {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func openSettings() { onSettings() }

    @objc private func togglePet() {
        guard let pet = petWindow else { return }
        if pet.isVisible {
            pet.orderOut(nil)
        } else {
            pet.orderFrontRegardless()
        }
    }
}

extension MenuBarController: NSMenuItemValidation {
    /// Called each time the menu opens, so the title follows the window even if it was hidden elsewhere.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePet) {
            menuItem.title = (petWindow?.isVisible ?? false) ? "Hide Pip" : "Show Pip"
            return petWindow != nil
        }
        return true
    }
}
