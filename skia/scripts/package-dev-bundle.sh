#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
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
print(manifest.get("release", {}).get("dev_bundle", "skia-dev-headers.zip"))
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

python3 - "$SOURCE_DIR" "$DIST_DIR/$BUNDLE_NAME" <<'PY'
import pathlib
import sys
import zipfile

source_dir = pathlib.Path(sys.argv[1])
bundle_path = pathlib.Path(sys.argv[2])
root = source_dir / "modules" / "skia"
included_roots = [
    root / "include",
    root / "src" / "gpu" / "gl",
]

if bundle_path.exists():
    bundle_path.unlink()

with zipfile.ZipFile(bundle_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for included_root in included_roots:
        for path in sorted(included_root.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(source_dir))
PY

echo "Created dev headers bundle:"
echo "  $DIST_DIR/$BUNDLE_NAME"
