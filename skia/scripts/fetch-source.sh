#!/usr/bin/env bash
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
    git clone "$url" "$ROOT_DIR/$path"
  fi

  git -C "$ROOT_DIR/$path" fetch --tags "$url" "$commit"
  git -C "$ROOT_DIR/$path" checkout --detach "$commit"
}

checkout_pinned_repo skia
checkout_pinned_repo depot_tools

