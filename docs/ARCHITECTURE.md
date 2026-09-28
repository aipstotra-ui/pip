# Architecture

```
Pip.app (LSUIElement menu-bar agent)
├── PetWindow        NSPanel: borderless, clear, .floating, canJoinAllSpaces, draggable
│   └── PetPixelView ← PetAnimator (idle/happy/sleeping/listening)
├── PetMenu          popover on pet click → enabled AI targets
├── QuickBar         global hotkey (⌃⌥Space) → fuzzy search panel
├── (future) VoiceController  push-to-talk → on-device speech → alias match
├── AppRegistry      catalog.json + custom.json → [AITarget]; installed-app detection
├── Launcher         the ONLY summon path
├── Settings         SwiftUI window
└── MenuBarController show/hide pet, settings, quit
```

## Summon path (all inputs converge here)
```
click / quick bar → AITarget → Launcher.summon(target)
  1. (M6) preference == .web? → open webURL
  2. running app with bundleId AND passes CodeTrust? → activate()
  3. running/installed AND passes CodeTrust? → openApplication(at:)
  4. kind == .cli? → folder menu → Terminal runs the CLITool command
  5. else → open webURL with warning bubble
  → PetStateMachine.react(.happy)
```

## File ownership
| Concern | Files |
|---|---|
| App lifecycle, menu bar | `App/PipApp.swift`, `AppDelegate.swift`, `MenuBarController.swift` |
| Pet window and animation | `Pet/PetWindow.swift (PetPixelView), PetAnimator.swift, PetStateMachine.swift, PipSprites.swift, PixelArt.swift, PixelArtImageCache.swift, SpeechBubble.swift` |
| Quick bar | `QuickBar/QuickBarController.swift`, `QuickBarView.swift`, `QuickBarModel.swift`, `FuzzyMatcher.swift` |
| Global hotkey | `App/HotKey.swift` |
| Voice (future, not built) | planned `Voice/VoiceController.swift`. `PetState.listening` and its frames are already in place |
| Data | `Registry/AITarget.swift`, `AppRegistry.swift`, `catalog.json`, `TargetValidator.swift` |
| Launching | `Launch/Launcher.swift`, `CodeTrust.swift`, `TerminalLauncher.swift`, `CLIFlow.swift`, `RecentFolders.swift` |
| Menu | `Menu/BranchLayout.swift`, `RingLayout.swift`, `RingMenuModel.swift`, `RingMenuView.swift`, `RingMenuController.swift`, `AISymbols.swift`, `TargetIcon.swift` |
| Settings | `Settings/SettingsView.swift` |

## AITarget schema
`{ id, name, aliases[], bundleIds[], teamId?, webURL (https only), kind: app|web|cli, cli?: claude|codex, parent?: id }`
User entries live in `~/Library/Containers/com.pipapp.Pip/Data/Library/Application Support/Pip/custom.json` (sandbox container). They are validated by `TargetValidator`, can't reuse a built-in id, and can't be `cli`.
