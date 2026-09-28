# QA checklist

Run only the sections for completed milestones. Report pass/fail per line, with screenshots saved to the scratchpad.

**Automated QA limitations**: Terminal lacks Screen Recording and Accessibility permissions, so screenshots and System Events queries fail. Window checks work through `CGWindowListCopyWindowInfo` (via `swift -e`).

## M1
- [ ] Pet appears, has no Dock icon, and the menu-bar item is present
- [ ] Pet stays on top of other apps and follows across Spaces and full-screen apps
- [ ] Pet can be dragged. Transparent areas pass clicks through

Last run 2026-09-27: window layer 3 (floating), 96×96pt, idle CPU 0.0%, RSS ~85MB, 3/3 unit tests pass

## M2
- [ ] Click the pet → the menu lists the enabled targets
- [ ] Running app → it's focused, with no second instance
- [ ] Installed but not running → it launches
- [ ] Not installed → the website opens in the default browser
- [ ] Ring: Esc/click-outside/arrow keys+Return work; ring stays on-screen near edges
- [ ] Claude Code: folder menu above Pip → pick folder → first time macOS asks 'Pip wants to control Terminal' → Terminal opens `claude` in that folder
- [ ] Hover Claude/ChatGPT → branches appear (Chat + Claude Code / Codex); the connector never crosses other slots; Tab enters the branch
- [ ] Codex branch → folder menu → Terminal runs `codex`
- [ ] Ring looks like one frosted band with circular slots; the hover label is never covered by an icon (light and dark)
- [ ] Drawn symbols for Gemini/Grok/Perplexity/Cursor in light and dark
- [ ] Snapshot previews: RingMenuSnapshotTests writes PNGs to ~/Library/Containers/com.pipapp.Pip/Data/tmp/pip-ring-preview/

Last run 2026-09-27: qa-plan decisions all as expected, sandbox active, idle CPU 0.0%, 70/70 tests pass

## M3
- [ ] ⌃⌥Space opens the quick bar on the mouse's screen
- [ ] "cla" → Claude first
- [ ] ↑/↓, Return, Esc, the hotkey again, and a click elsewhere all close it
- [ ] "codex" → folder menu near the bar
- [ ] the ring and bar are never both open
- [ ] light/dark previews at ~/Library/Containers/com.pipapp.Pip/Data/tmp/pip-quickbar-preview/

## M4
- [ ] Each state animates: idle, walk, happy (after a summon), sleep (after idle time), listening
- [ ] CPU usage stays low when idle (check Activity Monitor)

## M5
- [ ] First use asks for microphone and speech permissions
- [ ] Hold push-to-talk, say "open Gemini" → gemini.google.com opens
- [ ] An unknown phrase gives friendly feedback

## M6–M7
- [ ] Web override per app is respected
- [ ] Add a custom app (from a .app and from a URL), reorder, disable
- [ ] Launch at login works. Position is remembered. Works across multiple monitors
