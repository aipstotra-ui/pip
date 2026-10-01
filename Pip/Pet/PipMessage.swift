import Foundation

/// Something Pip says in its speech bubble: what happened, and optionally one thing you can do about it.
/// Actions are a closed list handled by the app, so a message can never carry a link or a command.
struct PipMessage: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// System Settings › Privacy & Security › Automation (Terminal permission).
        case openAutomationSettings
        /// Pip's own Settings window, on the given tab.
        case openPipSettings(SettingsTab)
        /// Summon the same target again.
        case retry(targetID: String)

        var title: String {
            switch self {
            case .openAutomationSettings: "Open System Settings"
            case .openPipSettings(.shortcut): "Change Shortcut"
            case .openPipSettings(.apps): "Settings"
            case .retry: "Try Again"
            }
        }
    }

    enum SettingsTab: Equatable, Sendable { case apps, shortcut }

    let text: String
    var action: Action?

    init(_ text: String, action: Action? = nil) {
        self.text = text
        self.action = action
    }

    /// The Automation pane. A constant: never built from data.
    static let automationSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
}
