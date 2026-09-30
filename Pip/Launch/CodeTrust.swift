import Foundation
import Security

/// Verifies an app's code signature before Pip launches or activates it,
/// so an app that merely claims a well-known bundle ID can't be summoned in its place.
enum CodeTrust {
    /// Marker extension that only exists on Apple's Mac App Store signing certificate.
    private static let appStoreCertMarker = "1.2.840.113635.100.6.1.9"
    /// Developer ID markers: intermediate CA (6.2.6) and leaf application certificate (6.1.13).
    /// Required so a free "Apple Development" certificate can't impersonate an unpinned app.
    private static let developerIDIntermediateMarker = "1.2.840.113635.100.6.2.6"
    private static let developerIDLeafMarker = "1.2.840.113635.100.6.1.13"

    /// Requirement: the expected bundle identifier, signed either by Apple's Mac App Store certificate or by a
    /// Developer ID certificate (with the pinned team, when known). The App Store path's team is checked in
    /// `isTrusted` against the sealed team ID. Ad-hoc, self-signed and Apple Development signatures fail.
    /// Inputs are pre-validated by `TargetValidator` to `[A-Za-z0-9.-]` and `[A-Z0-9]{10}`, so they're safe to embed.
    static func requirementString(bundleId: String, teamId: String?) -> String {
        let appStore = "certificate leaf[field.\(appStoreCertMarker)] exists"
        var developerID = "certificate 1[field.\(developerIDIntermediateMarker)] exists"
            + " and certificate leaf[field.\(developerIDLeafMarker)] exists"
        if let teamId {
            developerID += #" and certificate leaf[subject.OU] = "\#(teamId)""#
        }
        return #"anchor apple generic and identifier "\#(bundleId)" and ("# + appStore + " or (" + developerID + "))"
    }

    /// Slow for large apps (hashes all resources), so call it off the main thread.
    static func isTrusted(appAt url: URL, bundleId: String, teamId: String?) -> Bool {
        verifiedTeam(appAt: url, bundleId: bundleId, teamId: teamId) != nil
    }

    /// Validates the app and returns the team ID sealed in *that same* validated signature
    /// (never re-reads the file), or nil if it fails. With `teamId`, it must match the pin.
    static func verifiedTeam(appAt url: URL, bundleId: String, teamId: String?) -> String? {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(requirementString(bundleId: bundleId, teamId: teamId) as CFString,
                                             [], &requirement) == errSecSuccess, let requirement
        else { return nil }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else { return nil }

        // Read from the validated code object, whose signature info is now cached and sealed.
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let team = (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String,
              team.range(of: #"^[A-Z0-9]{10}$"#, options: .regularExpression) != nil
        else { return nil }
        if let teamId, team != teamId { return nil }
        return team
    }

    /// The signing team of a trusted (Developer ID or App Store) app, used to pin apps the user adds.
    /// Returns nil unless the app passes the same requirement Pip enforces at launch.
    static func pinnedTeam(forAppAt url: URL, bundleId: String) -> String? {
        verifiedTeam(appAt: url, bundleId: bundleId, teamId: nil)
    }
}
