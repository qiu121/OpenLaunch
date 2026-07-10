#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenLaunch"
APP_BUNDLE="$ROOT_DIR/.build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/.build/dist"
STAGING_DIR="$ROOT_DIR/.build/dmg-staging"
MOUNT_DIR="$ROOT_DIR/.build/dmg-mount"
DMG_ICON_DIR="$ROOT_DIR/.build/package-icons"
DMG_ICON="$DMG_ICON_DIR/OpenLaunchDiskIcon.icns"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"
bash "$ROOT_DIR/scripts/generate-dmg-volume-icon.sh" "$DMG_ICON_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
PACKAGE_VERSION="$(bash "$ROOT_DIR/scripts/resolve-package-version.sh" "$ROOT_DIR" "$VERSION")"
DMG_PATH="$DIST_DIR/${APP_NAME}-${PACKAGE_VERSION}.dmg"
RW_DMG_PATH="$DIST_DIR/${APP_NAME}-${PACKAGE_VERSION}.rw.dmg"

cleanup() {
    if [[ -d "$MOUNT_DIR" ]] && hdiutil info | grep -Fq "$MOUNT_DIR"; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi

    rm -rf "$STAGING_DIR" "$MOUNT_DIR"
    rm -f "$RW_DMG_PATH"
}

trap cleanup EXIT

rm -rf "$STAGING_DIR" "$MOUNT_DIR"
rm -f "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$DIST_DIR" "$STAGING_DIR" "$MOUNT_DIR"

# 使用 ditto 复制 .app，保留 bundle 结构和资源属性。
ditto "$APP_BUNDLE" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$RW_DMG_PATH"

hdiutil attach "$RW_DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
bash "$ROOT_DIR/scripts/apply-package-icon.sh" "$MOUNT_DIR" "$DMG_ICON"
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$RW_DMG_PATH" \
    -ov \
    -format UDZO \
    -o "$DMG_PATH"

bash "$ROOT_DIR/scripts/apply-package-icon.sh" "$DMG_PATH" "$DMG_ICON"

echo "Packaged $DMG_PATH"
