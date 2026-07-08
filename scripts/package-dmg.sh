#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenLaunch"
APP_BUNDLE="$ROOT_DIR/.build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/.build/dist"
STAGING_DIR="$ROOT_DIR/.build/dmg-staging"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
PACKAGE_VERSION="$(bash "$ROOT_DIR/scripts/resolve-package-version.sh" "$ROOT_DIR" "$VERSION")"
DMG_PATH="$DIST_DIR/${APP_NAME}-${PACKAGE_VERSION}.dmg"

rm -rf "$STAGING_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

# 使用 ditto 复制 .app，保留 bundle 结构和资源属性。
ditto "$APP_BUNDLE" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "Packaged $DMG_PATH"
