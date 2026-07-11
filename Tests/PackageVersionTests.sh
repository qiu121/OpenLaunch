#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/resolve-package-version.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/package-dmg.sh"
PKG_SCRIPT="$ROOT_DIR/scripts/package-pkg.sh"
ICON_SCRIPT="$ROOT_DIR/scripts/apply-package-icon.sh"
DMG_ICON_SCRIPT="$ROOT_DIR/scripts/generate-dmg-volume-icon.sh"
DMG_ICON_SWIFT="$ROOT_DIR/scripts/generate-dmg-volume-icon.swift"
DMGBUILD_SETTINGS="$ROOT_DIR/scripts/dmgbuild-openlaunch.py"
DMGBUILD_LEGACY_JSON="$ROOT_DIR/scripts/dmgbuild-openlaunch.json"
PACKAGING_PYPROJECT="$ROOT_DIR/pyproject.toml"
PACKAGING_LOCK="$ROOT_DIR/uv.lock"
PACKAGE_WORKFLOW="$ROOT_DIR/.github/workflows/package.yml"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: $message" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
}

assert_contains() {
    local expected="$1"
    local file="$2"
    local message="$3"

    if ! grep -Fq -- "$expected" "$file"; then
        echo "FAIL: $message" >&2
        echo "  expected to find: $expected" >&2
        echo "  file:             $file" >&2
        exit 1
    fi
}

assert_not_contains() {
    local unexpected="$1"
    local file="$2"
    local message="$3"

    if grep -Fq -- "$unexpected" "$file"; then
        echo "FAIL: $message" >&2
        echo "  unexpected text: $unexpected" >&2
        echo "  file:            $file" >&2
        exit 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    if [[ ! -f "$file" ]]; then
        echo "FAIL: $message" >&2
        echo "  expected file: $file" >&2
        exit 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="$2"

    if [[ -e "$file" ]]; then
        echo "FAIL: $message" >&2
        echo "  unexpected file: $file" >&2
        exit 1
    fi
}

assert_has_custom_icon_attribute() {
    local path="$1"
    local message="$2"

    if ! GetFileInfo -a "$path" | grep -Fq "C"; then
        echo "FAIL: $message" >&2
        echo "  expected custom icon attribute on: $path" >&2
        exit 1
    fi
}

