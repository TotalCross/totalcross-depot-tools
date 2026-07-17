#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
# Experimental, isolated ARMv7 cross-build. The production workflow keeps QEMU.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export CC=${CC:-arm-linux-gnueabihf-gcc}
export CXX=${CXX:-arm-linux-gnueabihf-g++}
export AR=${AR:-arm-linux-gnueabihf-ar}
export RANLIB=${RANLIB:-arm-linux-gnueabihf-ranlib}
export SKIA_ARMV7_CROSS_EXPERIMENT=1
export SKIA_OUT_DIR=${SKIA_OUT_DIR:-"$ROOT_DIR/out/linux-armv7-cross"}

for command in "$CC" "$CXX" "$AR" "$RANLIB"; do
  command -v "$command" >/dev/null || { echo "missing ARMv7 cross tool: $command" >&2; exit 1; }
done

exec "$ROOT_DIR/scripts/build-linux-armv7l.sh"
