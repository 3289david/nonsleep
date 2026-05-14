#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.0.0"
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
echo "==> Cleaning previous build..."
rm -rf "$DIST"
mkdir -p "$DIST"

# ── Build function for a single arch ──
build_arch() {
    local ARCH="$1"
    local ARCHDIR="$DIST/build-$ARCH"
    mkdir -p "$ARCHDIR"

    echo ""
    echo "==> [$ARCH] Building CLI and Daemon..."
    cd "$ROOT"
    swift build -c release --arch "$ARCH" 2>&1

    local SPM_BIN="$ROOT/.build/release"

    cp "$SPM_BIN/nonsleep" "$ARCHDIR/nonsleep"
    cp "$SPM_BIN/nonsleepd" "$ARCHDIR/nonsleepd"

    echo "==> [$ARCH] Building NonSleep.app binary..."
    swiftc \
        -O \
        -target "${ARCH}-apple-macos13.0" \
        -sdk "$SDK" \
        -framework SwiftUI \
        -framework AppKit \
        -framework ServiceManagement \
        -framework IOKit \
        -o "$ARCHDIR/NonSleep" \
        "${APP_SOURCES[@]}" 2>&1

    echo "==> [$ARCH] Build complete."
}

# ── Build both architectures ──
build_arch "arm64"

echo ""
echo "==> Cleaning SPM cache for x86_64 cross-compile..."
swift package clean 2>/dev/null || true

build_arch "x86_64"

# ── Create universal binaries via lipo ──
echo ""
echo "==> Creating universal (fat) binaries..."
UNIDIR="$DIST/build-universal"
mkdir -p "$UNIDIR"

for bin in NonSleep nonsleep nonsleepd; do
    lipo -create \
        "$DIST/build-arm64/$bin" \
        "$DIST/build-x86_64/$bin" \
        -output "$UNIDIR/$bin"
    echo "   $bin: $(file "$UNIDIR/$bin" | sed 's/.*: //')"
done

# ── Assemble app bundles and DMGs ──
assemble_app() {
    local ARCH="$1"
    local BINDIR="$DIST/build-$ARCH"
    local SUFFIX="$2"
    local APP="$DIST/NonSleep${SUFFIX}.app"
    local DMG="$DIST/NonSleep-${VERSION}${SUFFIX}.dmg"
    local DMGDIR="$DIST/dmg${SUFFIX}"

    echo ""
    echo "==> Assembling NonSleep${SUFFIX}.app..."

    mkdir -p "$APP/Contents/MacOS"
    mkdir -p "$APP/Contents/Resources"
    mkdir -p "$APP/Contents/Library/LaunchAgents"

    cp "$BINDIR/NonSleep" "$APP/Contents/MacOS/NonSleep"
    cp "$BINDIR/nonsleep" "$APP/Contents/MacOS/nonsleep-cli"
    cp "$BINDIR/nonsleepd" "$APP/Contents/MacOS/nonsleepd"
    echo "$INFOPLIST" > "$APP/Contents/Info.plist"
    cp "$ROOT/assets/NonSleep.icns" "$APP/Contents/Resources/NonSleep.icns"
    cp "$ROOT/scripts/com.nonsleep.daemon.plist" "$APP/Contents/Library/LaunchAgents/"
    echo -n "APPL????" > "$APP/Contents/PkgInfo"

    # Code sign
    codesign --force --deep --sign - "$APP" 2>&1 || true

    # Create DMG
    echo "==> Creating NonSleep-${VERSION}${SUFFIX}.dmg..."
    mkdir -p "$DMGDIR"
    cp -R "$APP" "$DMGDIR/"
    ln -sf /Applications "$DMGDIR/Applications"

    hdiutil create \
        -volname "NonSleep" \
        -srcfolder "$DMGDIR" \
        -ov \
        -format UDZO \
        -imagekey zlib-level=9 \
        "$DMG" 2>&1

    rm -rf "$DMGDIR"
    echo "   DMG: $(du -h "$DMG" | cut -f1)"
}

assemble_app "arm64" "-arm64"
assemble_app "x86_64" "-x86_64"
assemble_app "universal" "-universal"

# ── Clean up build dirs ──
rm -rf "$DIST/build-arm64" "$DIST/build-x86_64" "$DIST/build-universal"
rm -rf "$DIST"/*.app

# ── Summary ──
echo ""
echo "============================================"
echo "  BUILD COMPLETE — NonSleep v${VERSION}"
echo "============================================"
echo ""
echo "  DMGs:"
for f in "$DIST"/NonSleep-*.dmg; do
    local_name="$(basename "$f")"
    local_size="$(du -h "$f" | cut -f1)"
    echo "    $local_name  ($local_size)"
done
echo ""
echo "  Architectures:"
echo "    arm64     — Apple Silicon (M1/M2/M3/M4)"
echo "    x86_64    — Intel Mac"
echo "    universal — Both (fat binary)"
echo ""
