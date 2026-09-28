import Foundation

/// One AI app or website Pip can summon. Loaded from the bundled catalog.json and the optional user custom.json.
struct AITarget: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case app   // native app, website fallback
        case web   // website only
        case cli   // terminal command; bundled catalog only
    }

    let id: String
    let name: String
    let aliases: [String]
    let bundleIds: [String]
    /// Apple Team ID that must sign the app, when known. Unpinned apps still need a valid Apple-issued signature.
    let teamId: String?
    let webURL: URL
    let kind: Kind

    init(id: String, name: String, aliases: [String] = [], bundleIds: [String] = [],
         teamId: String? = nil, webURL: URL, kind: Kind) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.bundleIds = bundleIds
        self.teamId = teamId
        self.webURL = webURL
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        bundleIds = try c.decodeIfPresent([String].self, forKey: .bundleIds) ?? []
        teamId = try c.decodeIfPresent(String.self, forKey: .teamId)
        webURL = try c.decode(URL.self, forKey: .webURL)
        kind = try c.decode(Kind.self, forKey: .kind)
    }
}
