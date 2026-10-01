# Roadmap

Status key: [ ] todo · [~] in progress · [x] done

## v0.1: launch + focus
- [x] **Setup**: install Xcode (blocker, the user has to do this)
- [x] **M1 Skeleton**: Xcode project, menu-bar agent, transparent draggable pet (placeholder)
- [x] **M2 Launcher + registry**: catalog.json, detection, open/focus/web fallback, click menu
  - Click-vs-drag threshold: done
- [x] **M3 Quick bar**: ⌃⌥Space panel, fuzzy search, keyboard navigation
- [x] **M4 Sprite animation**: state machine + AI-generated artwork *(optimizer pass)*
- ~~M5 Voice~~: moved to Later (user decision, 2026-09-28)
- [x] **M6 Settings**: enable/reorder, custom apps, app-vs-web override, hotkeys
- [x] **M7 Polish**: friendlier, actionable error bubbles + optimizer pass

## Later (out of scope for v0.1)
### "More than a shortcut" ideas (user, 2026-09-30; plan these after M7)
1. Ask from the quick bar: `claude: …` opens the AI with the question prefilled (URL params, clipboard fallback); ask several AIs at once to compare
2. Send to AI from anywhere: selected text via macOS Services + shortcut, or drag text/files/images onto Pip, then pick an AI
3. Saved prompts ("Summarize this", "Review for bugs") applied to what you send
4. Context-aware ring: reorder by the frontmost app (Xcode/Terminal → Claude Code/Codex; browser → Perplexity)
5. Work modes: one click opens a set (Coding: Cursor + Claude Code in a folder; Research: Perplexity + Claude)
6. Pip reports back: Claude Code/Codex hooks tell Pip when a long task finishes (tightly limited `pip://` messages), Pip bounces and shows a bubble
7. Mood and personality: reactions to hover, busy streaks, late nights
8. Voice: push-to-talk (on-device speech, alias matching; listening frames already drawn), later a wake word

Each adds a new path in/out of Pip (clipboard, dropped files, messages from tools) and needs its own security review.

### Other
Launch at login (off by default; needs Pip installed in /Applications) · multi-monitor recovery while running · "Reset Pip's position" · app icon from the pixel art · Settings → General tab (moved out of M7 by the user, 2026-09-30)
Two-way bridge (read replies back) · skins · Windows
Developer ID signing + notarization (needs the user's Apple Developer account; ad-hoc builds reset the Terminal permission on each rebuild)
Post-launch dynamic signature check (TOCTOU hardening, low priority)
Run the Terminal AppleScript off the main thread (the first-time permission prompt blocks the UI)
Ring icons/labels based on the signature check (currently an installed-but-untrusted app shows its icon even though the website opens; security Low)

## Open questions (ask the user before the milestone that needs the answer)
