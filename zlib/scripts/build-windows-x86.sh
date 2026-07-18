#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

exec scripts/build-cmake-multi.sh \
  --source-dir zlib \
  --build-dir zlib/build/windows-x86 \
  --install-dir zlib/build/windows-x86/install \
  --platform-arch windows/x86 \
  --generator 'Visual Studio 17 2022' \
  --cmake-args '-A Win32 -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded' \
  --package-script zlib/scripts/package-artifact.sh
