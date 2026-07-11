#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenLaunch"
APP_BUNDLE="$ROOT_DIR/.build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/.build/dist"
DMG_ICON_DIR="$ROOT_DIR/.build/package-icons"
DMG_ICON="$DMG_ICON_DIR/OpenLaunchDiskIcon.icns"
DMGBUILD_SETTINGS="$ROOT_DIR/scripts/dmgbuild-openlaunch.py"

ensure_dmgbuild() {
    if [[ -n "${DMGBUILD_BIN:-}" ]]; then
        if [[ ! -x "$DMGBUILD_BIN" ]]; then
            echo "DMGBUILD_BIN must point to an executable dmgbuild binary." >&2
            exit 1
        fi
        return
    fi

    if ! command -v uv >/dev/null 2>&1; then
        echo "uv is required to package DMG with dmgbuild." >&2
        echo "Install uv from https://docs.astral.sh/uv/ and rerun scripts/package-dmg.sh." >&2
        exit 1
    fi
}

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"
bash "$ROOT_DIR/scripts/generate-dmg-volume-icon.sh" "$DMG_ICON_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
PACKAGE_VERSION="$(bash "$ROOT_DIR/scripts/resolve-package-version.sh" "$ROOT_DIR" "$VERSION")"
DMG_PATH="$DIST_DIR/${APP_NAME}-${PACKAGE_VERSION}.dmg"

rm -f "$DMG_PATH"
mkdir -p "$DIST_DIR"

# 使用 dmgbuild 生成可复现的 Finder 安装窗口布局，避免依赖 Finder 或 AppleScript。
ensure_dmgbuild

if [[ -n "${DMGBUILD_BIN:-}" ]]; then
    "$DMGBUILD_BIN" \
        --detach-retries 12 \
        -s "$DMGBUILD_SETTINGS" \
        "$APP_NAME" \
        "$DMG_PATH"
else
    uv run \
        --locked \
        dmgbuild \
        --detach-retries 12 \
        -s "$DMGBUILD_SETTINGS" \
        "$APP_NAME" \
        "$DMG_PATH"
fi

bash "$ROOT_DIR/scripts/apply-package-icon.sh" "$DMG_PATH" "$DMG_ICON"

echo "Packaged $DMG_PATH"
