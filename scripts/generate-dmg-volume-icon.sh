#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/.build/package-icons}"
DISK_ICON="$OUTPUT_DIR/OpenLaunchDiskIcon.icns"

mkdir -p "$OUTPUT_DIR"
swift "$ROOT_DIR/scripts/generate-dmg-volume-icon.swift" "$OUTPUT_DIR"
rm -f "$DISK_ICON"
iconutil -c icns "$OUTPUT_DIR/OpenLaunchDiskIcon.iconset" -o "$DISK_ICON"

echo "Generated $DISK_ICON"
