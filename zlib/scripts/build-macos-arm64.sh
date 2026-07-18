#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

exec scripts/build-cmake-multi.sh \
  --source-dir zlib \
  --build-dir zlib/build/macos-arm64 \
  --install-dir zlib/build/macos-arm64/install \
  --platform-arch macos/arm64 \
  --cmake-args '-DCMAKE_OSX_ARCHITECTURES=arm64' \
  --package-script zlib/scripts/package-artifact.sh
