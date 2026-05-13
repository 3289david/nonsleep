# AGENTS.md

Instructions for AI agents working on this codebase.

## Project Overview

NonSleep is a macOS utility that prevents system sleep when the lid is closed. It has three components: a SwiftUI menu bar app, a CLI tool, and a background daemon. All share a core library (`NonSleepCore`) and communicate via a shared JSON state file.

## Repository Structure

```
NonSleep/
├── Package.swift              # Swift Package Manager manifest
├── Makefile                   # Build and install targets
├── Sources/
│   ├── NonSleepCore/          # Shared library
│   │   ├── PowerManager.swift     # IOKit power assertions
│   │   ├── LidWatcher.swift       # Lid state detection
│   │   ├── StateManager.swift     # JSON state file I/O
│   │   └── NonSleepController.swift # Orchestrator
│   ├── NonSleepCLI/           # CLI tool (nonsleep)
│   │   └── CLI.swift              # ArgumentParser commands
│   ├── NonSleepDaemon/        # Background daemon (nonsleepd)
│   │   └── Daemon.swift           # Daemon entry point
│   └── NonSleepApp/           # Menu bar app
│       ├── NonSleepApp.swift      # App entry point
│       ├── AppDelegate.swift      # State management
│       ├── Views/
│       │   ├── MenuBarView.swift  # Menu bar dropdown
│       │   └── SettingsView.swift # Settings window
│       └── Resources/
│           └── Info.plist         # App metadata
├── scripts/
│   ├── install.sh             # Install script
│   ├── uninstall.sh           # Uninstall script
│   └── com.nonsleep.daemon.plist  # LaunchAgent config
├── website/
│   └── index.html             # Project website
├── nonsleep.rb                # Homebrew formula
└── package.json               # npm metadata
```

## Build Commands

```bash
swift build                    # Debug build
swift build -c release         # Release build
make install                   # Build + install CLI, daemon, LaunchAgent
make uninstall                 # Remove everything
make clean                     # Clean build artifacts
```

## Key Technical Details

### Power Management (IOKit)

- `PowerManager.swift` uses `IOPMAssertionCreateWithName` with `kIOPMAssertPreventUserIdleSystemSleep`
- Display sleep/wake via `IORegistryEntrySetCFProperty` on `IODisplayWrangler`
- No kernel extensions or elevated privileges required

### Lid Detection

- `LidWatcher.swift` polls `AppleClamshellState` from `AppleACPIPlatformExpert` every 2 seconds
- Traverses IORegistry recursively to find the property
- Fires `onLidStateChanged` callback on state transitions

### State Sync

- All components use `~/Library/Application Support/NonSleep/state.json`
- Daemon watches the file with `DispatchSource.makeFileSystemObjectSource`
- Menu bar app watches with the same mechanism
- CLI reads/writes directly

### State File Format

```json
{
  "enabled": true,
  "temporaryUntil": "2025-01-15T14:30:00Z"
}
```

## Conventions

- macOS 13.0+ minimum deployment target
- Swift 5.9+
- No third-party dependencies except `swift-argument-parser` (CLI only)
- No comments unless explaining a non-obvious workaround
- Menu bar app is `LSUIElement` (no dock icon)
- Daemon uses `launchd` KeepAlive

## Testing

The CLI and daemon can be tested directly:

```bash
.build/debug/nonsleep status   # Check state
.build/debug/nonsleep toggle   # Toggle state
.build/debug/nonsleepd         # Run daemon in foreground
```

## Common Tasks

### Adding a new CLI command

1. Add a new struct conforming to `ParsableCommand` in `Sources/NonSleepCLI/CLI.swift`
2. Register it in `NonSleepCLI.configuration.subcommands`
3. Use `NonSleepController.shared` or `StateManager.shared` for state operations

### Adding a new setting

1. Add `@AppStorage` property in `Sources/NonSleepApp/Views/SettingsView.swift`
2. Add corresponding toggle in `GeneralSettingsView`
3. If the setting affects core behavior, add it to `NonSleepState` and update `StateManager`

### Modifying power management behavior

All power management goes through `PowerManager.swift`. Do not call IOKit APIs directly from other files.
