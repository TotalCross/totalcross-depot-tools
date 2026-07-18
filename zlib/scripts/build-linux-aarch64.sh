#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

exec scripts/build-cmake-multi.sh \
  --source-dir zlib \
  --build-dir zlib/build/linux-arm64 \
  --install-dir zlib/build/linux-arm64/install \
  --platform-arch linux/aarch64 \
  --docker-image totalcross/linux-arm64:v2.0.1 \
  --docker-platform linux/arm64 \
  --package-script zlib/scripts/package-artifact.sh
