import XCTest
import SwiftUI
import AppKit
@testable import Pip

/// Not a correctness test: renders every sprite frame to PNG so a human (or Claude) can eyeball
/// alignment, baseline jumpiness, and palette issues across the animation set. No pixel assertions.
private struct SpriteCell: View {
    static let pixelScale: CGFloat = 5

    let label: String
    let art: PixelArt
    let labelColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, _ in
                let cell = Self.pixelScale
                for (y, row) in art.rows.enumerated() {
                    for (x, pixel) in row.enumerated() where pixel != PixelArt.transparent {
                        guard let color = PixelArt.palette[pixel] else { continue }
                        let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .frame(width: CGFloat(art.width) * Self.pixelScale, height: CGFloat(art.height) * Self.pixelScale)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(labelColor)
        }
        .padding(6)
    }
}

private struct SpriteGrid: View {
    let entries: [(String, PixelArt)]
    let backgroundColor: Color
    let labelColor: Color

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(CGFloat(PipSprites.size) * SpriteCell.pixelScale + 16)), count: 6)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                SpriteCell(label: entry.0, art: entry.1, labelColor: labelColor)
            }
        }
        .padding(16)
        .background(backgroundColor)
    }
}

@MainActor
final class SpritePreviewTests: XCTestCase {
    private enum PreviewError: Error { case renderFailed, encodeFailed }

    /// idle0-3, happy0-3, sleep0-1, listening0-1, in that order.
    private var orderedFrames: [(String, PixelArt)] {
        [
            ("idle0", PipSprites.idle0), ("idle1", PipSprites.idle1),
            ("idle2", PipSprites.idle2), ("idle3", PipSprites.idle3),
            ("happy0", PipSprites.happy0), ("happy1", PipSprites.happy1),
            ("happy2", PipSprites.happy2), ("happy3", PipSprites.happy3),
            ("sleep0", PipSprites.sleep0), ("sleep1", PipSprites.sleep1),
            ("listening0", PipSprites.listening0), ("listening1", PipSprites.listening1),
        ]
    }

    private var previewDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pip-sprite-preview", isDirectory: true)
    }

    func testRendersLightAndDarkSpriteSheets() throws {
        let entries = orderedFrames
        XCTAssertEqual(entries.count, 12, "expected exactly the 12 documented frames")

        let dir = previewDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let lightPath = try renderGrid(entries: entries, backgroundColor: .white, labelColor: .black,
                                        filename: "sprites-light.png", in: dir)
        let darkPath = try renderGrid(entries: entries, backgroundColor: .black, labelColor: .white,
                                       filename: "sprites-dark.png", in: dir)

        print("Sprite preview (light background): \(lightPath.path)")
        print("Sprite preview (dark background): \(darkPath.path)")
    }

    private func renderGrid(entries: [(String, PixelArt)], backgroundColor: Color, labelColor: Color,
                             filename: String, in dir: URL) throws -> URL {
        let view = SpriteGrid(entries: entries, backgroundColor: backgroundColor, labelColor: labelColor)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let nsImage = renderer.nsImage else {
            XCTFail("failed to render \(filename)")
            throw PreviewError.renderFailed
        }
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("failed to encode \(filename)")
            throw PreviewError.encodeFailed
        }

        let url = dir.appendingPathComponent(filename)
        try png.write(to: url)
        return url
    }
}
