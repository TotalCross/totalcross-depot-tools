#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
SOURCE_DIR="${SOURCE_DIR:-$ROOT_DIR/staging}"

if [[ -z "${BUNDLE_NAME:-}" ]]; then
  BUNDLE_NAME=$(python3 - "$ROOT_DIR/manifest.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(manifest.get("release", {}).get("dev_bundle", "skia-dev.tar.gz"))
PY
)
fi

mkdir -p "$DIST_DIR"

[[ -d "$SOURCE_DIR/modules/skia/include" ]] || {
  echo "error: missing $SOURCE_DIR/modules/skia/include" >&2
  exit 1
}

[[ -d "$SOURCE_DIR/modules/skia/src/gpu/gl" ]] || {
  echo "error: missing $SOURCE_DIR/modules/skia/src/gpu/gl" >&2
  exit 1
}

tar -czf "$DIST_DIR/$BUNDLE_NAME" -C "$SOURCE_DIR" modules/skia
echo "Created dev bundle:"
echo "  $DIST_DIR/$BUNDLE_NAME"
