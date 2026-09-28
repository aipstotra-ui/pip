# Pip

Native macOS desktop pet that **launches or focuses AI apps and websites** (ChatGPT, Claude, Gemini, Cursor, …).
There's no LLM inside, and v0.1 is launch + focus only. See `docs/ROADMAP.md` for scope and status.

## Read first (instead of scanning the repo)
- `docs/ARCHITECTURE.md`: components, launch path, which file owns what
- `docs/ROADMAP.md`: milestones, current status, open questions
- `docs/DECISIONS.md`: why things are the way they are
- `docs/APP_CATALOG.md`: bundle IDs and URLs for each AI app
- `docs/QA_CHECKLIST.md`: manual test script

## Stack
Swift + SwiftUI + AppKit, macOS only. **App Sandbox + hardened runtime** (`Config/Pip.entitlements`; Debug adds library-validation off for XCTest only). Menu-bar agent app (`LSUIElement`). Ad-hoc signed until a Developer ID exists.
SPM dependency: `KeyboardShortcuts` (sindresorhus). Speech: on-device `SFSpeechRecognizer`.

## Commands
```
xcodebuild -project Pip.xcodeproj -scheme Pip -derivedDataPath $TMPDIR/pip-dd build 2>&1 | grep -E "error:|BUILD"
xcodebuild -project Pip.xcodeproj -scheme Pip -derivedDataPath $TMPDIR/pip-dd test  2>&1 | grep -E "error:|failed|passed|TEST"
```
Requires full Xcode. Always build into `$TMPDIR/pip-dd` (per-user private temp; a build folder inside the project fails with a "disk I/O error" on build.db). The app is at `$TMPDIR/pip-dd/Build/Products/Debug/Pip.app`.

## Conventions
- Every summon goes through `Launcher.summon(_ target: AITarget)`. Don't open apps anywhere else.
- AI targets are data (`Registry/catalog.json` + user `custom.json`), never hardcoded in UI.
- UI and AppKit code is `@MainActor`. No polling timers; animation is driven by the display link.
- Pet frames are named `<state>_<n>` in `Assets.xcassets/Pet`.
- Keep files small and single-purpose. Add tests for pure logic (matching, registry, launch decisions).

## Workflow
Per milestone, run the subagents in `.claude/agents/` in this order:
implement (ui-designer for views) → build-fixer → test-writer → code-reviser → security-reviewer (every milestone) → code-optimizer (M4, M7) → qa-tester → docs-keeper → user review.
Subagents return summaries under 200 words. Update `docs/` rather than growing this file.
