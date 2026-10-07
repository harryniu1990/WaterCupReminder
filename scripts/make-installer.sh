#!/usr/bin/env bash
#
# 生成可分发的安装包：
#   dist/WaterCupReminder-<VERSION>.dmg   —— 拖拽安装（推荐）
#   dist/WaterCupReminder-<VERSION>.zip   —— 绿色版压缩包
#
# 产物为 Universal Binary（arm64 + x86_64），Apple Silicon / Intel Mac 通用。
# 使用 ad-hoc 签名（无 Apple 开发者证书），首次打开需右键「打开」或执行：
#   xattr -dr com.apple.quarantine /Applications/WaterCupReminder.app
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="WaterCupReminder"
VERSION="1.0.0"
BUNDLE_ID="local.water-cup-reminder"
MIN_MACOS="12.0"

SRC_FILE="$ROOT_DIR/Sources/WaterCupReminder/main.swift"
BUILD_DIR="$ROOT_DIR/.build/universal"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
STAGING_DIR="$ROOT_DIR/.build/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"

cd "$ROOT_DIR"
export HOME="$ROOT_DIR/.home"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

echo "==> [1/5] 编译 Universal Binary (arm64 + x86_64)"
mkdir -p "$BUILD_DIR"
for ARCH in arm64 x86_64; do
    echo "    - $ARCH"
    swiftc \
        -target "${ARCH}-apple-macosx${MIN_MACOS}" \
        -sdk "$SDK_PATH" \
        -O -whole-module-optimization \
        -framework AppKit \
        -framework QuartzCore \
        "$SRC_FILE" \
        -o "$BUILD_DIR/$APP_NAME-$ARCH"
done
lipo -create -output "$BUILD_DIR/$APP_NAME" \
    "$BUILD_DIR/$APP_NAME-arm64" \
    "$BUILD_DIR/$APP_NAME-x86_64"
rm -f "$BUILD_DIR/$APP_NAME-arm64" "$BUILD_DIR/$APP_NAME-x86_64"
lipo -info "$BUILD_DIR/$APP_NAME"

echo "==> [2/5] 组装 .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>喝水提醒</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> [3/5] Ad-hoc 签名"
xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --sign - --identifier "$BUNDLE_ID" --timestamp=none "$APP_DIR"
codesign --verify --verbose=2 "$APP_DIR"

echo "==> [4/5] 制作 DMG 安装包"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/安装说明.txt" <<'TXT'
喝水提醒 WaterCupReminder —— 安装说明
=====================================

【安装】
1. 把左边的「WaterCupReminder」拖到右边的「Applications」文件夹。
2. 在「应用程序」里双击打开。

【首次打开被系统拦下怎么办】
由于是本地编译、未做 Apple 开发者签名，macOS 首次会提示
"无法打开，因为无法验证开发者"。任选一种方式放行：

  方式一：在「应用程序」里右键点它 → 选「打开」→ 再点「打开」。
  方式二：打开「终端」，执行：
      xattr -dr com.apple.quarantine /Applications/WaterCupReminder.app

【使用】
- 启动后菜单栏出现水滴图标，Dock 里不会显示（无窗口应用）。
- 每天 10:00 - 18:00 每小时弹一次喝水提醒，固定在屏幕左上角。
- 点「我喝啦」立即隐藏；不理会则每 30 秒继续放大，直到几乎铺满屏幕。
- 菜单栏图标菜单：手动提醒 / 隐藏提醒 / 退出。

【卸载】
在「应用程序」里把 WaterCupReminder 拖进废纸篓即可。
TXT

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

echo "==> [5/5] 制作 ZIP 绿色版"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo ""
echo "✅ 打包完成："
ls -lh "$DMG_PATH" "$ZIP_PATH" | awk '{print "   " $5 "\t" $9}'
