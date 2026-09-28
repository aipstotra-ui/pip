# Architecture

```
Pip.app (LSUIElement menu-bar agent)
├── PetWindow        NSPanel: borderless, clear, .floating, canJoinAllSpaces, draggable
│   └── SpriteView   frame animator driven by PetStateMachine (idle/walk/happy/sleep/listening)
├── PetMenu          popover on pet click → enabled AI targets
├── QuickBar         global hotkey (⌥Space) → fuzzy search panel
├── VoiceController  push-to-talk → SFSpeechRecognizer (on-device) → alias match
├── AppRegistry      catalog.json + custom.json → [AITarget]; installed-app detection
├── Launcher         the ONLY summon path
├── Settings         SwiftUI window
└── MenuBarController show/hide pet, settings, quit
```

## Summon path (all inputs converge here)
```
click / quick bar / voice → AITarget → Launcher.summon(target)
  1. (M6) preference == .web? → open webURL
  2. running app with bundleId AND passes CodeTrust? → activate()
  3. running/installed AND passes CodeTrust? → openApplication(at:)
  4. kind == .cli? → open terminal + run command
  5. else → open webURL with warning bubble
  → PetStateMachine.react(.happy)
```

## File ownership
| Concern | Files |
|---|---|
| App lifecycle, menu bar | `App/PipApp.swift`, `AppDelegate.swift`, `MenuBarController.swift` |
| Pet window and animation | `Pet/PetWindow.swift`, `SpriteView.swift`, `PetStateMachine.swift`, `PetMenuView.swift`, `PixelArt.swift`, `SpeechBubble.swift` |
| Quick bar | `QuickBar/QuickBarPanel.swift`, `QuickBarView.swift`, `FuzzyMatcher.swift` |
| Voice | `Voice/VoiceController.swift` |
| Data | `Registry/AITarget.swift`, `AppRegistry.swift`, `catalog.json`, `TargetValidator.swift` |
| Launching | `Launch/Launcher.swift`, `CodeTrust.swift`, `ClaudeCodeLauncher.swift`, `ClaudeCodeFlow.swift`, `RecentFolders.swift` |
| Menu | `Menu/RingLayout.swift`, `RingMenuView.swift`, `RingMenuController.swift` |
| Settings | `Settings/SettingsView.swift` |

## AITarget schema
`{ id, name, aliases[], bundleIds[], teamId?, webURL (https only), kind: app|web|cli }`
User entries live in `~/Library/Containers/com.pipapp.Pip/Data/Library/Application Support/Pip/custom.json` (sandbox container). They are validated by `TargetValidator`, can't reuse a built-in id, and can't be `cli`.
