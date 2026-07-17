#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") PLATFORM ARCH" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
PLATFORM="$1"
ARCH="$2"

fetch_required() {
  local dep="$1"
  local token_env="$2"
  local release_tag

  release_tag=$(bash "$ROOT_DIR/.github/scripts/read-deps-release.sh" "$dep")
  if [[ -z "$release_tag" ]]; then
    echo "error: could not read compatible release tag for $dep from deps.yml" >&2
    exit 1
  fi

  if bash "$ROOT_DIR/$dep/fetch.sh" \
      --platform "$PLATFORM" \
      --arch "$ARCH" \
      --release-tag "$release_tag" \
      --github-token-env "$token_env"; then
    return 0
  fi

  echo "error: no $dep prebuilt available for $PLATFORM/$ARCH at release $release_tag" >&2
  exit 1
}

fetch_required zlib-ng ZLIB_NG_GITHUB_TOKEN
fetch_required libpng LIBPNG_GITHUB_TOKEN
