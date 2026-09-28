import AppKit
import Carbon.OpenScripting

/// Starts Claude Code (`claude`) in Terminal.app in a folder the user picked.
///
/// Security: the AppleScript source is a compile-time constant. The folder path is passed as an
/// Apple Event parameter and shell-quoted by AppleScript's `quoted form of`, so it is never
/// interpolated into script or shell text. Paths containing control characters are refused.
@MainActor
enum ClaudeCodeLauncher {
    enum Failure: Error, Equatable {
        case invalidFolder
        case automationDenied
        case scriptFailed
    }

    private static let scriptSource = """
    on run_in(folderPath)
        tell application id "com.apple.Terminal"
            activate
            do script "cd -- " & quoted form of folderPath & " && claude"
        end tell
    end run_in
    """

    /// -1743: the user denied (or hasn't granted) Automation permission for Terminal.
    private static let errAEEventNotPermitted = -1743

    static func isAcceptablePath(_ path: String) -> Bool {
        path.hasPrefix("/") && path.count <= 1024
            && path.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }

    static func run(in folder: URL) -> Result<Void, Failure> {
        let path = folder.resolvingSymlinksInPath().path
        guard isAcceptablePath(path) else { return .failure(.invalidFolder) }

        guard let script = NSAppleScript(source: scriptSource) else { return .failure(.scriptFailed) }
        var error: NSDictionary?
        guard script.compileAndReturnError(&error) else { return .failure(.scriptFailed) }

        let params = NSAppleEventDescriptor.list()
        params.insert(NSAppleEventDescriptor(string: path), at: 1)

        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASSubroutineEvent),
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setDescriptor(NSAppleEventDescriptor(string: "run_in"), forKeyword: AEKeyword(keyASSubroutineName))
        event.setDescriptor(params, forKeyword: AEKeyword(keyDirectObject))

        script.executeAppleEvent(event, error: &error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            return .failure(code == errAEEventNotPermitted ? .automationDenied : .scriptFailed)
        }
        return .success(())
    }
}
