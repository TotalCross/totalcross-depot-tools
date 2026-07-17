#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
STAGING_DIR="${STAGING_DIR:-$ROOT_DIR/staging}"
DEVICE_LIB="$DIST_DIR/libskia-ios-arm64.a"
SIMULATOR_LIB="$DIST_DIR/libskia-ios-simulator-arm64.a"
HEADERS_DIR="$STAGING_DIR/modules/skia/include"
XCFRAMEWORK_DIR="$DIST_DIR/skia-ios.xcframework"
XCFRAMEWORK_ZIP="$DIST_DIR/skia-ios.xcframework.zip"

command -v xcodebuild >/dev/null 2>&1 || {
  echo "error: missing required command: xcodebuild" >&2
  exit 1
}

[[ -f "$DEVICE_LIB" ]] || {
  echo "error: missing iOS device library at $DEVICE_LIB" >&2
  exit 1
}

[[ -f "$SIMULATOR_LIB" ]] || {
  echo "error: missing iOS simulator library at $SIMULATOR_LIB" >&2
  exit 1
}

[[ -d "$HEADERS_DIR" ]] || {
  echo "error: missing Skia headers at $HEADERS_DIR" >&2
  exit 1
}

rm -rf "$XCFRAMEWORK_DIR" "$XCFRAMEWORK_ZIP"
xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" \
  -headers "$HEADERS_DIR" \
  -library "$SIMULATOR_LIB" \
  -headers "$HEADERS_DIR" \
  -output "$XCFRAMEWORK_DIR"

if command -v ditto >/dev/null 2>&1; then
  ditto -c -k --sequesterRsrc --keepParent "$XCFRAMEWORK_DIR" "$XCFRAMEWORK_ZIP"
else
  (cd "$DIST_DIR" && zip -qry "$(basename "$XCFRAMEWORK_ZIP")" "$(basename "$XCFRAMEWORK_DIR")")
fi

echo "Created artifact:"
echo "  $XCFRAMEWORK_ZIP"
