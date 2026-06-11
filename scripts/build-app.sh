#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="WaterCupReminder"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
export HOME="$ROOT_DIR/.home"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$BUILD_DIR"
swiftc \
    -target arm64-apple-macosx12.0 \
    -sdk "$SDK_PATH" \
    -framework AppKit \
    -framework QuartzCore \
    "$ROOT_DIR/Sources/WaterCupReminder/main.swift" \
    -o "$BUILD_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WaterCupReminder</string>
    <key>CFBundleIdentifier</key>
    <string>local.water-cup-reminder</string>
    <key>CFBundleName</key>
    <string>WaterCupReminder</string>
    <key>CFBundleDisplayName</key>
    <string>喝水提醒</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built: $APP_DIR"
