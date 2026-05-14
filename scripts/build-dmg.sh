#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.2.0"
DIST="$ROOT/dist"
SDK="$(xcrun --show-sdk-path)"

APP_SOURCES=(
    "$ROOT/Sources/NonSleepApp/NonSleepApp.swift"
    "$ROOT/Sources/NonSleepApp/AppDelegate.swift"
    "$ROOT/Sources/NonSleepApp/Views/MenuBarView.swift"
    "$ROOT/Sources/NonSleepApp/Views/SettingsView.swift"
)

INFOPLIST='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NonSleep</string>
    <key>CFBundleDisplayName</key><string>NonSleep</string>
    <key>CFBundleIdentifier</key><string>com.nonsleep.app</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>'"$VERSION"'</string>
    <key>CFBundleExecutable</key><string>NonSleep</string>
    <key>CFBundleIconFile</key><string>NonSleep</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>'

# ── Clean ──
echo "==> Cleaning..."
rm -rf "$DIST"
mkdir -p "$DIST"
cd "$ROOT"
swift package clean 2>/dev/null || true

# ── Step 1: Build arm64 ──
echo ""
echo "==> [arm64] Building CLI + Daemon..."
swift build -c release --arch arm64 2>&1

ARM_SPM="$ROOT/.build/arm64-apple-macosx/release"
ARM_DIR="$DIST/build-arm64"
mkdir -p "$ARM_DIR"
cp "$ARM_SPM/nonsleep" "$ARM_DIR/nonsleep"
cp "$ARM_SPM/nonsleepd" "$ARM_DIR/nonsleepd"

echo "==> [arm64] Building app binary..."
swiftc -O \
    -target arm64-apple-macos13.0 \
    -sdk "$SDK" \
    -framework SwiftUI -framework AppKit -framework ServiceManagement -framework IOKit \
    -o "$ARM_DIR/NonSleep" \
    "${APP_SOURCES[@]}" 2>&1

echo "==> [arm64] Verifying..."
file "$ARM_DIR/nonsleep"
file "$ARM_DIR/nonsleepd"
file "$ARM_DIR/NonSleep"

# ── Step 2: Build x86_64 ──
echo ""
echo "==> [x86_64] Building CLI + Daemon..."
swift build -c release --arch x86_64 2>&1

X86_SPM="$ROOT/.build/x86_64-apple-macosx/release"
X86_DIR="$DIST/build-x86_64"
mkdir -p "$X86_DIR"
cp "$X86_SPM/nonsleep" "$X86_DIR/nonsleep"
cp "$X86_SPM/nonsleepd" "$X86_DIR/nonsleepd"

echo "==> [x86_64] Building app binary..."
swiftc -O \
    -target x86_64-apple-macos13.0 \
    -sdk "$SDK" \
    -framework SwiftUI -framework AppKit -framework ServiceManagement -framework IOKit \
    -o "$X86_DIR/NonSleep" \
    "${APP_SOURCES[@]}" 2>&1

echo "==> [x86_64] Verifying..."
file "$X86_DIR/nonsleep"
file "$X86_DIR/nonsleepd"
file "$X86_DIR/NonSleep"

# ── Step 3: Create universal binaries ──
echo ""
echo "==> Creating universal binaries (lipo)..."
UNI_DIR="$DIST/build-universal"
mkdir -p "$UNI_DIR"

for bin in NonSleep nonsleep nonsleepd; do
    lipo -create "$ARM_DIR/$bin" "$X86_DIR/$bin" -output "$UNI_DIR/$bin"
    echo "   $bin:"
    lipo -info "$UNI_DIR/$bin"
done

# ── Step 4: Assemble .app and .dmg for each arch ──
assemble() {
    local ARCH="$1"
    local LABEL="$2"
    local BINDIR="$DIST/build-$ARCH"
    local APP="$DIST/_app_$ARCH/NonSleep.app"
    local DMG="$DIST/NonSleep-${VERSION}-${ARCH}.dmg"
    local STAGING="$DIST/_staging_$ARCH"

    echo ""
    echo "==> [$LABEL] Assembling NonSleep.app..."

    mkdir -p "$APP/Contents/MacOS"
    mkdir -p "$APP/Contents/Resources"
    mkdir -p "$APP/Contents/Library/LaunchAgents"

    cp "$BINDIR/NonSleep"  "$APP/Contents/MacOS/NonSleep"
    cp "$BINDIR/nonsleep"  "$APP/Contents/MacOS/nonsleep-cli"
    cp "$BINDIR/nonsleepd" "$APP/Contents/MacOS/nonsleepd"
    echo "$INFOPLIST" > "$APP/Contents/Info.plist"
    cp "$ROOT/assets/NonSleep.icns" "$APP/Contents/Resources/NonSleep.icns"
    cp "$ROOT/scripts/com.nonsleep.daemon.plist" "$APP/Contents/Library/LaunchAgents/"
    echo -n "APPL????" > "$APP/Contents/PkgInfo"

    echo "   Verifying main binary:"
    lipo -info "$APP/Contents/MacOS/NonSleep"
    lipo -info "$APP/Contents/MacOS/nonsleep-cli"
    lipo -info "$APP/Contents/MacOS/nonsleepd"

    echo "   Code signing..."
    codesign --force --deep --sign - "$APP" 2>&1

    echo "   Creating DMG..."
    mkdir -p "$STAGING"
    cp -R "$APP" "$STAGING/"
    ln -sf /Applications "$STAGING/Applications"

    hdiutil create \
        -volname "NonSleep" \
        -srcfolder "$STAGING" \
        -ov -format UDZO -imagekey zlib-level=9 \
        "$DMG" 2>&1

    rm -rf "$STAGING"
    echo "   $DMG ($(du -h "$DMG" | cut -f1))"
}

assemble "arm64"     "Apple Silicon"
assemble "x86_64"    "Intel"
assemble "universal" "Universal"

# ── Cleanup ──
rm -rf "$DIST/build-arm64" "$DIST/build-x86_64" "$DIST/build-universal"
rm -rf "$DIST/_app_arm64" "$DIST/_app_x86_64" "$DIST/_app_universal"

# ── Verify final DMGs ──
echo ""
echo "==> Final verification — mounting each DMG..."
for arch in arm64 x86_64 universal; do
    dmg="$DIST/NonSleep-${VERSION}-${arch}.dmg"
    echo ""
    echo "--- $arch ---"
    hdiutil attach "$dmg" -nobrowse -mountpoint "/tmp/nonsleep_verify_$arch" 2>/dev/null | tail -1
    echo "  App binary:"
    lipo -info "/tmp/nonsleep_verify_$arch/NonSleep.app/Contents/MacOS/NonSleep"
    echo "  CLI binary:"
    lipo -info "/tmp/nonsleep_verify_$arch/NonSleep.app/Contents/MacOS/nonsleep-cli"
    echo "  Daemon binary:"
    lipo -info "/tmp/nonsleep_verify_$arch/NonSleep.app/Contents/MacOS/nonsleepd"
    hdiutil detach "/tmp/nonsleep_verify_$arch" 2>/dev/null
done

echo ""
echo "============================================"
echo "  BUILD COMPLETE — NonSleep v${VERSION}"
echo "============================================"
echo ""
ls -lh "$DIST"/*.dmg
echo ""
