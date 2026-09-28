import AppKit

/// Menu-bar item: show/hide Pip and quit. Pip is an LSUIElement app, so this is its only persistent UI.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Hide Pip", action: #selector(togglePet), keyEquivalent: "")
    private weak var petWindow: PetWindow?

    init(petWindow: PetWindow) {
        self.petWindow = petWindow
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Pip")

        let menu = NSMenu()
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

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
        if menuItem === toggleItem {
            toggleItem.title = (petWindow?.isVisible ?? false) ? "Hide Pip" : "Show Pip"
            return petWindow != nil
        }
        return true
    }
}
