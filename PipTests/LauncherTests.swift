import XCTest
@testable import Pip

@MainActor
private final class FakeWorkspace: WorkspaceProviding {
    var runningURLs: [String: URL] = [:]
    var installedURLs: [String: URL] = [:]
    var trustedURLs: Set<URL> = []
    var activateResult = true
    var openAppResult = true
    var openWebResult = true

    private(set) var activatedURL: URL?
    private(set) var openedAppURL: URL?
    private(set) var openedWebURL: URL?

    func runningAppURL(bundleId: String) -> URL? { runningURLs[bundleId] }
    func installedAppURL(bundleId: String) -> URL? { installedURLs[bundleId] }

    func isTrusted(appAt url: URL, bundleId: String, teamId: String?) async -> Bool {
        trustedURLs.contains(url)
    }

    func activate(appAt url: URL) -> Bool {
        activatedURL = url
        return activateResult
    }

    func openApp(at url: URL) async -> Bool {
        openedAppURL = url
        return openAppResult
    }

    func openWeb(_ url: URL) -> Bool {
        openedWebURL = url
        return openWebResult
    }
}

@MainActor
final class LauncherTests: XCTestCase {

    private let webURL = URL(string: "https://example.com")!
    private let bundleA = "com.example.a"
    private let bundleB = "com.example.b"
    private let installedURLA = URL(string: "file:///Applications/A.app")!
    private let installedURLB = URL(string: "file:///Applications/B.app")!

    private func makeTarget(
        bundleIds: [String] = [],
        teamId: String? = nil,
        webURL: URL? = nil,
        kind: AITarget.Kind,
        cli: CLITool? = nil
    ) -> AITarget {
        AITarget(id: "test-app", name: "Test App", bundleIds: bundleIds,
                 teamId: teamId, webURL: webURL ?? self.webURL, kind: kind, cli: cli)
    }

