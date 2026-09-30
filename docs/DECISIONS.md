# Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-09-27 | Launch + focus only for v0.1 | Reliable MVP. Prompt injection is fragile for each app |
| 2026-09-27 | macOS only, native Swift | Best transparent always-on-top window and app control; the user is on a Mac |
| 2026-09-27 | Inputs: click menu, hotkey quick bar, voice | User choice. Drag & drop postponed until prompt handoff exists |
| 2026-09-27 | Voice = push-to-talk, on-device | Avoids the battery and privacy cost of an always-on wake word |
| 2026-09-27 | Desktop app if installed, else web (override per app) | Least surprise; works without installs |
| 2026-09-27 | Roster: chat assistants + coding tools + custom | User choice |
| 2026-09-27 | Artwork generated with AI; frames `<state>_<n>` | User choice; art can be swapped later |
| 2026-09-27 | ~~Unsandboxed~~ (superseded: see "App Sandbox ON" below) | — |
| 2026-09-27 | Subagent loop per milestone + lean docs | User request, for token and context efficiency |
| 2026-09-27 | Pixel-art pet style | User choice |
| 2026-09-27 | Radial ring menu around the pet | User choice |
| 2026-09-27 | Hotkeys: ⌥Space quick bar, hold ⌥⌘ push-to-talk | User confirmed |
| 2026-09-27 | Added security-reviewer + ui-designer subagents | User approved |
| 2026-09-27 | Rename away from "Pip" (new name TBD) | User request |
| 2026-09-27 | App name: **Pip** (the pet is also Pip) | User choice |
| 2026-09-27 | Pet = pixel-art slime/blob | User choice; expressive and simple to animate |
| 2026-09-27 | Claude Code: Terminal.app + ask for the folder each time (recent first) | Always opens in the right project |
| 2026-09-27 | Build output in $TMPDIR/pip-dd; project uses folder-synced groups | A build folder inside the project fails under the sandbox. New files need no edits to the project file |
| 2026-09-27 | App Sandbox ON | Security review showed it's feasible with an Apple-Events exception for Terminal only |
| 2026-09-27 | Hardened runtime forced for ad-hoc signing via --options=runtime | Release: no get-task-allow. Debug only: library validation off for XCTest |
| 2026-09-27 | Launch only apps whose signature passes | Bundle ID + (Mac App Store cert OR Developer ID cert), plus the pinned team when known. Otherwise open the website with a warning |
| 2026-09-27 | custom.json validation: no catalog id/name/alias reuse, no cli, O_NOFOLLOW+fstat read, one bad entry doesn't discard file | Prevent impersonation and command injection; malformed entries are logged only |
| 2026-09-27 | Claude Code: constant AppleScript with folder parameter and quoted form of | Security: no shell interpolation. Recent folders are security-scoped bookmarks |
| 2026-09-27 | Ring menu: full ring or 180°/90° arc away from edges; keyboard: arrows/Return/Esc | Adapt to screen edges; standard nav |
| 2026-09-27 | Grok = xAI web only; ignore the local Grok Bot.app (Anysphere) | User choice |
| 2026-09-27 | Git: local commit per milestone; GitHub push only on the user's "commit" | User request |
| 2026-09-27 | Ring style: Apple Pencil Pro-like radial palette. One frosted-glass band (full ring or arc), 40pt circular slots, a single top-level name label outside the band (with suffix · Website / · Terminal). Clicking empty ring area or Pip closes it. | user feedback (label was hidden behind icons; wanted minimal circles) |
| 2026-09-27 | Removed VS Code and Windsurf from the catalog | user request |
| 2026-09-27 | Branches: items with children (Claude → Claude Code, ChatGPT → Codex) fan out beyond the ring on hover (120ms); clicking the parent opens chat. Tab enters the branch. | user idea |
| 2026-09-27 | Codex = `codex` CLI in Terminal (like Claude Code) | user choice |
| 2026-09-27 | CLI tools are a closed enum CLITool {claude, codex}; the AppleScript takes path and command as parameters, both via `quoted form of`. `claude`/`codex` resolve via the login shell PATH (accepted risk) | security |
| 2026-09-27 | Logos: original drawn symbols (AISymbols.swift); no downloaded brand assets | the user declined downloads; Gemini's icon needs Google's permission for distribution |
| 2026-09-27 | ChatGPT keeps bundle id com.openai.codex: on this Mac the installed app named 'ChatGPT' uses it (verified) | security review Low note |
| 2026-09-27 | Claude Code project `.claude/settings.json` has `ask` rules for sudo/curl/wget/rm -rf/git push/gh repo create/~/.ssh/~/.aws | user rule, ask before risky actions |
| 2026-09-27 | Global hotkey: native Carbon `RegisterEventHotKey`, no package | User choice; no third-party code, works sandboxed, needs no Accessibility permission |
| 2026-09-27 | Quick bar shortcut ⌃⌥Space (not ⌥Space) | ⌥Space is ChatGPT desktop's default shortcut |
| 2026-09-27 | Quick bar lists all 9 targets, including branch tools | User choice |
| 2026-09-27 | Quick bar ranking: exact > prefix > word-prefix > initials (cc → Claude Code) > contains > subsequence; aliases ×0.9; branch tools −10 on near-ties | Claude should outrank Codex for 'c' |
| 2026-09-27 | Quick bar is a nonactivating key panel at .modalPanel level that closes on resign-key | Typing without stealing focus; security review found it acceptable |
| 2026-09-27 | Hotkey conflicts can't be detected (Carbon only rejects duplicates inside Pip); M6 adds a shortcut recorder | Code review. ⌃⌥Space is macOS's 'next input source' default (disabled on this Mac) |
| 2026-09-28 | Pip art: AI-generated sprite sheet (Higgsfield nano_banana_2), processed in Higgsfield's cloud sandbox (no file downloaded to the Mac), snapped to its 30px grid → 20×20 frames, hand touch-ups | User choice |
| 2026-09-28 | Canvas 20×20 at 5× = 100pt window (was 16×16/96pt) | The AI frames need up to 18px plus jump headroom, and an integer scale keeps them crisp |
| 2026-09-28 | Pet behavior: stays put; idle breathe/blink; happy bounce after a summon; sleeps after 5 min without interaction; wakes on hover/click/drag; listening frames reserved for M5 | User choice |
| 2026-09-28 | Rendering: cached 20×20 CGImages swapped on a CALayer (nearest-neighbor), Task.sleep between frames, paused when occluded or displays sleep; no SwiftUI in the pet redraw path | Optimizer measured idle CPU 0.28% → 0.0% and RSS 83 → 80 MB |
| 2026-09-28 | Voice (M5) moved to future development; listening state/frames kept for later | User decision |
| 2026-09-28 | Settings: standard macOS Settings window (menu bar + right-click Pip) | User choice |
| 2026-09-28 | Custom entries: installed Mac apps (signature verified and team pinned at add time) and https websites; no custom terminal tools | User choice; custom commands are too risky |
| 2026-09-28 | Ring shows the first 10 enabled apps in the user's order; everything enabled stays searchable in the quick bar | User choice |
| 2026-09-28 | Branch tools (Claude Code, Codex): show/hide only | User choice |
| 2026-09-28 | Preferences (order, hidden, preferWeb, hotKey) stored as sanitized JSON in UserDefaults `pip.preferences`; custom entries in custom.json | Small, validated, easy to reset |
| 2026-09-28 | AITarget.webURL is optional (custom apps may have no website); apps without a website refuse with a message instead of falling back | Custom apps |
| 2026-09-28 | Custom app add: signature verified off the main thread; the team is read from the same validated code object (no re-read) | Security review |
| 2026-09-28 | Look-alike check transliterates to Latin (catches Cyrillic 'Claudе') and bundle ids are compared case-insensitively | Security review |
| 2026-09-28 | custom.json written as a 0600 temp file then renamed; saving more than 50 entries is refused, never truncated | Security review |
| 2026-09-28 | Shortcut recorder pauses the live hotkey while recording; the empty system Settings scene has its command removed (⌘, can't open a blank window) | Code review |
| 2026-09-29 | Full ring: host view never resizes the panel (sizingOptions = []), ring centered on the slime's body (bodyCenter), panel kept below the menu bar | User saw the ring at varying heights; a Debug sweep (`--qa-ring`) measured macOS pushing the panel down 30–33pt under the menu bar. Now 0 drift at 48 positions |
| 2026-09-29 | Edge/corner arcs kept as the original 180°/90° candidates | User preferred them over a wider-arc/shifted-center experiment, which was reverted |
