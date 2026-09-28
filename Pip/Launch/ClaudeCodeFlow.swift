import AppKit

/// Claude Code needs a folder: offer recent folders first, then "Choose Folder…", then launch in Terminal.
@MainActor
final class ClaudeCodeFlow: NSObject {
    private let recents = RecentFolders()
    private let report: (String) -> Void

    /// `report` shows a message to the user (Pip's speech bubble).
    init(report: @escaping (String) -> Void) {
        self.report = report
    }

    /// Shows the folder menu at `point` (screen coordinates), normally just above Pip.
    func start(at point: NSPoint) {
        let menu = NSMenu(title: "Open Claude Code in…")
        menu.addItem(withTitle: "Open Claude Code in…", action: nil, keyEquivalent: "").isEnabled = false
        for folder in recents.folders {
            let item = NSMenuItem(title: folder.lastPathComponent, action: #selector(pickRecent(_:)), keyEquivalent: "")
            item.representedObject = folder
            item.toolTip = (folder.path as NSString).abbreviatingWithTildeInPath
            item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let choose = NSMenuItem(title: "Choose Folder…", action: #selector(chooseFolder), keyEquivalent: "")
        choose.target = self
        menu.addItem(choose)
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    @objc private func pickRecent(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? URL else { return }
        launch(in: folder)
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Open Claude Code Here"
        panel.message = "Choose the project folder Claude Code should work in."
        // Pip is a background agent: activate so the panel comes to the front and takes keyboard focus.
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else {
            // Cancelled: give focus back instead of leaving a windowless Pip active.
            if let previous, previous != NSRunningApplication.current { previous.activate() }
            return
        }
        launch(in: folder)   // on success Terminal activates itself
    }

    private func launch(in folder: URL) {
        switch ClaudeCodeLauncher.run(in: folder) {
        case .success:
            recents.add(folder)
        case .failure(.automationDenied):
            report("I need permission to open Terminal. Turn on Pip → Terminal in System Settings › Privacy & Security › Automation.")
        case .failure(.invalidFolder):
            report("That folder name has characters I can't safely pass to Terminal.")
        case .failure(.scriptFailed):
            report("Couldn't start Claude Code in Terminal.")
        }
    }
}
