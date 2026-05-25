#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$ROOT_DIR/manifest.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
print("skia:", manifest["skia"]["commit"])
print("depot_tools:", manifest["depot_tools"]["commit"])
print("release_tag:", manifest["release"]["tag"])
PY
