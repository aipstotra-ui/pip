import Foundation

/// Ranks AI targets against what the user typed in the quick bar. Pure and local: the query is
/// only compared against catalog names and aliases, never opened, run, or sent anywhere.
enum FuzzyMatcher {
    static let maxQueryLength = 64

    /// Case-, diacritic- and width-insensitive, trimmed.
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    /// 0 means no match; higher is better.
    static func score(query rawQuery: String, candidate rawCandidate: String) -> Int {
        let query = fold(String(rawQuery.prefix(maxQueryLength)))
        let candidate = fold(rawCandidate)
        guard !query.isEmpty else { return 1 }
        guard !candidate.isEmpty else { return 0 }

        if candidate == query { return 1000 }
        if candidate.hasPrefix(query) { return 800 - min(candidate.count - query.count, 100) }

        let words = candidate.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "." }).map(String.init)
        if words.contains(where: { $0.hasPrefix(query) }) { return 600 }

        let initials = String(words.compactMap(\.first))
        if initials.count > 1, initials.hasPrefix(query.replacingOccurrences(of: " ", with: "")) { return 500 }

        if candidate.contains(query) { return 400 }

        // Subsequence match ("gmn" → "gemini"); fewer gaps score higher.
        var gaps = 0
        var index = candidate.startIndex
        for ch in query where ch != " " {
            guard let found = candidate[index...].firstIndex(of: ch) else { return 0 }
            gaps += candidate.distance(from: index, to: found)
            index = candidate.index(after: found)
        }
        return max(1, 200 - gaps * 10)
    }

    /// Best score over the target's name and aliases (aliases slightly lower than the name).
    /// Branch tools (e.g. Codex under ChatGPT) rank just below main apps on near-ties.
    static func score(query: String, target: AITarget) -> Int {
        let nameScore = score(query: query, candidate: target.name)
        let aliasScore = target.aliases.map { score(query: query, candidate: $0) * 9 / 10 }.max() ?? 0
        let best = max(nameScore, aliasScore)
        guard best > 0, target.parent != nil else { return best }
        return max(1, best - branchPenalty)
    }

    static let branchPenalty = 10

    /// Matching targets, best first; ties keep catalog order. An empty query returns everything.
    static func rank(_ targets: [AITarget], query: String) -> [AITarget] {
        struct Scored { let offset: Int; let target: AITarget; let score: Int }
        let scored: [Scored] = targets.enumerated().map { offset, target in
            Scored(offset: offset, target: target, score: score(query: query, target: target))
        }
        return scored
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in lhs.score != rhs.score ? lhs.score > rhs.score : lhs.offset < rhs.offset }
            .map(\.target)
    }
}
