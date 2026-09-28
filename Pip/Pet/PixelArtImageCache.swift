import CoreGraphics
import SwiftUI

/// Renders each `PixelArt` frame into a native-size (20×20) CGImage once, keyed by frame identity.
/// The pet's CALayer scales this up with nearest-neighbor filtering (`magnificationFilter = .nearest`),
/// so drawing a frame is a layer content swap instead of iterating 400 pixels through a palette
/// dictionary lookup every redraw.
@MainActor
final class PixelArtImageCache {
    static let shared = PixelArtImageCache()

    private var images: [Int: CGImage] = [:]

    func image(for art: PixelArt) -> CGImage? {
        if let cached = images[art.id] { return cached }
        guard let rendered = Self.render(art) else { return nil }
        images[art.id] = rendered
        return rendered
    }

    private static func render(_ art: PixelArt) -> CGImage? {
        let width = art.width, height = art.height
        guard width > 0, height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        for (y, row) in art.rows.enumerated() {
            for (x, pixel) in row.enumerated() {
                guard let color = PixelArt.palette[pixel], let cgColor = color.cgColor else { continue }
                context.setFillColor(cgColor)
                // CGContext's origin is bottom-left, so art row 0 (the top) goes at y = height - 1.
                // A CGImage in layer.contents always displays upright, so no other flip is needed.
                context.fill(CGRect(x: x, y: height - 1 - y, width: 1, height: 1))
            }
        }
        return context.makeImage()
    }
}
