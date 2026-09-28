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
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(requirementString(bundleId: bundleId, teamId: teamId) as CFString,
                                             [], &requirement) == errSecSuccess, let requirement
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else { return false }
        guard let teamId else { return true }

        // The team ID is sealed in the (now validated) signature; it must match the pin.
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any]
        else { return false }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String == teamId
    }
}
