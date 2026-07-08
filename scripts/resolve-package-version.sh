#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: resolve-package-version.sh <repo-root> <bundle-version>" >&2
    exit 64
fi

ROOT_DIR="$1"
BUNDLE_VERSION="$2"

release_tag=""
is_dirty=false

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # 仅把 v 开头的语义化版本 tag 作为发布版本，避免普通标记污染安装包命名。
    release_tag="$(git -C "$ROOT_DIR" tag --points-at HEAD --list 'v[0-9]*' --sort=-v:refname | head -n 1 || true)"

    if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
        is_dirty=true
    fi
fi

if [[ -n "$release_tag" ]]; then
    package_version="${release_tag#v}"

    if [[ "$is_dirty" == true ]]; then
        echo "${package_version}-dev"
    else
        echo "$package_version"
    fi
else
    echo "${BUNDLE_VERSION}-dev"
fi
