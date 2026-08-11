#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKIA_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPOSITORY_ROOT=$(cd "$SKIA_ROOT/.." && pwd)
ASSETS_DIR=${1:-"$REPOSITORY_ROOT/release-assets"}

[[ -d "$ASSETS_DIR" ]] || {
  echo "missing Skia release assets directory: $ASSETS_DIR" >&2
  exit 1
}

diagnostics_archive=$(python3 - "$SKIA_ROOT/manifest.yml" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as manifest:
    for line in manifest:
        match = re.match(r"^  diagnostics:\s*(\S.*?)\s*$", line)
        if match:
            print(match.group(1))
            break
    else:
        raise SystemExit("Skia manifest has no diagnostics release asset")
PY
)

! find "$ASSETS_DIR" -maxdepth 1 -name '*.so' -print -quit | grep -q .

diagnostics_staging=$(mktemp -d "$ASSETS_DIR/.diagnostics.XXXXXX")
cleanup() {
  rm -rf "$diagnostics_staging"
}
trap cleanup EXIT

if [[ -d "$ASSETS_DIR/diagnostics" ]]; then
  find "$ASSETS_DIR/diagnostics" -mindepth 1 -maxdepth 1 -exec mv {} "$diagnostics_staging/" \;
  rmdir "$ASSETS_DIR/diagnostics"
fi

while IFS= read -r -d '' diagnostics_dir; do
  mv "$diagnostics_dir" "$diagnostics_staging/"
done < <(find "$ASSETS_DIR" -mindepth 1 -maxdepth 1 -type d ! -path "$diagnostics_staging" -print0)

python3 - "$SKIA_ROOT/artifacts.json" "$diagnostics_staging" <<'PY'
import json
import pathlib
import sys

with open(sys.argv[1], encoding="utf-8") as manifest:
    expected = set(json.load(manifest)["metadata"]["machine-build-configs"])
actual = {path.parent.name for path in pathlib.Path(sys.argv[2]).rglob("build-summary.json")}
if actual != expected:
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    raise SystemExit(f"Skia summary diagnostics mismatch: missing={missing}, unexpected={unexpected}")
PY

tar -C "$diagnostics_staging" -czf "$ASSETS_DIR/$diagnostics_archive" .
test -f "$ASSETS_DIR/$diagnostics_archive"

find "$ASSETS_DIR" -maxdepth 1 -type f ! -name SHA256SUMS -print0 |
  xargs -0 shasum -a 256 |
  sed 's#  .*/#  #' |
  sort -k 2 > "$ASSETS_DIR/SHA256SUMS"
