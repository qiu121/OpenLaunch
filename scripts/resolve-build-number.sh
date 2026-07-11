#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: resolve-build-number.sh <repo-root>" >&2
    exit 64
fi

ROOT_DIR="$1"

if [[ -n "${OPENLAUNCH_BUILD_NUMBER:-}" ]]; then
    if [[ ! "$OPENLAUNCH_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
        echo "OPENLAUNCH_BUILD_NUMBER must be a positive integer." >&2
        exit 64
    fi

    echo "$OPENLAUNCH_BUILD_NUMBER"
    exit 0
fi

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Cannot resolve a local build number without Git metadata." >&2
    echo "Set OPENLAUNCH_BUILD_NUMBER to a positive integer for archive builds." >&2
    exit 1
fi

if [[ "$(git -C "$ROOT_DIR" rev-parse --is-shallow-repository)" == "true" ]]; then
    echo "Cannot resolve a local build number from shallow Git history." >&2
    echo "Fetch the complete history or set OPENLAUNCH_BUILD_NUMBER." >&2
    exit 1
fi

if ! commit_count="$(git -C "$ROOT_DIR" rev-list --count HEAD)" || [[ ! "$commit_count" =~ ^[1-9][0-9]*$ ]]; then
    echo "Cannot resolve a positive build number from Git history." >&2
    exit 1
fi

echo "$commit_count"