    func testWebKindOpensWebWithNoWarning() async {
        let workspace = FakeWorkspace()
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: makeTarget(kind: .web))
        XCTAssertEqual(plan, .openWeb(webURL, warning: nil))
    }

    func testCLIKindRunsItsTool() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        for tool in CLITool.allCases {
            let plan = await launcher.plan(for: makeTarget(kind: .cli, cli: tool))
            XCTAssertEqual(plan, .runCLI(tool))
        }
    }

    func testCLIKindWithoutToolRefuses() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        let plan = await launcher.plan(for: makeTarget(kind: .cli))
        guard case .refuse = plan else { return XCTFail("expected refuse, got \(plan)") }
    }

    func testCLIKindNeverTouchesWorkspace() async {
        let workspace = FakeWorkspace()
        let launcher = Launcher(workspace: workspace)
        _ = await launcher.summon(makeTarget(kind: .cli, cli: .codex))
        XCTAssertNil(workspace.openedWebURL)
        XCTAssertNil(workspace.openedAppURL)
        XCTAssertNil(workspace.activatedURL)
    }

    func testRunningAndTrustedActivates() async {
        let workspace = FakeWorkspace()
        workspace.runningURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: makeTarget(bundleIds: [bundleA], kind: .app))
        XCTAssertEqual(plan, .activate(appURL: installedURLA))
    }

    func testRunningButUntrustedOpensWebWithWarning() async {
        let workspace = FakeWorkspace()
        workspace.runningURLs[bundleA] = installedURLA
        // Not added to trustedURLs, so isTrusted returns false.
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: makeTarget(bundleIds: [bundleA], kind: .app))
        guard case .openWeb(let url, let warning) = plan else {
            return XCTFail("expected openWeb, got \(plan)")
        }
        XCTAssertEqual(url, webURL)
        XCTAssertNotNil(warning)
    }

    func testInstalledButUntrustedOpensWebWithWarning() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        // Not added to trustedURLs, so isTrusted returns false.
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: makeTarget(bundleIds: [bundleA], kind: .app))
        guard case .openWeb(let url, let warning) = plan else {
            return XCTFail("expected openWeb, got \(plan)")
        }
        XCTAssertEqual(url, webURL)
        XCTAssertNotNil(warning)
    }

    func testInstalledAndTrustedLaunchesVerifiedURL() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: makeTarget(bundleIds: [bundleA], kind: .app))
        XCTAssertEqual(plan, .launch(appURL: installedURLA))
    }

    func testSecondBundleIdUsedWhenFirstNotFound() async {
        let workspace = FakeWorkspace()
        // bundleA is not installed/running at all; only bundleB is.
        workspace.installedURLs[bundleB] = installedURLB
        workspace.trustedURLs = [installedURLB]
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: makeTarget(bundleIds: [bundleA, bundleB], kind: .app))
        XCTAssertEqual(plan, .launch(appURL: installedURLB))
    }

    func testUnsafeWebURLRefuses() async {
        let workspace = FakeWorkspace()
        let launcher = Launcher(workspace: workspace)
        let unsafe = URL(string: "http://example.com")!
        let plan = await launcher.plan(for: makeTarget(webURL: unsafe, kind: .web))
        guard case .refuse = plan else {
            return XCTFail("expected refuse, got \(plan)")
        }
    }

    // MARK: - summon

    func testSummonCLIReturnsNeedsFolderWithItsTool() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        let claude = await launcher.summon(makeTarget(kind: .cli, cli: .claude))
        let codex = await launcher.summon(makeTarget(kind: .cli, cli: .codex))
        XCTAssertEqual(claude, .needsFolder(.claude))
        XCTAssertEqual(codex, .needsFolder(.codex))
    }

    func testSummonCLIWithoutToolFails() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        let outcome = await launcher.summon(makeTarget(kind: .cli))
        guard case .failed = outcome else { return XCTFail("expected failed, got \(outcome)") }
    }

    func testSummonOpenWebFailureReturnsFailed() async {
        let workspace = FakeWorkspace()
        workspace.openWebResult = false
        let launcher = Launcher(workspace: workspace)
        let outcome = await launcher.summon(makeTarget(kind: .web))
        guard case .failed = outcome else {
            return XCTFail("expected failed, got \(outcome)")
        }
    }

    // MARK: - preferWeb

    private func appTarget(webURL: URL?, teamId: String? = nil) -> AITarget {
        AITarget(id: "test-app", name: "Test App", bundleIds: [bundleA], teamId: teamId, webURL: webURL, kind: .app)
    }

    func testPreferWebOpensWebEvenWhenInstalledAndTrusted() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.runningURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let launcher = Launcher(workspace: workspace)
        let plan = await launcher.plan(for: appTarget(webURL: webURL), preferWeb: true)
        XCTAssertEqual(plan, .openWeb(webURL, warning: nil))
    }

    func testSummonPreferWebOpensOnlyTheWebsite() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let launcher = Launcher(workspace: workspace)
        let outcome = await launcher.summon(appTarget(webURL: webURL), preferWeb: true)
        XCTAssertEqual(outcome, .done(warning: nil))
        XCTAssertEqual(workspace.openedWebURL, webURL)
        XCTAssertNil(workspace.openedAppURL)
        XCTAssertNil(workspace.activatedURL)
    }

    func testPreferWebFalseStillPrefersInstalledApp() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let plan = await Launcher(workspace: workspace).plan(for: appTarget(webURL: webURL), preferWeb: false)
        XCTAssertEqual(plan, .launch(appURL: installedURLA))
    }

    func testPreferWebWithoutWebURLAndNotInstalledRefuses() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        let plan = await launcher.plan(for: appTarget(webURL: nil), preferWeb: true)
        XCTAssertEqual(plan, .refuse(reason: "Test App isn't installed on this Mac."))
    }

    func testPreferWebWithoutWebURLInstalledAndTrustedLaunchesApp() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let plan = await Launcher(workspace: workspace).plan(for: appTarget(webURL: nil), preferWeb: true)
        XCTAssertEqual(plan, .launch(appURL: installedURLA))
    }

    func testPreferWebWithoutWebURLInstalledButUntrustedRefusesWithSignatureMessage() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        // Not trusted.
        let plan = await Launcher(workspace: workspace).plan(for: appTarget(webURL: nil), preferWeb: true)
        XCTAssertEqual(plan, .refuse(reason: "Test App didn't pass Pip's safety check, so I didn't open it."))
    }

    func testSummonRefusalBecomesFailedOutcome() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        let outcome = await launcher.summon(appTarget(webURL: nil), preferWeb: true)
        XCTAssertEqual(outcome, .failed(PipMessage("Test App isn't installed on this Mac.", action: .openPipSettings(.apps))))
    }

    func testPreferWebDoesNotAffectCLITargets() async {
        let launcher = Launcher(workspace: FakeWorkspace())
        let plan = await launcher.plan(for: makeTarget(kind: .cli, cli: .claude), preferWeb: true)
        XCTAssertEqual(plan, .runCLI(.claude))
    }

    func testPreferWebWithUnsafeWebURLRefuses() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let plan = await Launcher(workspace: workspace)
            .plan(for: appTarget(webURL: URL(string: "http://example.com")!), preferWeb: true)
        guard case .refuse = plan else { return XCTFail("expected refuse, got \(plan)") }
    }

    func testWebTargetWithNilWebURLFailsValidation() async {
        let target = AITarget(id: "test-web", name: "Test Web", webURL: nil, kind: .web)
        XCTAssertFalse(TargetValidator.isValid(target, source: .user))
        XCTAssertFalse(TargetValidator.isValid(target, source: .bundled))
        // And the launcher refuses it rather than opening anything.
        let workspace = FakeWorkspace()
        let plan = await Launcher(workspace: workspace).plan(for: target)
        XCTAssertEqual(plan, .refuse(reason: "Test Web has no web address."))
        _ = await Launcher(workspace: workspace).summon(target, preferWeb: true)
        XCTAssertNil(workspace.openedWebURL)
    }

    // MARK: - Outcome messages and actions

    private var retry: PipMessage.Action { .retry(targetID: "test-app") }

    private func assertFailed(_ outcome: Launcher.Outcome, action: PipMessage.Action?, contains: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard case .failed(let message) = outcome else {
            return XCTFail("expected failed, got \(outcome)", file: file, line: line)
        }
        XCTAssertEqual(message.action, action, file: file, line: line)
        XCTAssertTrue(message.text.contains(contains), "\(message.text) should contain \(contains)", file: file, line: line)
    }

    func testActivateFailureOffersRetry() async {
        let workspace = FakeWorkspace()
        workspace.runningURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        workspace.activateResult = false
        let outcome = await Launcher(workspace: workspace).summon(appTarget(webURL: webURL))
        assertFailed(outcome, action: retry, contains: "Test App")
    }

    func testOpenAppFailureOffersRetry() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        workspace.openAppResult = false
        let outcome = await Launcher(workspace: workspace).summon(appTarget(webURL: webURL))
        assertFailed(outcome, action: retry, contains: "Test App")
    }

    func testOpenWebFailureOffersRetry() async {
        let workspace = FakeWorkspace()
        workspace.openWebResult = false
        let outcome = await Launcher(workspace: workspace).summon(makeTarget(kind: .web))
        assertFailed(outcome, action: retry, contains: "website")
    }

    func testUntrustedWithWebsiteWarnsAndPointsToAppsSettings() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA   // untrusted
        let outcome = await Launcher(workspace: workspace).summon(appTarget(webURL: webURL))
        guard case .done(let warning?) = outcome else { return XCTFail("expected done with warning, got \(outcome)") }
        XCTAssertEqual(warning.action, .openPipSettings(.apps))
        XCTAssertTrue(warning.text.contains("safety check"))
        XCTAssertEqual(workspace.openedWebURL, webURL)
    }

    func testNotInstalledWithoutWebsiteFailsWithAppsSettings() async {
        let outcome = await Launcher(workspace: FakeWorkspace()).summon(appTarget(webURL: nil))
        assertFailed(outcome, action: .openPipSettings(.apps), contains: "isn't installed on this Mac")
    }

    func testUntrustedWithoutWebsiteFailsWithSafetyCheckMessage() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        let outcome = await Launcher(workspace: workspace).summon(appTarget(webURL: nil))
        assertFailed(outcome, action: .openPipSettings(.apps), contains: "didn't pass Pip's safety check")
        XCTAssertNil(workspace.openedAppURL)
    }

    func testUnsafeURLAtSummonTimeFailsWithAppsSettings() async {
        let workspace = FakeWorkspace()
        let outcome = await Launcher(workspace: workspace)
            .summon(makeTarget(webURL: URL(string: "http://example.com")!, kind: .web))
        assertFailed(outcome, action: .openPipSettings(.apps), contains: "unsafe")
        XCTAssertNil(workspace.openedWebURL)
    }

    func testSuccessHasNoWarning() async {
        let workspace = FakeWorkspace()
        workspace.installedURLs[bundleA] = installedURLA
        workspace.trustedURLs = [installedURLA]
        let launched = await Launcher(workspace: workspace).summon(appTarget(webURL: webURL))
        XCTAssertEqual(launched, .done(warning: nil))

        workspace.runningURLs[bundleA] = installedURLA
        let activated = await Launcher(workspace: workspace).summon(appTarget(webURL: webURL))
        XCTAssertEqual(activated, .done(warning: nil))

        let web = await Launcher(workspace: FakeWorkspace()).summon(makeTarget(kind: .web))
        XCTAssertEqual(web, .done(warning: nil))
    }

    func testMessageToneEveryLauncherMessageIsShortAndEndsWithPeriod() async {
        var messages: [PipMessage] = []
        func collect(_ outcome: Launcher.Outcome) {
            switch outcome {
            case .done(let warning?): messages.append(warning)
            case .failed(let message): messages.append(message)
            default: break
            }
        }

        // Use a long name to check the limit holds for realistic names.
        func target(kind: AITarget.Kind = .app, web: URL?, cli: CLITool? = nil) -> AITarget {
            AITarget(id: "test-app", name: "Some Fairly Long Assistant Name", bundleIds: [bundleA],
                     webURL: web, kind: kind, cli: cli)
        }
        let unsafe = URL(string: "http://example.com")!

        for (activate, openApp, openWeb) in [(false, true, true), (true, false, true), (true, true, false)] {
            let w = FakeWorkspace()
            w.activateResult = activate
            w.openAppResult = openApp
            w.openWebResult = openWeb
            w.runningURLs[bundleA] = installedURLA
            w.trustedURLs = [installedURLA]
            collect(await Launcher(workspace: w).summon(target(web: webURL)))
            w.runningURLs = [:]
            w.installedURLs[bundleA] = installedURLA
            collect(await Launcher(workspace: w).summon(target(web: webURL)))
            collect(await Launcher(workspace: w).summon(target(kind: .web, web: webURL)))
        }

        let untrusted = FakeWorkspace()
        untrusted.installedURLs[bundleA] = installedURLA
        collect(await Launcher(workspace: untrusted).summon(target(web: webURL)))
        collect(await Launcher(workspace: untrusted).summon(target(web: nil)))
        collect(await Launcher(workspace: FakeWorkspace()).summon(target(web: nil)))
        collect(await Launcher(workspace: FakeWorkspace()).summon(target(web: unsafe)))
        collect(await Launcher(workspace: FakeWorkspace()).summon(target(kind: .web, web: nil)))
        collect(await Launcher(workspace: FakeWorkspace()).summon(target(kind: .cli, web: nil)))

        XCTAssertGreaterThanOrEqual(messages.count, 9)
        for message in messages {
            XCTAssertLessThanOrEqual(message.text.count, 160, message.text)
            XCTAssertTrue(message.text.hasSuffix("."), message.text)
            XCTAssertNotNil(message.action, message.text)
        }
    }
}
