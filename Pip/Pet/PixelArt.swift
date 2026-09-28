import SwiftUI

/// A tiny pixel image described as rows of palette characters. '.' is transparent.
struct PixelArt {
    let rows: [[Character]]

    init(_ lines: [String]) {
        rows = lines.map(Array.init)
    }

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    static let transparent: Character = "."

    static let palette: [Character: Color] = [
        "o": Color(red: 0.11, green: 0.33, blue: 0.20), // outline
        "g": Color(red: 0.36, green: 0.80, blue: 0.46), // body
        "l": Color(red: 0.76, green: 0.97, blue: 0.76), // highlight
        "e": Color(red: 0.08, green: 0.10, blue: 0.10), // eyes
        "c": Color(red: 1.00, green: 0.60, blue: 0.66), // cheeks
    ]

    /// Placeholder Pip until the generated sprite frames arrive in M4.
    static let placeholderSlime = PixelArt([
        "................",
        "................",
        "................",
        "......oooo......",
        "....oogggloo....",
        "...oggggggllo...",
        "..oggggggggllo..",
        "..oggeggggeggo..",
        "..oggeggggeggo..",
        ".ogcggggggggcgo.",
        ".oggggggggggggo.",
        ".oggggggggggggo.",
        "..oggggggggggo..",
        "...oooooooooo...",
        "................",
        "................",
    ])
}
