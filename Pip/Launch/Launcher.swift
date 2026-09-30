import AppKit

/// What the launcher decided to do for a target. Pure data, so the decision logic is unit-testable.
enum LaunchPlan: Equatable {
    case activate(appURL: URL)
    case launch(appURL: URL)
    /// `warning` is shown when a native app was found but failed the signature check.
    case openWeb(URL, warning: String?)
    case runCLI(CLITool)
    case refuse(reason: String)
}

/// The side-effect surface the launcher needs, so tests can substitute a fake.
@MainActor
protocol WorkspaceProviding {
    func runningAppURL(bundleId: String) -> URL?
    func installedAppURL(bundleId: String) -> URL?
    func isTrusted(appAt url: URL, bundleId: String, teamId: String?) async -> Bool
    func activate(appAt url: URL) -> Bool
    func openApp(at url: URL) async -> Bool
    func openWeb(_ url: URL) -> Bool
}

/// The only place Pip opens apps or websites. Every input (ring menu, quick bar, voice) goes through `summon`.
@MainActor
final class Launcher {
    enum Outcome: Equatable {
        case done(warning: String?)
        case needsFolder(CLITool)   // CLI target: the caller asks the user for a folder
        case failed(String)
    }

    private let workspace: WorkspaceProviding

    init(workspace: WorkspaceProviding = SystemWorkspace()) {
        self.workspace = workspace
    }

    /// `preferWeb`: the user chose "open as website" for this app in Settings.
    func summon(_ target: AITarget, preferWeb: Bool = false) async -> Outcome {
        switch await plan(for: target, preferWeb: preferWeb) {
        case .activate(let url):
            return workspace.activate(appAt: url) ? .done(warning: nil) : .failed("Couldn't bring \(target.name) forward.")
        case .launch(let url):
            return await workspace.openApp(at: url) ? .done(warning: nil) : .failed("Couldn't open \(target.name).")
        case .openWeb(let url, let warning):
            // Defense in depth: re-check the URL right before handing it to the browser.
            guard TargetValidator.isSafeWebURL(url) else { return .failed("Blocked an unsafe link for \(target.name).") }
            return workspace.openWeb(url) ? .done(warning: warning) : .failed("Couldn't open \(target.name)'s website.")
        case .runCLI(let tool):
            return .needsFolder(tool)
        case .refuse(let reason):
            return .failed(reason)
        }
    }

    func plan(for target: AITarget, preferWeb: Bool = false) async -> LaunchPlan {
        if let web = target.webURL, !TargetValidator.isSafeWebURL(web) {
            return .refuse(reason: "\(target.name) has an unsafe web address.")
        }
        if preferWeb, target.kind == .app, let web = target.webURL {
            return .openWeb(web, warning: nil)
        }
        switch target.kind {
        case .web:
            guard let web = target.webURL else { return .refuse(reason: "\(target.name) has no web address.") }
            return .openWeb(web, warning: nil)
        case .cli:
            guard let tool = target.cli else { return .refuse(reason: "\(target.name) has no command.") }
            return .runCLI(tool)
        case .app:
            var foundUntrusted = false
            for bundleId in target.bundleIds {
                if let url = workspace.runningAppURL(bundleId: bundleId) {
                    if await workspace.isTrusted(appAt: url, bundleId: bundleId, teamId: target.teamId) {
                        return .activate(appURL: url)   // activate exactly the process that was verified
                    }
                    foundUntrusted = true
                }
            }
            for bundleId in target.bundleIds {
                if let url = workspace.installedAppURL(bundleId: bundleId) {
                    if await workspace.isTrusted(appAt: url, bundleId: bundleId, teamId: target.teamId) {
                        return .launch(appURL: url)   // launch exactly the bundle that was verified
                    }
                    foundUntrusted = true
                }
            }
            guard let web = target.webURL else {
                return .refuse(reason: foundUntrusted
                    ? "\(target.name) didn't pass the signature check, so I didn't open it."
                    : "\(target.name) isn't installed.")
            }
            let warning = foundUntrusted
                ? "\(target.name)'s app didn't pass the signature check, so I opened the website instead."
                : nil
            return .openWeb(web, warning: warning)
        }
    }
}

/// Real implementation backed by NSWorkspace and the Security framework.
@MainActor
struct SystemWorkspace: WorkspaceProviding {
    func runningAppURL(bundleId: String) -> URL? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.bundleURL
    }

    func installedAppURL(bundleId: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
    }

    func isTrusted(appAt url: URL, bundleId: String, teamId: String?) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            CodeTrust.isTrusted(appAt: url, bundleId: bundleId, teamId: teamId)
        }.value
    }

    func activate(appAt url: URL) -> Bool {
        let bundleId = Bundle(url: url)?.bundleIdentifier ?? ""
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .first(where: { $0.bundleURL == url }) else { return false }
        if app.isHidden { app.unhide() }
        return app.activate()
    }

    func openApp(at url: URL) async -> Bool {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        return (try? await NSWorkspace.shared.openApplication(at: url, configuration: config)) != nil
    }

    func openWeb(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
