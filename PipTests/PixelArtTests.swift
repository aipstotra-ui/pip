import XCTest
@testable import Pip

final class PixelArtTests: XCTestCase {
    func testPlaceholderIsSquare16() {
        let art = PixelArt.placeholderSlime
        XCTAssertEqual(art.width, 16)
        XCTAssertEqual(art.height, 16)
        XCTAssertTrue(art.rows.allSatisfy { $0.count == 16 }, "every row must be the same width")
    }

    func testEveryPixelIsInPalette() {
        for row in PixelArt.placeholderSlime.rows {
            for pixel in row where pixel != PixelArt.transparent {
                XCTAssertNotNil(PixelArt.palette[pixel], "missing palette entry for '\(pixel)'")
            }
        }
    }

    func testEmptyArt() {
        let art = PixelArt([])
        XCTAssertEqual(art.width, 0)
        XCTAssertEqual(art.height, 0)
    }
}
