# Roadmap

Status key: [ ] todo · [~] in progress · [x] done

## v0.1: launch + focus
- [x] **Setup**: install Xcode (blocker, the user has to do this)
- [x] **M1 Skeleton**: Xcode project, menu-bar agent, transparent draggable pet (placeholder)
- [~] **M2 Launcher + registry**: catalog.json, detection, open/focus/web fallback, click menu *(awaiting user manual check)*
  - Click-vs-drag threshold: done
- [ ] **M3 Quick bar**: ⌥Space panel, fuzzy search, keyboard navigation
- [ ] **M4 Sprite animation**: state machine + AI-generated artwork *(optimizer pass)*
- [ ] **M5 Voice**: push-to-talk, permissions, alias matching
- [ ] **M6 Settings**: enable/reorder, custom apps, app-vs-web override, hotkeys
- [ ] **M7 Polish**: launch at login, multi-monitor, saved position, error toasts *(optimizer pass)*

## Later (out of scope for v0.1)
Prompt handoff · drag & drop onto pet · two-way bridge · wake-word voice · moods/skins · Windows
Developer ID signing + notarization (needs the user's Apple Developer account; ad-hoc builds reset the Terminal permission on each rebuild)
Post-launch dynamic signature check (TOCTOU hardening, low priority)
Run the Terminal AppleScript off the main thread (the first-time permission prompt blocks the UI)
Ring icons/labels based on the signature check (currently an installed-but-untrusted app shows its icon even though the website opens; security Low)

## Open questions (ask the user before the milestone that needs the answer)
