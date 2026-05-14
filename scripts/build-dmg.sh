#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/release"
APP_NAME="NonSleep"
APP_BUNDLE="$ROOT/dist/${APP_NAME}.app"
DMG_NAME="NonSleep-1.0.0"
DMG_DIR="$ROOT/dist/dmg"
DMG_PATH="$ROOT/dist/${DMG_NAME}.dmg"
VOLUME_NAME="NonSleep"

echo "==> Cleaning previous build..."
rm -rf "$ROOT/dist"
mkdir -p "$ROOT/dist"

# ── Step 1: Build CLI and Daemon via SPM ──
echo "==> Building CLI and Daemon (release)..."
cd "$ROOT"
swift build -c release 2>&1

# ── Step 2: Build the SwiftUI App ──
echo "==> Building NonSleep.app..."

APP_SOURCES=(
    "$ROOT/Sources/NonSleepApp/NonSleepApp.swift"
    "$ROOT/Sources/NonSleepApp/AppDelegate.swift"
    "$ROOT/Sources/NonSleepApp/Views/MenuBarView.swift"
    "$ROOT/Sources/NonSleepApp/Views/SettingsView.swift"
)

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Library/LaunchAgents"

swiftc \
    -O \
    -target arm64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework SwiftUI \
    -framework AppKit \
    -framework ServiceManagement \
    -framework IOKit \
    -o "$APP_BUNDLE/Contents/MacOS/NonSleep" \
    "${APP_SOURCES[@]}" 2>&1

echo "==> Assembling app bundle..."

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NonSleep</string>
    <key>CFBundleDisplayName</key>
    <string>NonSleep</string>
    <key>CFBundleIdentifier</key>
    <string>com.nonsleep.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>NonSleep</string>
    <key>CFBundleIconFile</key>
    <string>NonSleep</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# Copy icon
cp "$ROOT/assets/NonSleep.icns" "$APP_BUNDLE/Contents/Resources/NonSleep.icns"

# Copy CLI tools into app bundle
cp "$BUILD_DIR/nonsleep" "$APP_BUNDLE/Contents/MacOS/nonsleep-cli"
cp "$BUILD_DIR/nonsleepd" "$APP_BUNDLE/Contents/MacOS/nonsleepd"

# Copy LaunchAgent plist
cp "$ROOT/scripts/com.nonsleep.daemon.plist" "$APP_BUNDLE/Contents/Library/LaunchAgents/"

# PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> App bundle created at $APP_BUNDLE"

# ── Step 3: Ad-hoc code sign ──
echo "==> Code signing..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 || echo "   (ad-hoc signing — notarization requires Developer ID)"

# ── Step 4: Create DMG ──
echo "==> Creating DMG..."

mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -sf /Applications "$DMG_DIR/Applications"

# Create a background image for the DMG
"$ROOT/scripts/generate-dmg-bg.swift" "$DMG_DIR/.background" 2>/dev/null || true

# Create the DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" 2>&1

echo ""
echo "=== Build Complete ==="
echo ""
echo "  App:    $APP_BUNDLE"
echo "  DMG:    $DMG_PATH"
echo "  CLI:    $BUILD_DIR/nonsleep"
echo "  Daemon: $BUILD_DIR/nonsleepd"
echo ""
echo "  DMG size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
