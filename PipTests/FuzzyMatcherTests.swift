import XCTest
@testable import Pip

final class FuzzyMatcherTests: XCTestCase {

    // MARK: - fold

    func testFoldIsCaseInsensitive() {
        XCTAssertEqual(FuzzyMatcher.fold("CLAUDE"), FuzzyMatcher.fold("claude"))
    }

    func testFoldStripsDiacritics() {
        XCTAssertEqual(FuzzyMatcher.fold("café"), "cafe")
    }

    func testFoldNormalizesFullWidth() {
        XCTAssertEqual(FuzzyMatcher.fold("ｃｌａｕｄｅ"), "claude")
    }

    func testFoldTrimsWhitespace() {
        XCTAssertEqual(FuzzyMatcher.fold("  claude  "), "claude")
    }

    // MARK: - score ordering

    func testExactMatchScoresHighest() {
        XCTAssertEqual(FuzzyMatcher.score(query: "claude", candidate: "Claude"), 1000)
    }

    func testPrefixMatch() {
        let score = FuzzyMatcher.score(query: "cla", candidate: "Claude")
        XCTAssertTrue(score > 0 && score < 1000)
    }

    func testWordPrefixMatchesWordInMultiWordCandidate() {
        let score = FuzzyMatcher.score(query: "code", candidate: "Claude Code")
        XCTAssertEqual(score, 600)
    }

    func testInitialsMatch() {
        let score = FuzzyMatcher.score(query: "cc", candidate: "Claude Code")
        XCTAssertEqual(score, 500)
    }

    func testContainsMatch() {
        let score = FuzzyMatcher.score(query: "hat", candidate: "ChatGPT")
        XCTAssertEqual(score, 400)
    }

    func testSubsequenceMatch() {
        let score = FuzzyMatcher.score(query: "gmn", candidate: "Gemini")
        XCTAssertTrue(score > 0 && score < 400)
    }

    func testNoMatchScoresZero() {
        XCTAssertEqual(FuzzyMatcher.score(query: "xyz", candidate: "Gemini"), 0)
    }

    func testScoreOrderingAcrossAllTiers() {
        let exact = FuzzyMatcher.score(query: "claude", candidate: "Claude")
        let prefix = FuzzyMatcher.score(query: "cla", candidate: "Claude")
        let wordPrefix = FuzzyMatcher.score(query: "code", candidate: "Claude Code")
        let initials = FuzzyMatcher.score(query: "cc", candidate: "Claude Code")
        let contains = FuzzyMatcher.score(query: "hat", candidate: "ChatGPT")
        let subsequence = FuzzyMatcher.score(query: "gmn", candidate: "Gemini")
        let none = FuzzyMatcher.score(query: "xyz", candidate: "Gemini")

        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, wordPrefix)
        XCTAssertGreaterThan(wordPrefix, initials)
        XCTAssertGreaterThan(initials, contains)
        XCTAssertGreaterThan(contains, subsequence)
        XCTAssertGreaterThan(subsequence, none)
        XCTAssertEqual(none, 0)
    }

    // MARK: - empty query

    func testEmptyQueryScoresOne() {
        XCTAssertEqual(FuzzyMatcher.score(query: "", candidate: "Anything"), 1)
    }

    func testEmptyQueryRankReturnsAllTargetsInCatalogOrder() {
        let targets = [web("a"), web("b"), web("c")]
        XCTAssertEqual(FuzzyMatcher.rank(targets, query: "").map(\.id), ["a", "b", "c"])
    }

    // MARK: - aliases

    func testAliasesScoreBelowNames() {
        let byName = web("a", name: "Zeta")
        let byAlias = web("b", name: "Other", aliases: ["zeta"])
        let nameScore = FuzzyMatcher.score(query: "zeta", target: byName)
        let aliasScore = FuzzyMatcher.score(query: "zeta", target: byAlias)
        XCTAssertEqual(nameScore, 1000)
        XCTAssertEqual(aliasScore, 900)
        XCTAssertLessThan(aliasScore, nameScore)
    }

    func testAliasFindsTargetEvenWhenNameDoesNotContainQuery() {
        let target = web("chatgpt-ish", name: "Assistant", aliases: ["gpt"])
        XCTAssertGreaterThan(FuzzyMatcher.score(query: "gpt", target: target), 0)
    }

    // MARK: - ties

    func testTiesKeepCatalogOrder() {
        // Same name shape ("x1", "x2", ...) so every candidate scores identically for this query.
        let targets = [web("first", name: "Xa"), web("second", name: "Xb"), web("third", name: "Xc")]
        XCTAssertEqual(FuzzyMatcher.rank(targets, query: "x").map(\.id), ["first", "second", "third"])
    }

    // MARK: - maxQueryLength

    func testQueryLongerThanMaxIsTruncatedAndDoesNotCrash() {
        let longQuery = String(repeating: "a", count: 100)
        let candidate = String(repeating: "a", count: FuzzyMatcher.maxQueryLength)
        // The query is truncated to maxQueryLength before comparison, so it exactly matches
        // a candidate made of maxQueryLength 'a's.
        XCTAssertEqual(FuzzyMatcher.score(query: longQuery, candidate: candidate), 1000)
    }

    func testVeryLongQueryAgainstShortCandidateDoesNotCrash() {
        let longQuery = String(repeating: "z", count: 500)
        XCTAssertEqual(FuzzyMatcher.score(query: longQuery, candidate: "Claude"), 0)
    }

    // MARK: - bundled catalog

    func testCatalogClaudeQueryRanksClaudeFirstThenClaudeCode() {
        let registry = AppRegistry.load(bundle: .main, customURL: nil)
        let ranked = FuzzyMatcher.rank(registry.targets, query: "claude")
        XCTAssertEqual(Array(ranked.prefix(2)).map(\.id), ["claude", "claude-code"])
    }

    func testCatalogCodexQueryFindsCodex() {
        let registry = AppRegistry.load(bundle: .main, customURL: nil)
        let ranked = FuzzyMatcher.rank(registry.targets, query: "codex")
        XCTAssertEqual(ranked.first?.id, "codex")
    }

    func testCatalogPerQueryFindsPerplexityFirst() {
        let registry = AppRegistry.load(bundle: .main, customURL: nil)
        let ranked = FuzzyMatcher.rank(registry.targets, query: "per")
        XCTAssertEqual(ranked.first?.id, "perplexity")
    }

    func testCatalogGptQueryFindsChatGPTThroughAlias() {
        let registry = AppRegistry.load(bundle: .main, customURL: nil)
        let ranked = FuzzyMatcher.rank(registry.targets, query: "gpt")
        XCTAssertTrue(ranked.contains { $0.id == "chatgpt" })
    }

    // MARK: - helpers

    private func web(_ id: String, name: String? = nil, aliases: [String] = []) -> AITarget {
        AITarget(id: id, name: name ?? id, aliases: aliases, webURL: URL(string: "https://example.com")!, kind: .web)
    }
}
