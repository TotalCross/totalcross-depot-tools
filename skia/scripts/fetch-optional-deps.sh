#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") PLATFORM ARCH" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
PLATFORM="$1"
ARCH="$2"

read_release() {
  local manifest="$1"
  awk '/^release:[[:space:]]*/ { print $2; exit }' "$manifest"
}

fetch_optional() {
  local dep="$1"
  local token_env="$2"
  local release_tag

  release_tag=$(read_release "$ROOT_DIR/$dep/manifest.yml")
  if [[ -z "$release_tag" ]]; then
    echo "warning: could not read release tag for $dep; skipping optional Skia prebuilt dependency" >&2
    return 0
  fi

  if bash "$ROOT_DIR/$dep/fetch.sh" \
      --platform "$PLATFORM" \
      --arch "$ARCH" \
      --release-tag "$release_tag" \
      --github-token-env "$token_env"; then
    return 0
  fi

  echo "warning: no $dep prebuilt available for $PLATFORM/$ARCH; Skia will use its internal dependency for this target" >&2
}

fetch_optional zlib-ng ZLIB_NG_GITHUB_TOKEN
fetch_optional libpng LIBPNG_GITHUB_TOKEN
