import SwiftUI

/// Minimal drawn marks for targets without an installed app icon. Original simplified shapes,
/// not copies of any trademark. Anything without a mark here falls back to a monogram.
enum AISymbols {
    static let ids: [String] = ["gemini", "grok", "perplexity", "cursor", "codex", "claude-code"]

    static func has(_ id: String) -> Bool { ids.contains(id) }

    static let claudeOrange = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
}

/// The drawn mark for `id`, or a circled monogram of `name` when there isn't one.
struct AISymbol: View {
    let id: String
    let name: String
    var size: CGFloat = 26

    @Environment(\.colorScheme) private var scheme

    private var line: CGFloat { max(1.2, size / 16) }
    private var stroke: StrokeStyle { StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round) }

    var body: some View {
        mark.frame(width: size, height: size)
    }

    @ViewBuilder private var mark: some View {
        switch id {
        case "gemini":
            let gradient = LinearGradient(
                colors: [Color(red: 0.29, green: 0.53, blue: 0.96),
                         Color(red: 0.58, green: 0.45, blue: 0.86),
                         Color(red: 0.87, green: 0.43, blue: 0.56)],
                startPoint: .bottomLeading, endPoint: .topTrailing)
            SparkleShape()
                .fill(gradient)
                .overlay(SparkleShape().stroke(gradient, style: StrokeStyle(lineWidth: line * 0.9, lineJoin: .round)))
                .padding(size * 0.06)
        case "grok":
            SlashedCircleShape().stroke(.primary, style: stroke)
        case "perplexity":
            let teal = scheme == .dark ? Color(red: 0.25, green: 0.66, blue: 0.71)
                                       : Color(red: 0x20 / 255, green: 0x80 / 255, blue: 0x8D / 255)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .inset(by: line / 2 + size * 0.04)
                    .stroke(teal, style: stroke)
                AsteriskShape(spokes: 8).stroke(teal, style: StrokeStyle(lineWidth: line * 0.85, lineCap: .round))
                    .padding(size * 0.25)
            }
        case "cursor":
            ZStack {
                CubeFaceShape().fill(.primary.opacity(scheme == .dark ? 0.45 : 0.3))
                CubeShape().stroke(.primary, style: stroke)
            }
            .padding(size * 0.04)
        case "codex":
            PromptMark(accent: .primary, size: size, stroke: stroke)
        case "claude-code":
            PromptMark(accent: AISymbols.claudeOrange, size: size, stroke: stroke)
        default:
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.55, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(.secondary.opacity(0.45), lineWidth: 1))
        }
    }
}

/// `>_` in a rounded square; the cursor bar carries the accent color.
private struct PromptMark: View {
    let accent: Color
    let size: CGFloat
    let stroke: StrokeStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .inset(by: stroke.lineWidth / 2 + size * 0.04)
                .stroke(.primary, style: stroke)
            ChevronShape().stroke(.primary, style: stroke)
            CursorBarShape().stroke(accent, style: StrokeStyle(lineWidth: stroke.lineWidth * 1.15, lineCap: .round))
        }
    }
}

// MARK: - Shapes (drawn in a unit square, scaled to the rect)

private extension CGRect {
    func unit(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: minX + x * width, y: minY + y * height)
    }
}

/// Four-point sparkle with concave sides.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = rect.unit(0.5, 0.5)
        let tips = [rect.unit(0.5, 0), rect.unit(1, 0.5), rect.unit(0.5, 1), rect.unit(0, 0.5)]
        let pull: CGFloat = 0.07   // how far each side's control point sits from the center
        var p = Path()
        p.move(to: tips[0])
        for i in 0..<4 {
            let a = tips[i], b = tips[(i + 1) % 4]
            // Control point just off the center toward the side's midpoint: a deep, smooth concave curve.
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let control = CGPoint(x: c.x + (mid.x - c.x) * pull * 2, y: c.y + (mid.y - c.y) * pull * 2)
            p.addQuadCurve(to: b, control: control)
        }
        p.closeSubpath()
        return p
    }
}

/// A circle with a diagonal stroke through it, poking out past the rim.
struct SlashedCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(origin: rect.unit(0.14, 0.14),
                                size: CGSize(width: rect.width * 0.72, height: rect.height * 0.72)))
        p.move(to: rect.unit(0.1, 0.9))
        p.addLine(to: rect.unit(0.9, 0.1))
        return p
    }
}

/// Evenly spaced spokes from the center.
struct AsteriskShape: Shape {
    var spokes: Int

    func path(in rect: CGRect) -> Path {
        let c = rect.unit(0.5, 0.5), r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<spokes {
            let a = Double(i) / Double(spokes) * 2 * .pi + .pi / 2
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y - r * sin(a)))
        }
        return p
    }
}

/// Isometric cube: a pointy-top hexagon with the three inner edges meeting at the center.
struct CubeShape: Shape {
    static func vertices(in rect: CGRect) -> [CGPoint] {
        let c = rect.unit(0.5, 0.5), r = min(rect.width, rect.height) * 0.46
        // Pointy top, going clockwise on screen from the top vertex.
        return [90.0, 30, -30, -90, -150, 150].map {
            CGPoint(x: c.x + r * cos($0 * .pi / 180), y: c.y - r * sin($0 * .pi / 180))
        }
    }

    func path(in rect: CGRect) -> Path {
        let v = Self.vertices(in: rect), c = rect.unit(0.5, 0.5)
        var p = Path()
        p.addLines(v)
        p.closeSubpath()
        for i in [5, 1, 3] {   // upper-left, upper-right, bottom: the "Y" of a cube seen from above
            p.move(to: c)
            p.addLine(to: v[i])
        }
        return p
    }
}

/// The cube's right-hand face, shaded.
struct CubeFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let v = CubeShape.vertices(in: rect), c = rect.unit(0.5, 0.5)
        var p = Path()
        p.addLines([c, v[1], v[2], v[3]])
        p.closeSubpath()
        return p
    }
}

/// The `>` of a shell prompt.
struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: rect.unit(0.3, 0.36))
        p.addLine(to: rect.unit(0.44, 0.5))
        p.addLine(to: rect.unit(0.3, 0.64))
        return p
    }
}

/// The `_` cursor after the prompt.
struct CursorBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: rect.unit(0.52, 0.65))
        p.addLine(to: rect.unit(0.7, 0.65))
        return p
    }
}
