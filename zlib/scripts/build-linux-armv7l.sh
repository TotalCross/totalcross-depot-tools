#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

exec scripts/build-cmake-multi.sh \
  --source-dir zlib \
  --build-dir zlib/build/linux-arm32v7 \
  --install-dir zlib/build/linux-arm32v7/install \
  --platform-arch linux/armv7l \
  --docker-image totalcross/linux-arm32v7:v2.0.1 \
  --docker-platform linux/arm/v7 \
  --package-script zlib/scripts/package-artifact.sh
