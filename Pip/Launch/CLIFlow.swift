import AppKit

/// Terminal tools need a folder: offer that tool's recent folders first, then "Choose Folder…", then launch.
@MainActor
final class CLIFlow: NSObject {
    private var recents: [CLITool: RecentFolders] = [:]
    private let report: (String) -> Void

    /// `report` shows a message to the user (Pip's speech bubble).
    init(report: @escaping (String) -> Void) {
        self.report = report
    }

    private func recentFolders(for tool: CLITool) -> RecentFolders {
        if let existing = recents[tool] { return existing }
        let created = RecentFolders(tool: tool)
        recents[tool] = created
        return created
    }

    /// Shows the folder menu for `tool` at `point` (screen coordinates), normally just above Pip.
    /// Each menu item carries its own tool (no shared "active tool"), so a second summon arriving while
    /// this menu or the open panel is up can never make a pick here launch the other tool.
    func start(_ tool: CLITool, at point: NSPoint) {
        let title = "Open \(tool.displayName) in…"
        let menu = NSMenu(title: title)
        menu.addItem(withTitle: title, action: nil, keyEquivalent: "").isEnabled = false
        for folder in recentFolders(for: tool).folders {
            let item = NSMenuItem(title: folder.lastPathComponent, action: #selector(pickRecent(_:)), keyEquivalent: "")
            item.representedObject = Pick(tool: tool, folder: folder)
            item.toolTip = (folder.path as NSString).abbreviatingWithTildeInPath
            item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let choose = NSMenuItem(title: "Choose Folder…", action: #selector(chooseFolder(_:)), keyEquivalent: "")
        choose.representedObject = tool
        choose.target = self
        menu.addItem(choose)
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    @objc private func pickRecent(_ sender: NSMenuItem) {
        guard let pick = sender.representedObject as? Pick else { return }
        launch(pick.tool, in: pick.folder)
    }

    @objc private func chooseFolder(_ sender: NSMenuItem) {
        guard let tool = sender.representedObject as? CLITool else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Open \(tool.displayName) Here"
        panel.message = "Choose the project folder \(tool.displayName) should work in."
        // Pip is a background agent: activate so the panel comes to the front and takes keyboard focus.
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else {
            // Cancelled: give focus back instead of leaving a windowless Pip active.
            if let previous, previous != NSRunningApplication.current { previous.activate() }
            return
        }
        launch(tool, in: folder)   // on success Terminal activates itself
    }

    private struct Pick {
        let tool: CLITool
        let folder: URL
    }

    private func launch(_ tool: CLITool, in folder: URL) {
        switch TerminalLauncher.run(tool, in: folder) {
        case .success:
            recentFolders(for: tool).add(folder)
        case .failure(.automationDenied):
            report("I need permission to open Terminal. Turn on Pip → Terminal in System Settings › Privacy & Security › Automation.")
        case .failure(.invalidFolder):
            report("That folder name has characters I can't safely pass to Terminal.")
        case .failure(.scriptFailed):
            report("Couldn't start \(tool.displayName) in Terminal.")
        }
    }
}
