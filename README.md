# NonSleep

<a href="https://3289david.github.io/nonsleep">https://img.shields.io/badge/Website-Github%20Pages-20B2AA?style=for-the-badge<a/>

Prevent macOS from sleeping when the lid is closed.

Tiny. Invisible. Native.

## Install

```bash
brew install nonsleep
```

Or build from source:

```bash
git clone https://github.com/3289david/nonsleep.git
cd nonsleep
make install
```

## Usage

### CLI

```bash
nonsleep              # Enable — keeps system awake (Ctrl+C to stop)
nonsleep stop         # Disable
nonsleep status       # Show current state
nonsleep toggle       # Toggle ON/OFF
nonsleep for 2h       # Enable for 2 hours
nonsleep for 30m      # Enable for 30 minutes
```

### Menu Bar

Click the moon icon in your menu bar to toggle. That's it.

```
● NonSleep
────────────
Disable Sleep: ON
Settings...
Quit NonSleep
```

### Daemon

The background daemon (`nonsleepd`) runs via LaunchAgent and handles:

- IOKit power assertions
- Lid close/open detection
- Display sleep on lid close
- Display wake on lid open
- State file sync with CLI and menu bar app

Installed automatically with `make install`.

## How It Works

```
Lid closes → Display OFF → System stays awake
Lid opens  → Display ON  → Resume normally
```

NonSleep uses three mechanisms:

1. **IOKit Power Assertions** — `kIOPMAssertPreventUserIdleSystemSleep` prevents the system from sleeping
2. **Lid State Detection** — Polls `AppleClamshellState` from IORegistry to detect lid open/close
3. **Display Control** — Sends `IORequestIdle` to `IODisplayWrangler` to sleep/wake the display

No kernel extensions. No SIP bypass. No root required.

## Architecture

```
┌─────────────┐   ┌──────────┐   ┌──────────┐
│  Menu Bar   │   │   CLI    │   │  Daemon  │
│  (SwiftUI)  │   │  (Swift) │   │ (launchd)│
└──────┬──────┘   └────┬─────┘   └────┬─────┘
       │               │              │
       └───────────┬───┘──────────────┘
                   │
         ┌─────────▼─────────┐
         │   NonSleepCore    │
         │                   │
         │  StateManager     │
         │  PowerManager     │
         │  LidWatcher       │
         │  NonSleepController│
         └───────────────────┘
                   │
         ┌─────────▼─────────┐
         │    state.json     │
         │ ~/Library/App...  │
         │ Support/NonSleep/ │
         └───────────────────┘
```

All components share state through `~/Library/Application Support/NonSleep/state.json`.

## State File

```json
{
  "enabled": true,
  "temporaryUntil": "2025-01-15T14:30:00Z"
}
```

The daemon watches this file for changes. The CLI and menu bar app read/write it directly.

## Settings

Available in the menu bar app under Settings:

| Setting | Description |
|---------|-------------|
| Launch at Login | Start NonSleep when you log in |
| Enable on Startup | Activate sleep prevention on launch |
| Show Notifications | Notify on state changes |

## LaunchAgent

The daemon runs as a LaunchAgent at `~/Library/LaunchAgents/com.nonsleep.daemon.plist`.

```bash
# Manual control
launchctl load   ~/Library/LaunchAgents/com.nonsleep.daemon.plist
launchctl unload ~/Library/LaunchAgents/com.nonsleep.daemon.plist
```

## Uninstall

```bash
make uninstall
```

Or manually:

```bash
launchctl unload ~/Library/LaunchAgents/com.nonsleep.daemon.plist
rm ~/Library/LaunchAgents/com.nonsleep.daemon.plist
rm /usr/local/bin/nonsleep /usr/local/bin/nonsleepd
rm -rf ~/Library/Application\ Support/NonSleep
```

## Requirements

- macOS 13.0+
- Xcode 14.0+ (build only)
- Swift 5.9+ (build only)

## Tech Stack

| Component | Technology |
|-----------|------------|
| GUI | SwiftUI + MenuBarExtra |
| Core | IOKit Framework |
| CLI | Swift ArgumentParser |
| IPC | Shared state file (JSON) |
| Daemon | launchd LaunchAgent |
| Build | Swift Package Manager |

## License

MIT
