#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/resolve-package-version.sh"
BUILD_NUMBER_SCRIPT="$ROOT_DIR/scripts/resolve-build-number.sh"
BUILD_APP_SCRIPT="$ROOT_DIR/scripts/build-app.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/package-dmg.sh"
PKG_SCRIPT="$ROOT_DIR/scripts/package-pkg.sh"
ICON_SCRIPT="$ROOT_DIR/scripts/apply-package-icon.sh"
APP_ICON_GENERATOR="$ROOT_DIR/scripts/generate-app-icon.swift"
APP_ICONSET="$ROOT_DIR/Resources/OpenLaunchAppIcon.iconset"
DMG_ICON_SCRIPT="$ROOT_DIR/scripts/generate-dmg-volume-icon.sh"
DMG_ICON_SWIFT="$ROOT_DIR/scripts/generate-dmg-volume-icon.swift"
DMG_BACKGROUND_SWIFT="$ROOT_DIR/scripts/generate-dmg-background.swift"
DMG_BACKGROUND_TEST_SWIFT="$ROOT_DIR/Tests/DMGBackgroundTests.swift"
APP_ICON_TEST_SWIFT="$ROOT_DIR/Tests/AppIconTests.swift"
DMGBUILD_SETTINGS="$ROOT_DIR/scripts/dmgbuild-openlaunch.py"
DMGBUILD_LEGACY_JSON="$ROOT_DIR/scripts/dmgbuild-openlaunch.json"
PACKAGING_PYPROJECT="$ROOT_DIR/pyproject.toml"
PACKAGING_LOCK="$ROOT_DIR/uv.lock"
PACKAGE_WORKFLOW="$ROOT_DIR/.github/workflows/package.yml"

TMP_DIR="$(mktemp -d)"
NON_GIT_DIR="$(mktemp -d)"
SHALLOW_PARENT="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$NON_GIT_DIR" "$SHALLOW_PARENT"' EXIT

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

assert_image_dimensions() {
    local file="$1"
    local expected_width="$2"
    local expected_height="$3"
    local message="$4"
    local actual_width
    local actual_height

    actual_width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
    actual_height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"

    if [[ "$actual_width" != "$expected_width" || "$actual_height" != "$expected_height" ]]; then
        echo "FAIL: $message" >&2
        echo "  expected: ${expected_width}x${expected_height}" >&2
        echo "  actual:   ${actual_width}x${actual_height}" >&2
        exit 1
    fi
}

