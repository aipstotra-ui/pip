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
- [ ] **M6 Settings**: enable/reorder, custom apps, app-vs-web override, hotkeys
- [ ] **M7 Polish**: launch at login, multi-monitor, saved position, error toasts *(optimizer pass)*

## Later (out of scope for v0.1)
Voice: push-to-talk (on-device speech, alias matching; listening frames already drawn) and later wake word · Prompt handoff · drag & drop onto pet · two-way bridge · moods/skins · Windows
Developer ID signing + notarization (needs the user's Apple Developer account; ad-hoc builds reset the Terminal permission on each rebuild)
Post-launch dynamic signature check (TOCTOU hardening, low priority)
Run the Terminal AppleScript off the main thread (the first-time permission prompt blocks the UI)
Ring icons/labels based on the signature check (currently an installed-but-untrusted app shows its icon even though the website opens; security Low)
M6: shortcut recorder to rebind ⌃⌥Space (it's macOS's default 'next input source' shortcut, which is disabled on this Mac but may clash for other users)

## Open questions (ask the user before the milestone that needs the answer)
