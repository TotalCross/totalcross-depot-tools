#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST_PATH="${MANIFEST_PATH:-$ROOT_DIR/manifest.json}"

read_manifest_field() {
  python3 - "$MANIFEST_PATH" "$1" "$2" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
section = manifest[sys.argv[2]]
field = sys.argv[3]
print(section[field])
PY
}

checkout_pinned_repo() {
  local name="$1"
  local path
  local url
  local commit

  path=$(read_manifest_field "$name" submodule_path)
  url=$(read_manifest_field "$name" upstream_url)
  commit=$(read_manifest_field "$name" commit)

  if [[ ! -d "$ROOT_DIR/$path/.git" ]]; then
    rm -rf "$ROOT_DIR/$path"
    mkdir -p "$ROOT_DIR/$path"
    git -C "$ROOT_DIR/$path" init -q
    git -C "$ROOT_DIR/$path" remote add origin "$url"
  else
    git -C "$ROOT_DIR/$path" remote set-url origin "$url"
  fi

  if [[ "$(git -C "$ROOT_DIR/$path" rev-parse HEAD 2>/dev/null || true)" == "$commit" ]]; then
    return
  fi

  if ! git -C "$ROOT_DIR/$path" fetch --no-tags --filter=blob:none --depth=1 origin "$commit"; then
    echo "warning: filtered fetch failed for $name; retrying shallow fetch without blob filter" >&2
    git -C "$ROOT_DIR/$path" fetch --no-tags --depth=1 origin "$commit"
  fi
  git -C "$ROOT_DIR/$path" checkout --detach -q FETCH_HEAD
}

if [[ $# -eq 0 ]]; then
  set -- skia depot_tools
fi

for repo_name in "$@"; do
  checkout_pinned_repo "$repo_name"
done