assert_contains 'resolve-package-version.sh' "$DMG_SCRIPT" "DMG packaging must use the shared package version resolver"
assert_contains 'resolve-package-version.sh' "$PKG_SCRIPT" "PKG packaging must use the shared package version resolver"
assert_file_exists "$BUILD_NUMBER_SCRIPT" "App builds must keep a shared bundle build-number resolver"
assert_contains 'is-shallow-repository' "$BUILD_NUMBER_SCRIPT" "Local build numbers must reject incomplete Git history"
assert_contains 'resolve-build-number.sh' "$BUILD_APP_SCRIPT" "App builds must derive CFBundleVersion from repository state"
assert_contains 'CFBundleVersion' "$BUILD_APP_SCRIPT" "App builds must write a bundle build number"
assert_not_contains '<string>1</string>' "$BUILD_APP_SCRIPT" "App builds must not keep a fixed bundle build number"
assert_contains 'Print :CFBundleVersion' "$PKG_SCRIPT" "PKG packaging must read the bundle build number"
assert_contains '--version "$BUILD_NUMBER"' "$PKG_SCRIPT" "PKG receipts must change with the app build number"
assert_contains 'apply-package-icon.sh' "$DMG_SCRIPT" "DMG packaging must apply the OpenLaunch icon"
assert_contains 'apply-package-icon.sh' "$PKG_SCRIPT" "PKG packaging must apply the OpenLaunch icon"
assert_contains 'OpenLaunchDiskIcon' "$DMG_SCRIPT" "DMG packaging must use the disk-shaped OpenLaunch icon"
assert_contains 'generate-dmg-volume-icon.sh' "$DMG_SCRIPT" "DMG packaging must generate the volume icon through the volume icon composer"
assert_file_exists "$DMG_BACKGROUND_SWIFT" "DMG packaging must keep a Swift background generator"
assert_file_exists "$DMG_BACKGROUND_TEST_SWIFT" "DMG packaging must keep background content checks"
assert_file_exists "$APP_ICON_TEST_SWIFT" "App icon generation must keep visual regression checks"
assert_not_contains 'lockFocus()' "$APP_ICON_GENERATOR" "App icon generation must not depend on the active screen scale"
assert_contains 'generate-dmg-background.swift' "$DMG_SCRIPT" "DMG packaging must generate its Finder background"
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
assert_contains 'background = ".build/package-assets/OpenLaunchDMGBackground.png"' "$DMGBUILD_SETTINGS" "DMG layout must use the generated background image"
assert_not_contains 'background = "#f5f7fa"' "$DMGBUILD_SETTINGS" "DMG layout must not fall back to a plain color without the drag arrow"
assert_contains 'icon_size = 112' "$DMGBUILD_SETTINGS" "DMG layout must use a large drag-install icon size"
assert_contains 'format = "UDZO"' "$DMGBUILD_SETTINGS" "DMG layout must produce a compressed read-only image"
assert_contains 'window_rect = ((180, 180), (560, 360))' "$DMGBUILD_SETTINGS" "DMG layout must keep the approved Finder window size"
assert_contains '"OpenLaunch.app": (150, 180)' "$DMGBUILD_SETTINGS" "DMG layout must keep OpenLaunch left of the arrow"
assert_contains '"Applications": (410, 180)' "$DMGBUILD_SETTINGS" "DMG layout must keep Applications right of the arrow"
assert_contains 'files = [' "$DMGBUILD_SETTINGS" "DMG layout must include files through dmgbuild native settings"
assert_contains '(".build/OpenLaunch.app", "OpenLaunch.app")' "$DMGBUILD_SETTINGS" "DMG layout must include the built OpenLaunch app"
assert_contains '"Applications": "/Applications"' "$DMGBUILD_SETTINGS" "DMG layout must include an Applications shortcut"
assert_file_exists "$PACKAGING_PYPROJECT" "DMG packaging must keep Python packaging dependencies in a uv project"
assert_file_exists "$PACKAGING_LOCK" "DMG packaging must commit uv.lock for repeatable local and CI builds"
assert_contains 'dmgbuild==1.6.7' "$PACKAGING_PYPROJECT" "DMG packaging project must pin dmgbuild"
assert_contains 'name = "dmgbuild"' "$PACKAGING_LOCK" "uv lockfile must include dmgbuild"
assert_file_exists "$PACKAGE_WORKFLOW" "GitHub Actions packaging workflow must be documented as runnable automation"
assert_contains 'fetch-depth: 0' "$PACKAGE_WORKFLOW" "packaging workflow must fetch tags for package version resolution"
assert_contains 'runs-on: macos-26' "$PACKAGE_WORKFLOW" "packaging workflow must pin the macOS runner image"
assert_not_contains 'runs-on: macos-latest' "$PACKAGE_WORKFLOW" "packaging workflow must not use a migrating macOS runner label"
assert_contains 'astral-sh/setup-uv@11f9893b081a58869d3b5fccaea48c9e9e46f990 # v8.3.2' "$PACKAGE_WORKFLOW" "packaging workflow must pin the Node 24 setup-uv action"
assert_not_contains 'astral-sh/setup-uv@v6' "$PACKAGE_WORKFLOW" "packaging workflow must not use the deprecated Node 20 setup-uv action"
assert_contains 'uv sync --locked' "$PACKAGE_WORKFLOW" "packaging workflow must verify the committed uv lockfile"
assert_contains 'scripts/package-dmg.sh' "$PACKAGE_WORKFLOW" "packaging workflow must build the DMG"
assert_contains 'scripts/package-pkg.sh' "$PACKAGE_WORKFLOW" "packaging workflow must build the PKG"
assert_contains 'OPENLAUNCH_BUILD_NUMBER: ${{ github.run_number }}' "$PACKAGE_WORKFLOW" "release packaging must use the workflow run number as a monotonic build number"
assert_contains 'actions/upload-artifact' "$PACKAGE_WORKFLOW" "packaging workflow must upload non-release build artifacts"
assert_contains 'gh release create' "$PACKAGE_WORKFLOW" "tagged packaging workflow must create GitHub releases through GitHub CLI"
assert_contains '--verify-tag' "$PACKAGE_WORKFLOW" "GitHub release publishing must verify the pushed tag"
assert_contains '--generate-notes' "$PACKAGE_WORKFLOW" "GitHub release publishing must generate release notes"
assert_not_contains 'softprops/action-gh-release' "$PACKAGE_WORKFLOW" "immutable releases must not publish before uploading assets"
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

