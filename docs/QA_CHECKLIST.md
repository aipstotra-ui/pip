# QA checklist

Run only the sections for completed milestones. Report pass/fail per line, with screenshots saved to the scratchpad.

**Automated QA limitations**: Terminal lacks Screen Recording and Accessibility permissions, so screenshots and System Events queries fail. Window checks work through `CGWindowListCopyWindowInfo` (via `swift -e`).

## M1
- [ ] Pet appears, has no Dock icon, and the menu-bar item is present
- [ ] Pet stays on top of other apps and follows across Spaces and full-screen apps
- [ ] Pet can be dragged. Transparent areas pass clicks through

Last run 2026-09-27: window layer 3 (floating), 100×100pt, idle CPU 0.0%, RSS ~85MB, 3/3 unit tests pass

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
- [ ] breathe/blink
- [ ] happy bounce after summon
- [ ] sleeps after 5 min idle, wakes on hover
- [ ] upright, crisp on Retina and external displays
- [ ] idle CPU ≤ 0.1%
- [ ] sprite preview at ~/Library/Containers/com.pipapp.Pip/Data/tmp/pip-sprite-preview/

## M5 (moved to future development: voice)

## M6 Settings
- [ ] right-click → Settings window opens
- [ ] reorder apps in the list → the ring reflects the new order on next open
- [ ] toggle an app off → the ring reflects this on next open
- [ ] toggle a branch tool (Claude Code / Codex) off → it disappears from the ring
- [ ] Open as Website toggle per app is respected
- [ ] add a website (https ok, http refused with error message)
- [ ] add an installed app signature is verified; unsigned app is refused with message
- [ ] remove an app with confirmation dialog
- [ ] shortcut recorder: ⌃⌥P works, P alone shows warning, Esc cancels, Reset clears the binding
- [ ] ⌘, doesn't open a blank window
- [ ] apps past 10 enabled are searchable in quick bar only (not shown in ring)

## M7
- [ ] Launch at login works
- [ ] Position is remembered across restarts
- [ ] Works across multiple monitors
