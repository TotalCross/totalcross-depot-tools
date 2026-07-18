#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

: "${ANDROID_HOME:?ANDROID_HOME must point to an Android SDK installation.}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

exec scripts/build-cmake-multi.sh \
  --source-dir zlib \
  --build-dir zlib/build/android-arm64-v8a \
  --install-dir zlib/build/android-arm64-v8a/install \
  --platform-arch android/arm64-v8a \
  --cmake-args "-DCMAKE_TOOLCHAIN_FILE=${ANDROID_HOME}/ndk/28.2.13676358/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-23 -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF" \
  --package-script zlib/scripts/package-artifact.sh