assert_contains 'resolve-package-version.sh' "$DMG_SCRIPT" "DMG packaging must use the shared package version resolver"
assert_contains 'resolve-package-version.sh' "$PKG_SCRIPT" "PKG packaging must use the shared package version resolver"
assert_contains 'apply-package-icon.sh' "$DMG_SCRIPT" "DMG packaging must apply the OpenLaunch icon"
assert_contains 'apply-package-icon.sh' "$PKG_SCRIPT" "PKG packaging must apply the OpenLaunch icon"
assert_contains 'OpenLaunchDiskIcon' "$DMG_SCRIPT" "DMG packaging must use the disk-shaped OpenLaunch icon"
assert_contains 'generate-dmg-volume-icon.sh' "$DMG_SCRIPT" "DMG packaging must generate the volume icon through the volume icon composer"
assert_contains 'uv run' "$DMG_SCRIPT" "DMG packaging must use uv to run the pinned Python packaging tools"
assert_contains '--locked' "$DMG_SCRIPT" "DMG packaging must use the committed uv lockfile"
assert_not_contains 'python -c' "$DMG_SCRIPT" "DMG packaging must not use inline Python probes"
assert_not_contains 'dmgbuild.__version__' "$DMG_SCRIPT" "DMG packaging must let uv.lock enforce the dmgbuild version"
assert_not_contains 'tools/packaging' "$DMG_SCRIPT" "DMG packaging must use the root uv project instead of a nested packaging project"
assert_not_contains 'python3 -m venv' "$DMG_SCRIPT" "DMG packaging must not hand-roll a Python virtual environment"
assert_not_contains 'pip install' "$DMG_SCRIPT" "DMG packaging must not install Python tools through raw pip"
assert_contains 'dmgbuild-openlaunch.py' "$DMG_SCRIPT" "DMG packaging must use dmgbuild native settings"
assert_not_contains 'dmgbuild-openlaunch.json' "$DMG_SCRIPT" "DMG packaging must not use the legacy appdmg JSON settings"
assert_contains '--detach-retries 12' "$DMG_SCRIPT" "DMG packaging must retry image detach during CI-friendly builds"
assert_not_contains 'generate-dmg-icon.swift' "$DMG_SCRIPT" "DMG packaging must not use the hand-drawn disk icon generator"
assert_contains 'generate-dmg-volume-icon.swift' "$DMG_ICON_SCRIPT" "DMG volume icon generation must use the Swift volume icon composer"
assert_not_contains 'dmgbuild[badge_icons]' "$DMG_ICON_SCRIPT" "DMG volume icon generation must not depend on badge composition with a built-in arrow"
assert_contains 'Removable.icns' "$DMG_ICON_SWIFT" "DMG volume icon must reuse the system removable disk shell"
assert_contains 'drawTintedDiskFace' "$DMG_ICON_SWIFT" "DMG volume icon must tint the whole disk face instead of adding a sticker-like backing plate"
assert_contains 'drawOpenLaunchMark' "$DMG_ICON_SWIFT" "DMG volume icon must draw the OpenLaunch mark on the disk face"
assert_contains 'let markCenterY: CGFloat = 559' "$DMG_ICON_SWIFT" "DMG volume icon mark must sit vertically centered on the tinted disk face"
assert_not_contains 'drawBadgeBackingPlate' "$DMG_ICON_SWIFT" "DMG volume icon must not add a panel-like backing plate"
assert_not_contains 'drawSolidMosaicBadge' "$DMG_ICON_SWIFT" "DMG volume icon must not use the rejected mosaic sticker mark"
assert_not_contains 'drawSystemStyleDiskShell' "$DMG_ICON_SWIFT" "DMG volume icon must not hand-draw the system disk shell"
assert_not_contains 'drawAppIconBadge' "$DMG_ICON_SWIFT" "DMG volume icon must not paste the full app icon as a small badge"
assert_file_not_exists "$DMGBUILD_LEGACY_JSON" "legacy appdmg JSON settings must be removed after switching to dmgbuild native settings"
assert_file_exists "$DMGBUILD_SETTINGS" "DMG packaging must keep its Finder layout in a committed config file"
assert_contains 'icon = ".build/package-icons/OpenLaunchDiskIcon.icns"' "$DMGBUILD_SETTINGS" "DMG layout must use the generated disk-shaped volume icon"
assert_contains 'background = "#f5f7fa"' "$DMGBUILD_SETTINGS" "DMG layout must use a quiet system-like background"
assert_contains 'icon_size = 112' "$DMGBUILD_SETTINGS" "DMG layout must use a large drag-install icon size"
assert_contains 'format = "UDZO"' "$DMGBUILD_SETTINGS" "DMG layout must produce a compressed read-only image"
assert_contains 'files = [' "$DMGBUILD_SETTINGS" "DMG layout must include files through dmgbuild native settings"
assert_contains '(".build/OpenLaunch.app", "OpenLaunch.app")' "$DMGBUILD_SETTINGS" "DMG layout must include the built OpenLaunch app"
assert_contains '"Applications": "/Applications"' "$DMGBUILD_SETTINGS" "DMG layout must include an Applications shortcut"
assert_file_exists "$PACKAGING_PYPROJECT" "DMG packaging must keep Python packaging dependencies in a uv project"
assert_file_exists "$PACKAGING_LOCK" "DMG packaging must commit uv.lock for repeatable local and CI builds"
assert_contains 'dmgbuild==1.6.7' "$PACKAGING_PYPROJECT" "DMG packaging project must pin dmgbuild"
assert_contains 'name = "dmgbuild"' "$PACKAGING_LOCK" "uv lockfile must include dmgbuild"
assert_file_exists "$PACKAGE_WORKFLOW" "GitHub Actions packaging workflow must be documented as runnable automation"
assert_contains 'fetch-depth: 0' "$PACKAGE_WORKFLOW" "packaging workflow must fetch tags for package version resolution"
assert_contains 'astral-sh/setup-uv' "$PACKAGE_WORKFLOW" "packaging workflow must install uv"
assert_contains 'uv sync --locked' "$PACKAGE_WORKFLOW" "packaging workflow must verify the committed uv lockfile"
assert_contains 'scripts/package-dmg.sh' "$PACKAGE_WORKFLOW" "packaging workflow must build the DMG"
assert_contains 'scripts/package-pkg.sh' "$PACKAGE_WORKFLOW" "packaging workflow must build the PKG"
assert_contains 'actions/upload-artifact' "$PACKAGE_WORKFLOW" "packaging workflow must upload non-release build artifacts"
assert_contains 'softprops/action-gh-release' "$PACKAGE_WORKFLOW" "tagged packaging workflow must create GitHub releases"
assert_contains 'tags:' "$PACKAGE_WORKFLOW" "packaging workflow must run for tags"
assert_contains 'v*' "$PACKAGE_WORKFLOW" "packaging workflow must use v-prefixed release tags"
assert_contains 'schedule:' "$PACKAGE_WORKFLOW" "packaging workflow must include scheduled health builds"
assert_contains 'github.ref_type == '\''tag'\''' "$PACKAGE_WORKFLOW" "packaging workflow must publish releases only for tags"
assert_contains 'DeRez' "$ICON_SCRIPT" "package icon helper must support Finder file icons"
assert_contains 'SetFile' "$ICON_SCRIPT" "package icon helper must mark custom icons"

