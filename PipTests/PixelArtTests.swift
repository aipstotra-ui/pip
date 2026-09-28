import XCTest
import AppKit
@testable import Pip

final class PixelArtTests: XCTestCase {
    func testEveryFrameIs20x20() {
        for (index, frame) in PipSprites.all.enumerated() {
            XCTAssertEqual(frame.height, PipSprites.size, "frame \(index) height")
            XCTAssertTrue(frame.rows.allSatisfy { $0.count == PipSprites.size }, "frame \(index) row widths")
        }
    }

    func testEveryPixelIsInPalette() {
        for (index, frame) in PipSprites.all.enumerated() {
            for row in frame.rows {
                for pixel in row where pixel != PixelArt.transparent {
                    XCTAssertNotNil(PixelArt.palette[pixel], "frame \(index): missing palette entry for '\(pixel)'")
                }
            }
        }
    }

    func testEmptyArt() {
        let art = PixelArt([])
        XCTAssertEqual(art.width, 0)
        XCTAssertEqual(art.height, 0)
    }

    /// Art row 0 must be the image's top row; CGContext's bottom-left origin makes this easy to flip.
    @MainActor
    func testCachedImageIsUpright() throws {
        let image = try XCTUnwrap(PixelArtImageCache.shared.image(for: PipSprites.idle0))
        let rep = NSBitmapImageRep(cgImage: image)   // colorAt(y: 0) is the top row
        XCTAssertEqual(rep.colorAt(x: 10, y: 0)?.alphaComponent, 0, "top row is empty in idle0")
        XCTAssertEqual(rep.colorAt(x: 10, y: 19)?.alphaComponent, 1, "bottom row is Pip's outline")
    }
}
