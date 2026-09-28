import SwiftUI

/// Draws Pip as crisp pixel art at an integer scale.
struct PetView: View {
    var art: PixelArt = .placeholderSlime

    var body: some View {
        Canvas { context, size in
            let cell = (min(size.width / CGFloat(art.width), size.height / CGFloat(art.height))).rounded(.down)
            let origin = CGPoint(
                x: ((size.width - cell * CGFloat(art.width)) / 2).rounded(.down),
                y: ((size.height - cell * CGFloat(art.height)) / 2).rounded(.down)
            )
            for (y, row) in art.rows.enumerated() {
                for (x, pixel) in row.enumerated() {
                    guard let color = PixelArt.palette[pixel] else { continue }
                    let rect = CGRect(x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(y) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: PetWindow.petSize.width, height: PetWindow.petSize.height)
        .accessibilityLabel("Pip")
    }
}