ICON_FIXTURE="$ROOT_DIR/Resources/OpenLaunchAppIcon.icns"
ICON_TMP_DIR="$TMP_DIR/icon-helper"
ICON_TEST_FILE="$ICON_TMP_DIR/OpenLaunch.pkg"
ICON_TEST_VOLUME="$ICON_TMP_DIR/OpenLaunchVolume"
mkdir -p "$ICON_TMP_DIR"
printf 'pkg-placeholder' > "$ICON_TEST_FILE"
mkdir -p "$ICON_TEST_VOLUME"
bash "$ICON_SCRIPT" "$ICON_TEST_FILE" "$ICON_FIXTURE"
bash "$ICON_SCRIPT" "$ICON_TEST_VOLUME" "$ICON_FIXTURE"
assert_file_exists "$ICON_TEST_VOLUME/.VolumeIcon.icns" "volume icon file must be copied into the DMG staging folder"
assert_has_custom_icon_attribute "$ICON_TEST_FILE" "PKG file must receive a Finder custom icon"
assert_has_custom_icon_attribute "$ICON_TEST_VOLUME" "DMG staging folder must receive a Finder custom icon"
rm -rf "$ICON_TMP_DIR"

git -C "$TMP_DIR" init -q
git -C "$TMP_DIR" config user.email "openlaunch-tests@example.com"
git -C "$TMP_DIR" config user.name "OpenLaunch Tests"
printf 'initial\n' > "$TMP_DIR/fixture.txt"
git -C "$TMP_DIR" add fixture.txt
git -C "$TMP_DIR" commit -qm "initial"

actual="$(bash "$SCRIPT" "$TMP_DIR" "0.1.0")"
assert_equal "0.1.0-dev" "$actual" "untagged builds use the app version with a dev suffix"

git -C "$TMP_DIR" tag "not-a-release"
actual="$(bash "$SCRIPT" "$TMP_DIR" "0.1.0")"
assert_equal "0.1.0-dev" "$actual" "non-version tags are ignored"

git -C "$TMP_DIR" tag "v0.1.0-alpha.1"
actual="$(bash "$SCRIPT" "$TMP_DIR" "0.1.0")"
assert_equal "0.1.0-alpha.1" "$actual" "clean release tags become package versions"

git -C "$TMP_DIR" tag "v0.1.0-alpha.2"
actual="$(bash "$SCRIPT" "$TMP_DIR" "0.1.0")"
assert_equal "0.1.0-alpha.2" "$actual" "the newest version tag on the same commit wins"

printf 'dirty\n' >> "$TMP_DIR/fixture.txt"
actual="$(bash "$SCRIPT" "$TMP_DIR" "0.1.0")"
assert_equal "0.1.0-alpha.2-dev" "$actual" "dirty tagged builds are marked as dev builds"

echo "Package version tests passed"
