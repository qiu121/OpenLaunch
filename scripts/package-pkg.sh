#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenLaunch"
APP_BUNDLE="$ROOT_DIR/.build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/.build/dist"
APP_ICON="$ROOT_DIR/Resources/OpenLaunchAppIcon.icns"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
PACKAGE_VERSION="$(bash "$ROOT_DIR/scripts/resolve-package-version.sh" "$ROOT_DIR" "$VERSION")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
PKG_PATH="$DIST_DIR/${APP_NAME}-${PACKAGE_VERSION}.pkg"

mkdir -p "$DIST_DIR"
rm -f "$PKG_PATH"

# 本地开发安装包：安装到 /Applications；对外发布前还需要 Developer ID 签名和公证。
COPYFILE_DISABLE=1 pkgbuild \
    --component "$APP_BUNDLE" \
    --install-location /Applications \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    "$PKG_PATH"

bash "$ROOT_DIR/scripts/apply-package-icon.sh" "$PKG_PATH" "$APP_ICON"

echo "Packaged $PKG_PATH"
