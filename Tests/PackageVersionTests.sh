#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/resolve-package-version.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/package-dmg.sh"
PKG_SCRIPT="$ROOT_DIR/scripts/package-pkg.sh"

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

    if ! grep -Fq "$expected" "$file"; then
        echo "FAIL: $message" >&2
        echo "  expected to find: $expected" >&2
        echo "  file:             $file" >&2
        exit 1
    fi
}

assert_contains 'resolve-package-version.sh' "$DMG_SCRIPT" "DMG packaging must use the shared package version resolver"
assert_contains 'resolve-package-version.sh' "$PKG_SCRIPT" "PKG packaging must use the shared package version resolver"

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
