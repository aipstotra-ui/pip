import AppKit
import SwiftUI
import XCTest
@testable import Pip

/// Renders the quick bar to PNGs for visual review (card, slots, selection, empty state).
/// Doesn't assert on pixels; materials may render flat under ImageRenderer.
@MainActor
final class QuickBarSnapshotTests: XCTestCase {

    private static let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("pip-quickbar-preview", isDirectory: true)

    func testRenderQuickBarPreviews() throws {
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)
        for (name, query) in [("empty", ""), ("query-c", "c"), ("no-results", "zzz")] {
            for scheme in [ColorScheme.light, .dark] {
                let model = Self.sampleModel()
                model.query = query
                if query == "c" { model.moveSelection(by: 1) }   // show the selection off the first row
                let url = Self.outputDir.appendingPathComponent("quickbar-\(name)-\(scheme == .dark ? "dark" : "light").png")
                try render(model: model, scheme: scheme, to: url)
                print("Quick bar preview: \(url.path)")
            }
        }
    }

    private func render(model: QuickBarModel, scheme: ColorScheme, to url: URL) throws {
        let height = QuickBarView.panelHeight(resultCount: model.results.count, queryIsEmpty: model.query.isEmpty)
        let view = QuickBarView(model: model, isSnapshot: true, onOpen: { _ in }, onCancel: {})
            .frame(width: QuickBarView.panelWidth, height: height)
            // Panel outline, to check the panel hugs the card and leaves room for the shadow.
            .overlay(Rectangle().strokeBorder(Color.red.opacity(0.4), lineWidth: 1))
            .background {
                // A stand-in desktop so the translucent card has something behind it.
                ZStack {
                    Rectangle().fill(scheme == .dark ? Color(white: 0.16) : Color(white: 0.9))
                    Circle().fill(Color.accentColor.opacity(0.35)).frame(width: 160, height: 160)
                        .offset(x: -180, y: 10)
                }
                .clipped()
            }
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return XCTFail("render failed") }
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
        try data.write(to: url)
    }

    /// The bundled catalog's shape: installed-looking apps (system icons stand in), websites,
    /// not-installed apps, and CLI tools under ChatGPT and Claude.
    private static func sampleModel() -> QuickBarModel {
        let web = URL(string: "https://example.com")!
        let registry = AppRegistry(targets: [
            AITarget(id: "chatgpt", name: "ChatGPT", aliases: ["gpt"], webURL: web, kind: .app),
            AITarget(id: "codex", name: "Codex", webURL: web, kind: .cli, parent: "chatgpt"),
            AITarget(id: "claude", name: "Claude", aliases: ["anthropic"], webURL: web, kind: .app),
            AITarget(id: "claude-code", name: "Claude Code", aliases: ["cc"], webURL: web, kind: .cli, parent: "claude"),
            AITarget(id: "gemini", name: "Gemini", webURL: web, kind: .web),
            AITarget(id: "grok", name: "Grok", webURL: web, kind: .web),
            AITarget(id: "copilot", name: "Copilot", webURL: web, kind: .app),
            AITarget(id: "perplexity", name: "Perplexity", webURL: web, kind: .app),
            AITarget(id: "cursor", name: "Cursor", webURL: web, kind: .app),
        ])
        let installed = ["chatgpt": "/System/Applications/Notes.app",
                         "claude": "/System/Applications/Calendar.app",
                         "copilot": "/System/Applications/Maps.app"]
        let names = Dictionary(uniqueKeysWithValues: registry.targets.map { ($0.id, $0.name) })
        let rows = registry.targets.map { target -> QuickBarResult in
            let icon = installed[target.id].map { NSWorkspace.shared.icon(forFile: $0) }
            let destination: String = switch target.kind {
            case .app: icon == nil ? "Website" : "App"
            case .web: "Website"
            case .cli: target.parent.flatMap { names[$0] }.map { "Terminal · \($0)" } ?? "Terminal"
            }
            return QuickBarResult(target: target, icon: icon, destination: destination)
        }
        return QuickBarModel(results: rows)
    }
}
