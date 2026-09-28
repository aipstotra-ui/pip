import AppKit

/// Icons shared by the ring and the quick bar.
@MainActor
enum TargetIcon {
    /// The installed app's own icon, or nil for web/CLI targets and apps that aren't installed.
    static func appIcon(for target: AITarget) -> NSImage? {
        guard target.kind == .app else { return nil }
        for id in target.bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
    }
}
