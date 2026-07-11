#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenLaunch"
APP_BUNDLE="$ROOT_DIR/.build/${APP_NAME}.app"
EXECUTABLE="$ROOT_DIR/.build/release/${APP_NAME}"
APP_ICON_NAME="OpenLaunchAppIcon"
APP_VERSION="0.1.0"
BUILD_NUMBER="$(bash "$ROOT_DIR/scripts/resolve-build-number.sh" "$ROOT_DIR")"

cd "$ROOT_DIR"

swift build -c release --product "$APP_NAME"
swift scripts/generate-app-icon.swift
iconutil -c icns "Resources/${APP_ICON_NAME}.iconset" -o "Resources/${APP_ICON_NAME}.icns"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/${APP_ICON_NAME}.icns" "$APP_BUNDLE/Contents/Resources/${APP_ICON_NAME}.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>OpenLaunch</string>
    <key>CFBundleExecutable</key>
    <string>OpenLaunch</string>
    <key>CFBundleIdentifier</key>
    <string>dev.openlaunch.OpenLaunch</string>
    <key>CFBundleIconFile</key>
    <string>OpenLaunchAppIcon</string>
    <key>CFBundleIconName</key>
    <string>OpenLaunchAppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenLaunch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSQuitAlwaysKeepsWindows</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# 清理普通扩展属性，减少本机打包产物中的额外元数据。
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo "Built $APP_BUNDLE"