BACKGROUND_TMP_DIR="$TMP_DIR/dmg-background"
mkdir -p "$BACKGROUND_TMP_DIR"
touch "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground@3x.png"
swift "$DMG_BACKGROUND_SWIFT" "$BACKGROUND_TMP_DIR"
assert_file_exists "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground.png" "DMG background generator must create the 1x image"
assert_file_exists "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground@2x.png" "DMG background generator must create the 2x image"
assert_file_not_exists "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground@3x.png" "DMG background generator must remove stale scale variants"
assert_image_dimensions "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground.png" 560 360 "DMG 1x background must match the Finder window"
assert_image_dimensions "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground@2x.png" 1120 720 "DMG 2x background must match the Retina Finder window"
swift "$DMG_BACKGROUND_TEST_SWIFT" "$BACKGROUND_TMP_DIR"
rm -rf "$BACKGROUND_TMP_DIR"

swift "$APP_ICON_TEST_SWIFT" "$ROOT_DIR/Resources/OpenLaunchAppIcon.iconset/icon_512x512@2x.png"
assert_image_dimensions "$APP_ICONSET/icon_16x16.png" 16 16 "App icon 16pt 1x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_16x16@2x.png" 32 32 "App icon 16pt 2x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_32x32.png" 32 32 "App icon 32pt 1x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_32x32@2x.png" 64 64 "App icon 32pt 2x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_128x128.png" 128 128 "App icon 128pt 1x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_128x128@2x.png" 256 256 "App icon 128pt 2x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_256x256.png" 256 256 "App icon 256pt 1x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_256x256@2x.png" 512 512 "App icon 256pt 2x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_512x512.png" 512 512 "App icon 512pt 1x resource must use exact pixels"
assert_image_dimensions "$APP_ICONSET/icon_512x512@2x.png" 1024 1024 "App icon 512pt 2x resource must use exact pixels"

git -C "$TMP_DIR" init -q
git -C "$TMP_DIR" config user.email "openlaunch-tests@example.com"
git -C "$TMP_DIR" config user.name "OpenLaunch Tests"
printf 'initial\n' > "$TMP_DIR/fixture.txt"
git -C "$TMP_DIR" add fixture.txt
git -C "$TMP_DIR" commit -qm "initial"

actual="$(bash "$BUILD_NUMBER_SCRIPT" "$TMP_DIR")"
assert_equal "1" "$actual" "the first repository commit uses bundle build number 1"

printf 'second\n' >> "$TMP_DIR/fixture.txt"
git -C "$TMP_DIR" add fixture.txt
git -C "$TMP_DIR" commit -qm "second"
actual="$(bash "$BUILD_NUMBER_SCRIPT" "$TMP_DIR")"
assert_equal "2" "$actual" "bundle build numbers follow the repository commit count"

actual="$(OPENLAUNCH_BUILD_NUMBER=42 bash "$BUILD_NUMBER_SCRIPT" "$TMP_DIR")"
assert_equal "42" "$actual" "release automation can override the bundle build number"

if OPENLAUNCH_BUILD_NUMBER=invalid bash "$BUILD_NUMBER_SCRIPT" "$TMP_DIR" >/dev/null 2>&1; then
    echo "FAIL: invalid bundle build-number overrides must be rejected" >&2
    exit 1
fi

if bash "$BUILD_NUMBER_SCRIPT" "$NON_GIT_DIR" >/dev/null 2>&1; then
    echo "FAIL: local bundle build numbers must reject missing Git metadata" >&2
    exit 1
fi

git clone -q --depth 1 "file://$TMP_DIR" "$SHALLOW_PARENT/repository"
if bash "$BUILD_NUMBER_SCRIPT" "$SHALLOW_PARENT/repository" >/dev/null 2>&1; then
    echo "FAIL: local bundle build numbers must reject shallow Git history" >&2
    exit 1
fi

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
