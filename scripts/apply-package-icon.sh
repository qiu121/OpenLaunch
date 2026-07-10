#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
    echo "Usage: apply-package-icon.sh <target-file-or-volume-folder> <icon.icns>" >&2
    exit 64
fi

TARGET_PATH="$1"
ICON_PATH="$2"

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 69
    fi
}

if [[ ! -e "$TARGET_PATH" ]]; then
    echo "Target does not exist: $TARGET_PATH" >&2
    exit 66
fi

if [[ ! -f "$ICON_PATH" ]]; then
    echo "Icon file does not exist: $ICON_PATH" >&2
    exit 66
fi

require_command sips
require_command DeRez
require_command Rez
require_command SetFile

if [[ -d "$TARGET_PATH" ]]; then
    cp "$ICON_PATH" "$TARGET_PATH/.VolumeIcon.icns"
    SetFile -a C "$TARGET_PATH"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TMP_ICON="$TMP_DIR/package-icon.icns"
TMP_RESOURCE="$TMP_DIR/package-icon.rsrc"

cp "$ICON_PATH" "$TMP_ICON"
sips -i "$TMP_ICON" >/dev/null
DeRez -only icns "$TMP_ICON" > "$TMP_RESOURCE"
Rez -append "$TMP_RESOURCE" -o "$TARGET_PATH"
SetFile -a C "$TARGET_PATH"
