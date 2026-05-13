#!/bin/bash
set -e

echo "Building NonSleep..."

swift build -c release

BIN_DIR="/usr/local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"

echo "Installing CLI..."
sudo cp .build/release/nonsleep "$BIN_DIR/nonsleep"
sudo chmod +x "$BIN_DIR/nonsleep"

echo "Installing daemon..."
sudo cp .build/release/nonsleepd "$BIN_DIR/nonsleepd"
sudo chmod +x "$BIN_DIR/nonsleepd"

echo "Installing LaunchAgent..."
mkdir -p "$PLIST_DIR"
cp scripts/com.nonsleep.daemon.plist "$PLIST_DIR/"
launchctl load "$PLIST_DIR/com.nonsleep.daemon.plist" 2>/dev/null || true

echo "Done. Run 'nonsleep' to get started."
