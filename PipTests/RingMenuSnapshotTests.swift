import AppKit
import SwiftUI
import XCTest
@testable import Pip

/// Renders the ring menu to PNGs for visual review (geometry, z-order, label placement).
/// Doesn't assert on pixels; materials may render flat under ImageRenderer.
@MainActor
final class RingMenuSnapshotTests: XCTestCase {

    private static let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("pip-ring-preview", isDirectory: true)
    private static let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private enum Focus {
        case ring(String)
        case branch(parent: String, index: Int)
        case parentWithBranch(String)
    }

    func testRenderRingPreviews() throws {
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)
        let mid = CGPoint(x: 720, y: 450), bottom = CGPoint(x: 720, y: 40)

        for (name, center, focus) in [
            ("full", mid, Focus.ring("gemini")),
            ("full-top", mid, .ring("chatgpt")),
            ("arc", bottom, .ring("grok")),
            ("branch-claude", mid, .branch(parent: "claude", index: 1)),
            ("branch-claude-parent", mid, .parentWithBranch("claude")),
            ("branch-chatgpt-arc", bottom, .branch(parent: "chatgpt", index: 1)),
        ] as [(String, CGPoint, Focus)] {
            for scheme in [ColorScheme.light, .dark] {
                let url = Self.outputDir.appendingPathComponent("ring-\(name)-\(scheme == .dark ? "dark" : "light").png")
                try render(center: center, focus: focus, scheme: scheme, to: url)
                print("Ring preview: \(url.path)")
            }
        }
    }

    func testRenderSymbolGrid() throws {
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            let grid = HStack(spacing: 18) {
                ForEach(AISymbols.ids + ["copilot"], id: \.self) { id in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(.regularMaterial).frame(width: RingMetrics.band, height: RingMetrics.band)
                            AISymbol(id: id, name: id.capitalized, size: RingMetrics.symbol)
                        }
                        Text(id).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .background(scheme == .dark ? Color(white: 0.16) : Color(white: 0.9))
            .environment(\.colorScheme, scheme)
            let url = Self.outputDir.appendingPathComponent("symbols-\(scheme == .dark ? "dark" : "light").png")
            try write(grid, to: url, scale: 3)
            print("Symbol preview: \(url.path)")
        }
    }

    private func render(center: CGPoint, focus: Focus, scheme: ColorScheme, to url: URL) throws {
        let scene = RingMenuController.scene(for: Self.sampleEntries(), center: center,
                                             bounds: Self.screen, screenFrame: Self.screen)
        let model = RingMenuModel()
        model.configure(items: scene.items, branches: scene.branches)
        switch focus {
        case .ring(let id):
            model.selectedID = id
        case .parentWithBranch(let id):
            model.selectedID = id
            model.openBranch(id)
        case .branch(let parent, let index):
            model.selectedID = parent
            model.enterBranch()
            for _ in 0..<index { model.moveClockwise() }
        }

        let ring = RingMenuView(model: model, center: scene.center, layout: scene.layout, initiallyShown: true) { _ in }
        let view = ZStack {
            // A stand-in desktop so the translucent band has something behind it.
            Rectangle().fill(scheme == .dark ? Color(white: 0.16) : Color(white: 0.9))
            Circle().fill(Color.accentColor.opacity(0.35)).frame(width: 90, height: 90)
                .position(scene.center)
            // Panel outline, to check that the band, branches and labels stay inside it.
            Rectangle().strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
            ring
        }
        .frame(width: scene.frame.width, height: scene.frame.height)
        .environment(\.colorScheme, scheme)
        try write(view, to: url, scale: 2)
    }

    private func write(_ view: some View, to url: URL, scale: CGFloat) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage else { return XCTFail("render failed") }
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
        try data.write(to: url)
    }

    /// The real catalog's shape: installed-looking apps (system icons stand in), websites,
    /// not-installed apps, and CLI children under ChatGPT and Claude.
    private static func sampleEntries() -> [RingMenuController.RingEntry] {
        func appIcon(_ path: String) -> NSImage { NSWorkspace.shared.icon(forFile: path) }
        let web = URL(string: "https://example.com")!
        func t(_ id: String, _ name: String, _ kind: AITarget.Kind) -> AITarget {
            AITarget(id: id, name: name, webURL: web, kind: kind)
        }
        return [
            .init(target: t("chatgpt", "ChatGPT", .app), icon: appIcon("/System/Applications/Notes.app"),
                  children: [(t("codex", "Codex", .cli), nil)]),
            .init(target: t("claude", "Claude", .app), icon: appIcon("/System/Applications/Calendar.app"),
                  children: [(t("claude-code", "Claude Code", .cli), nil)]),
            .init(target: t("gemini", "Gemini", .web), icon: nil, children: []),
            .init(target: t("grok", "Grok", .web), icon: nil, children: []),
            .init(target: t("copilot", "Copilot", .app), icon: appIcon("/System/Applications/Maps.app"), children: []),
            .init(target: t("perplexity", "Perplexity", .app), icon: nil, children: []),
            .init(target: t("cursor", "Cursor", .app), icon: nil, children: []),
        ]
    }
}
