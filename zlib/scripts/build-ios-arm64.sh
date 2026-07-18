#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

exec scripts/build-cmake-multi.sh \
  --source-dir zlib \
  --build-dir zlib/build/ios-arm64 \
  --install-dir zlib/build/ios-arm64/install \
  --platform-arch ios/arm64 \
  --generator Xcode \
  --cmake-args '-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO' \
  --package-script zlib/scripts/package-artifact.sh
