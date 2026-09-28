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
