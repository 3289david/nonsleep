#!/bin/bash
set -e

PLIST_DIR="$HOME/Library/LaunchAgents"

echo "Stopping daemon..."
launchctl unload "$PLIST_DIR/com.nonsleep.daemon.plist" 2>/dev/null || true
rm -f "$PLIST_DIR/com.nonsleep.daemon.plist"

echo "Removing binaries..."
sudo rm -f /usr/local/bin/nonsleep
sudo rm -f /usr/local/bin/nonsleepd

echo "Removing state..."
rm -rf "$HOME/Library/Application Support/NonSleep"

echo "NonSleep uninstalled."
