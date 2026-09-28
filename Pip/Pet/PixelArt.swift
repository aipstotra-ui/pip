import SwiftUI

/// A tiny pixel image described as rows of palette characters. '.' is transparent.
struct PixelArt: Equatable {
    let rows: [[Character]]
    /// Identifies this frame for `PixelArtImageCache`, computed once at construction (each
    /// `PipSprites` constant is built exactly once) so drawing never re-hashes 400 characters per frame.
    let id: Int

    init(_ lines: [String]) {
        rows = lines.map(Array.init)
        var hasher = Hasher()
        hasher.combine(lines)
        id = hasher.finalize()
    }

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    static let transparent: Character = "."

    /// Colors sampled from the AI sprite sheet, plus a few for effects.
    static let palette: [Character: Color] = [
        "o": Color(red: 0.024, green: 0.188, blue: 0.133),  // outline
        "g": Color(red: 0.314, green: 0.812, blue: 0.376),  // body
        "s": Color(red: 0.094, green: 0.518, blue: 0.329),  // body shade
        "l": Color(red: 0.800, green: 0.988, blue: 0.894),  // highlight / sparkles
        "e": Color(red: 0.040, green: 0.055, blue: 0.055),  // eyes
        "w": Color.white,                                    // eye shine
        "c": Color(red: 0.988, green: 0.612, blue: 0.612),  // cheeks
        "m": Color(red: 0.549, green: 0.196, blue: 0.294),  // mouth
        "z": Color(red: 0.431, green: 0.490, blue: 0.588),  // "z"s and sound waves
        "h": Color.black.opacity(0.18),                      // soft ground shadow
    ]
}
