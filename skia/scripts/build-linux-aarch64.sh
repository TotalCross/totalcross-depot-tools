#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/common.sh"

echo "No original linux aarch64 build script was found in the imported skia-build history." >&2
echo "Available original Linux recipes were x86_64 and armv7." >&2
exit 1
