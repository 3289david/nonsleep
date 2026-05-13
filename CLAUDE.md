# CLAUDE.md

## Project

NonSleep — macOS utility to prevent system sleep when the lid is closed. Menu bar app + CLI + background daemon.

## Build

```bash
swift build                    # Debug build
swift build -c release         # Release build
make install                   # Build + install everything
make uninstall                 # Remove everything
make clean                     # Clean build artifacts
```

## Architecture

Three executables share one library:

- `NonSleepCore` — IOKit power assertions, lid detection, state management
- `NonSleepCLI` → `nonsleep` binary — ArgumentParser CLI
- `NonSleepDaemon` → `nonsleepd` binary — launchd daemon
- `NonSleepApp` — SwiftUI MenuBarExtra app (separate Xcode target)

State synced via `~/Library/Application Support/NonSleep/state.json`.

## Key Files

| File | Purpose |
|------|---------|
| `Sources/NonSleepCore/PowerManager.swift` | IOKit assertions, display sleep/wake |
| `Sources/NonSleepCore/LidWatcher.swift` | Clamshell state polling |
| `Sources/NonSleepCore/StateManager.swift` | JSON state read/write |
| `Sources/NonSleepCore/NonSleepController.swift` | Orchestrates all components |
| `Sources/NonSleepCLI/CLI.swift` | CLI commands |
| `Sources/NonSleepDaemon/Daemon.swift` | Daemon entry point |

## Rules

- No third-party deps except `swift-argument-parser`
- No comments unless explaining a non-obvious workaround
- All IOKit calls go through `PowerManager.swift`
- All state changes go through `StateManager.swift`
- macOS 13.0+ minimum
- `LSUIElement = true` — no dock icon for the app
