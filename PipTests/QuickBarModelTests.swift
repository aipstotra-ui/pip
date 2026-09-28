import XCTest
@testable import Pip

@MainActor
final class QuickBarModelTests: XCTestCase {

    private func target(_ id: String, name: String? = nil) -> AITarget {
        AITarget(id: id, name: name ?? id, webURL: URL(string: "https://example.com")!, kind: .web)
    }

    private func result(_ id: String, name: String? = nil, destination: String = "Website") -> QuickBarResult {
        QuickBarResult(target: target(id, name: name), icon: nil, destination: destination)
    }

    // MARK: - typing

    func testTypingUpdatesResultsAndResetsSelection() {
        let model = QuickBarModel(results: [result("claude", name: "Claude"), result("gemini", name: "Gemini")])
        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedIndex, 1)

        model.query = "gem"

        XCTAssertEqual(model.results.map(\.id), ["gemini"])
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testEmptyQueryReturnsAllResults() {
        let model = QuickBarModel(results: [result("a"), result("b"), result("c")])
        model.query = "nomatch-zzz"
        XCTAssertTrue(model.results.isEmpty)

        model.query = ""
        XCTAssertEqual(model.results.map(\.id), ["a", "b", "c"])
    }

    // MARK: - moveSelection

    func testMoveSelectionWrapsForward() {
        let model = QuickBarModel(results: [result("a"), result("b"), result("c")])
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testMoveSelectionWrapsBackward() {
        let model = QuickBarModel(results: [result("a"), result("b"), result("c")])
        model.moveSelection(by: -1)
        XCTAssertEqual(model.selectedIndex, 2)
    }

    func testMoveSelectionDoesNothingWhenNoResults() {
        let model = QuickBarModel(results: [])
        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertNil(model.selected)
    }

    // MARK: - select

    func testSelectSetsSelectedIndexById() {
        let model = QuickBarModel(results: [result("a"), result("b"), result("c")])
        model.select("c")
        XCTAssertEqual(model.selected?.id, "c")
    }

    func testSelectWithUnknownIdLeavesSelectionUnchanged() {
        let model = QuickBarModel(results: [result("a"), result("b")])
        model.select("b")
        model.select("does-not-exist")
        XCTAssertEqual(model.selected?.id, "b")
    }

    // MARK: - selected

    func testSelectedIsNilWhenResultsAreEmpty() {
        let model = QuickBarModel(results: [])
        XCTAssertNil(model.selected)
    }

    // MARK: - query clamping

    func testQueryLongerThanMaxIsClamped() {
        let model = QuickBarModel(results: [result("a")])
        model.query = String(repeating: "a", count: FuzzyMatcher.maxQueryLength + 50)
        XCTAssertEqual(model.query.count, FuzzyMatcher.maxQueryLength)
    }

    // MARK: - make(from:)

    func testMakeSetsCliChildDestinationToTerminalWithParentName() {
        let parent = AITarget(id: "claude", name: "Claude", webURL: URL(string: "https://claude.ai")!, kind: .app)
        let child = AITarget(id: "claude-code", name: "Claude Code",
                              webURL: URL(string: "https://claude.ai/code")!, kind: .cli,
                              cli: .claude, parent: "claude")
        let registry = AppRegistry(targets: [parent, child])

        let model = QuickBarModel.make(from: registry)

        let row = model.results.first { $0.id == "claude-code" }
        XCTAssertEqual(row?.destination, "Terminal · Claude")
    }

    func testMakeSetsWebTargetDestinationToWebsite() {
        let webTarget = AITarget(id: "gemini", name: "Gemini", webURL: URL(string: "https://gemini.google.com")!, kind: .web)
        let registry = AppRegistry(targets: [webTarget])

        let model = QuickBarModel.make(from: registry)

        XCTAssertEqual(model.results.first?.destination, "Website")
    }

    func testMakeSetsUninstalledAppDestinationToWebsite() {
        let appTarget = AITarget(id: "nope", name: "NopeApp",
                                  bundleIds: ["com.example.definitely-not-installed-pip-test"],
                                  webURL: URL(string: "https://example.com")!, kind: .app)
        let registry = AppRegistry(targets: [appTarget])

        let model = QuickBarModel.make(from: registry)

        XCTAssertEqual(model.results.first?.destination, "Website")
    }
}
