import Foundation

/// Command-line tools Pip may start in Terminal. A closed set: the command string never comes from data files.
enum CLITool: String, Codable, Sendable, CaseIterable {
    case claude
    case codex

    /// The exact command typed into Terminal.
    var command: String { rawValue }
    var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        }
    }
}

/// One AI app or website Pip can summon. Loaded from the bundled catalog.json and the optional user custom.json.
struct AITarget: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case app   // native app, website fallback
        case web   // website only
        case cli   // terminal command from `CLITool`; bundled catalog only
    }

    let id: String
    let name: String
    let aliases: [String]
    let bundleIds: [String]
    /// Apple Team ID that must sign the app, when known. Unpinned apps still need a valid Apple-issued signature.
    let teamId: String?
    /// Website to open (or fall back to). Optional for apps added by the user.
    let webURL: URL?
    let kind: Kind
    /// For `.cli` targets: which tool to run.
    let cli: CLITool?
    /// Id of the ring item this target branches out from (e.g. Claude Code under Claude). Bundled catalog only.
    let parent: String?

    init(id: String, name: String, aliases: [String] = [], bundleIds: [String] = [],
         teamId: String? = nil, webURL: URL?, kind: Kind, cli: CLITool? = nil, parent: String? = nil) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.bundleIds = bundleIds
        self.teamId = teamId
        self.webURL = webURL
        self.kind = kind
        self.cli = cli
        self.parent = parent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        bundleIds = try c.decodeIfPresent([String].self, forKey: .bundleIds) ?? []
        teamId = try c.decodeIfPresent(String.self, forKey: .teamId)
        webURL = try c.decodeIfPresent(URL.self, forKey: .webURL)
        kind = try c.decode(Kind.self, forKey: .kind)
        cli = try c.decodeIfPresent(CLITool.self, forKey: .cli)
        parent = try c.decodeIfPresent(String.self, forKey: .parent)
    }
}
