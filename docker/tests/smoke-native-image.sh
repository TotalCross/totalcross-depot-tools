#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

image=${1:?usage: smoke-native-image.sh IMAGE PLATFORM_ARCH}
platform_arch=${2:?usage: smoke-native-image.sh IMAGE PLATFORM_ARCH}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

docker run --rm -v "$root:/sources" -v "$tmp:/work" -w /sources "$image" bash -lc "
  cmake -S zlib -B /work/build -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build /work/build
  cmake --install /work/build --prefix /work/install
  bash zlib/scripts/package-artifact.sh /work/build /work/install '$platform_arch'
  test -f /work/build/zlib-*.tar.gz
  ! find /work/install -type f -name '*.so' | grep -q .
"
