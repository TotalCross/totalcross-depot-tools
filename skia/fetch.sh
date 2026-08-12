#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$ROOT_DIR/../scripts/github-release.sh"
source "$ROOT_DIR/../scripts/artifact-install.sh"
MANIFEST_PATH="$ROOT_DIR/artifacts.json"
BASE_URL="${SKIA_ARTIFACT_BASE_URL:-}"
GITHUB_REPO="${SKIA_GITHUB_REPO:-}"
RELEASE_TAG="${SKIA_RELEASE_TAG:-}"
GITHUB_TOKEN_ENV="${SKIA_GITHUB_TOKEN_ENV:-}"
PLATFORM=""
ARCH=""
SOURCE=""
BUILD_CONFIG_SOURCE=""
INSTALL_DEV_BUNDLE=0
INSTALL_SHARED_ONLY=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Installs a Skia artifact outside Git tracking, either from a local file or from
an artifact base URL or a GitHub Release.

Options:
  --platform <name>   Target platform: ios, ios-simulator, macos, linux,
                      wasm, android, windows.
  --arch <name>       Target arch/ABI: arm64, x86, x64, x86_64, aarch64,
                      armv7l, wasm32, arm64-v8a.
  --source <path|url> Install from a specific local file or URL.
  --build-config <path|url>
                      Matching SkiaBuildConfig.cmake for --source.
  --base-url <url>    Base URL used with the manifest artifact_name.
  --github-repo <r>   GitHub repo in owner/name format.
  --release-tag <t>   GitHub release tag.
  --github-token-env <name>
                      Environment variable containing a GitHub token,
                      default: SKIA_GITHUB_TOKEN, then GITHUB_TOKEN.
  --manifest <file>   Manifest file. Default: $MANIFEST_PATH
  --install-dev       Install the target and shared release content (legacy).
  --install-shared    Install only shared release content; no target is required.
  --print-target      Print the resolved output path and exit.
  -h, --help          Show this help.

Examples:
  $(basename "$0")
  $(basename "$0") --platform macos --arch arm64 --source /tmp/libskia.a
  $(basename "$0") --platform macos --arch arm64 --source /tmp/libskia.a --build-config /tmp/SkiaBuildConfig.cmake
  $(basename "$0") --platform linux --arch x86_64 --base-url https://artifacts.example.com/skia/m87
  $(basename "$0") --platform ios --arch arm64
  $(basename "$0") --platform ios-simulator --arch arm64
  $(basename "$0") --github-repo TotalCross/totalcross-depot-tools --release-tag skia-158dc9d7-r7
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

github_token() {
  tc_github_release_token "$GITHUB_TOKEN_ENV" SKIA_GITHUB_TOKEN
}

SKIA_DOWNLOAD_RETRIES="${SKIA_DOWNLOAD_RETRIES:-5}"
SKIA_DOWNLOAD_RETRY_DELAY="${SKIA_DOWNLOAD_RETRY_DELAY:-2}"

download_to_file() {
  local url="$1"
  local out="$2"
  local token
  token="$(github_token)"
  TOTALCROSS_DEPOT_FETCH_ATTEMPTS="${TOTALCROSS_DEPOT_FETCH_ATTEMPTS:-$SKIA_DOWNLOAD_RETRIES}" \
    TOTALCROSS_DEPOT_FETCH_RETRY_DELAY="${TOTALCROSS_DEPOT_FETCH_RETRY_DELAY:-$SKIA_DOWNLOAD_RETRY_DELAY}" \
    tc_github_release_download_url "$url" "$out" 'Skia artifact URL' "$token"
}

download_github_asset() {
  local asset_name="$1"
  local out="$2"
  tc_github_release_download "$GITHUB_REPO" "$RELEASE_TAG" "$asset_name" "$out" \
    "$GITHUB_TOKEN_ENV" SKIA_GITHUB_TOKEN
}

verify_sha256() {
  local file_path="$1"
  local expected_sha="$2"
  local label="$3"

  if [[ -n "$expected_sha" ]]; then
    local actual_sha
    actual_sha=$(tc_github_release_sha256_file "$file_path")
    [[ "$actual_sha" == "$expected_sha" ]] || die "checksum mismatch for ${label}: expected ${expected_sha}, got ${actual_sha}"
  else
    echo "warning: no sha256 configured for ${label} in ${MANIFEST_PATH}" >&2
  fi
}

normalize_platform() {
  case "$1" in
    iOS|ios) echo "ios" ;;
    ios-simulator|iphonesimulator) echo "ios-simulator" ;;
    Darwin|darwin|macos|mac|osx) echo "macos" ;;
    Linux|linux) echo "linux" ;;
    wasm|wasm32|Emscripten|emscripten) echo "wasm" ;;
    Android|android) echo "android" ;;
    Windows|windows|mingw*|MINGW*|msys*|MSYS*) echo "windows" ;;
    *) die "unsupported platform: $1" ;;
  esac
}

normalize_arch() {
  case "$1" in
    universal) echo "universal" ;;
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "x86_64" ;;
    x64) echo "x64" ;;
    x86|i386|i686) echo "x86" ;;
    armv7l|armv7) echo "armv7l" ;;
    wasm|wasm32) echo "wasm32" ;;
    arm64-v8a) echo "arm64-v8a" ;;
    *) die "unsupported architecture/ABI: $1" ;;
  esac
}

detect_platform() {
  normalize_platform "$(uname -s)"
}

detect_arch() {
  normalize_arch "$(uname -m)"
}

PRINT_TARGET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || die "--platform requires a value"
      PLATFORM=$(normalize_platform "$2")
      shift 2
      ;;
    --arch)
      [[ $# -ge 2 ]] || die "--arch requires a value"
      ARCH=$(normalize_arch "$2")
      shift 2
      ;;
    --source)
      [[ $# -ge 2 ]] || die "--source requires a value"
      SOURCE="$2"
      shift 2
      ;;
    --build-config)
      [[ $# -ge 2 ]] || die "--build-config requires a value"
      BUILD_CONFIG_SOURCE="$2"
      shift 2
      ;;
    --base-url)
      [[ $# -ge 2 ]] || die "--base-url requires a value"
      BASE_URL="$2"
      shift 2
      ;;
    --github-repo)
      [[ $# -ge 2 ]] || die "--github-repo requires a value"
      GITHUB_REPO="$2"
      shift 2
      ;;
    --release-tag)
      [[ $# -ge 2 ]] || die "--release-tag requires a value"
      RELEASE_TAG="$2"
      shift 2
      ;;
    --github-token-env)
      [[ $# -ge 2 ]] || die "--github-token-env requires a value"
      GITHUB_TOKEN_ENV="$2"
      shift 2
      ;;
    --manifest)
      [[ $# -ge 2 ]] || die "--manifest requires a value"
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --install-dev)
      INSTALL_DEV_BUNDLE=1
      shift
      ;;
    --install-shared)
      INSTALL_SHARED_ONLY=1
      shift
      ;;
    --print-target)
      PRINT_TARGET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_cmd python3

install_shared_release() {
  local args=(--manifest "$MANIFEST_PATH")
  [[ -z "$GITHUB_REPO" ]] || args+=(--github-repo "$GITHUB_REPO")
  [[ -z "$RELEASE_TAG" ]] || args+=(--release-tag "$RELEASE_TAG")
  [[ -z "$GITHUB_TOKEN_ENV" ]] || args+=(--github-token-env "$GITHUB_TOKEN_ENV")
  [[ -z "$BASE_URL" ]] || args+=(--base-url "$BASE_URL")
  bash "$ROOT_DIR/scripts/install-shared-release.sh" "${args[@]}"
}

if [[ $INSTALL_SHARED_ONLY -eq 1 ]]; then
  install_shared_release
  exit 0
fi

[[ -n "$PLATFORM" ]] || PLATFORM=$(detect_platform)
[[ -n "$ARCH" ]] || ARCH=$(detect_arch)

if [[ "$PLATFORM" == "linux" && "$ARCH" == "arm64" ]]; then
  ARCH="aarch64"
fi

if [[ "$PLATFORM" == "windows" && "$ARCH" == "x86_64" ]]; then
  ARCH="x64"
fi

if [[ -n "$GITHUB_REPO" && ! "$GITHUB_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  die "invalid Skia GitHub repository value. Expected OWNER/REPO."
fi

if [[ "$RELEASE_TAG" == *"{"* ||
      "$RELEASE_TAG" == *"}"* ||
      "$RELEASE_TAG" == *" "* ||
      "$RELEASE_TAG" == *"/"* ||
      "$RELEASE_TAG" == *"\\"* ||
      "$RELEASE_TAG" == *".."* ]]; then
  die "invalid Skia release tag value: ${RELEASE_TAG}"
fi

ARTIFACT_KEY="${PLATFORM}-${ARCH}"

ARTIFACT_INFO=$(
  python3 - "$MANIFEST_PATH" "$ARTIFACT_KEY" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
artifact_key = sys.argv[2]

manifest = json.loads(manifest_path.read_text())
artifact = manifest["artifacts"].get(artifact_key)
if artifact is None:
    sys.exit(2)

print(artifact["artifact_name"])
print(artifact["target_path"])
print(artifact.get("sha256", ""))
defaults = manifest.get("defaults", {})
source = defaults.get("source", {})
print(source.get("type", ""))
print(source.get("repo", ""))
print(source.get("tag", ""))
dev_bundle = defaults.get("dev_bundle", {})
print(dev_bundle.get("artifact_name", ""))
print(dev_bundle.get("sha256", ""))
build_config = manifest.get("metadata", {}).get("machine-build-configs", {}).get(artifact_key)
if build_config is None:
    sys.exit(3)
print(build_config["artifact_name"])
print(build_config["target_path"])
print(build_config.get("sha256", ""))
machine_build_config = defaults.get("machine_build_config", {})
print("true" if machine_build_config.get("required", False) else "false")
PY
) || die "artifact '${ARTIFACT_KEY}' not found in manifest ${MANIFEST_PATH}"

ARTIFACT_NAME=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '1p')
TARGET_PATH_REL=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '2p')
EXPECTED_SHA=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '3p')
DEFAULT_SOURCE_TYPE=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '4p')
DEFAULT_GITHUB_REPO=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '5p')
DEFAULT_RELEASE_TAG=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '6p')
DEV_BUNDLE_NAME=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '7p')
DEV_BUNDLE_SHA=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '8p')
BUILD_CONFIG_NAME=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '9p')
BUILD_CONFIG_TARGET_REL=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '10p')
BUILD_CONFIG_SHA=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '11p')
DEFAULT_BUILD_CONFIG_REQUIRED=$(printf '%s\n' "$ARTIFACT_INFO" | sed -n '12p')
TARGET_PATH="$ROOT_DIR/$TARGET_PATH_REL"
BUILD_CONFIG_TARGET="$ROOT_DIR/$BUILD_CONFIG_TARGET_REL"

if [[ -z "$GITHUB_REPO" ]]; then
  GITHUB_REPO="$DEFAULT_GITHUB_REPO"
fi

if [[ -z "$RELEASE_TAG" ]]; then
  RELEASE_TAG="$DEFAULT_RELEASE_TAG"
fi

if [[ $PRINT_TARGET -eq 1 ]]; then
  printf '%s\n' "$TARGET_PATH"
  exit 0
fi

TARGET_ROOT="$(dirname "$TARGET_PATH")"
TARGET_REQUIREMENTS=("$(basename "$TARGET_PATH")" "$(basename "$BUILD_CONFIG_TARGET")")
if tc_artifact_marker_matches "$TARGET_ROOT" skia "$GITHUB_REPO" "$RELEASE_TAG" "$ARTIFACT_NAME" "$EXPECTED_SHA" "${TARGET_REQUIREMENTS[@]}"; then
  echo "Reusing ${ARTIFACT_KEY} Skia artifact from ${TARGET_ROOT}"
  if [[ $INSTALL_DEV_BUNDLE -eq 1 ]]; then
    install_shared_release
  fi
  exit 0
fi

mkdir -p "$(dirname "$TARGET_PATH")"
mkdir -p "$(dirname "$BUILD_CONFIG_TARGET")"

TMP_FILE=$(mktemp /tmp/skia-artifact.XXXXXX)
TMP_BUILD_CONFIG=$(mktemp /tmp/skia-build-config.XXXXXX)
TARGET_TMP=""
BUILD_CONFIG_TARGET_TMP=""
cleanup() {
  rm -f "$TMP_FILE"
  rm -f "$TMP_BUILD_CONFIG"
  if [[ -n "$TARGET_TMP" ]]; then
    rm -f "$TARGET_TMP"
  fi
  if [[ -n "$BUILD_CONFIG_TARGET_TMP" ]]; then
    rm -f "$BUILD_CONFIG_TARGET_TMP"
  fi
  return 0
}
trap cleanup EXIT

if [[ -n "$SOURCE" ]]; then
  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$TMP_FILE"
  else
    download_to_file "$SOURCE" "$TMP_FILE"
  fi
elif [[ -n "$BASE_URL" ]]; then
  download_to_file "${BASE_URL%/}/${ARTIFACT_NAME}" "$TMP_FILE"
elif [[ "$DEFAULT_SOURCE_TYPE" == "github_release" || -n "$GITHUB_REPO" || -n "$RELEASE_TAG" ]]; then
  [[ -n "$GITHUB_REPO" ]] || die "missing GitHub repo. Use --github-repo or set defaults.source.repo in the manifest"
  [[ -n "$RELEASE_TAG" ]] || die "missing release tag. Use --release-tag or set defaults.source.tag in the manifest"
  download_github_asset "$ARTIFACT_NAME" "$TMP_FILE"
else
  die "either --source, --base-url/SKIA_ARTIFACT_BASE_URL, or a GitHub release default is required"
fi

verify_sha256 "$TMP_FILE" "$EXPECTED_SHA" "$ARTIFACT_KEY"

INSTALL_BUILD_CONFIG=0
if [[ "$DEFAULT_BUILD_CONFIG_REQUIRED" == "true" ||
      -n "$BUILD_CONFIG_SOURCE" ||
      -n "$BASE_URL" ||
      "$GITHUB_REPO" != "$DEFAULT_GITHUB_REPO" ||
      "$RELEASE_TAG" != "$DEFAULT_RELEASE_TAG" ]]; then
  INSTALL_BUILD_CONFIG=1
fi

if [[ $INSTALL_BUILD_CONFIG -eq 1 && -n "$BUILD_CONFIG_SOURCE" ]]; then
  if [[ -f "$BUILD_CONFIG_SOURCE" ]]; then
    cp "$BUILD_CONFIG_SOURCE" "$TMP_BUILD_CONFIG"
  else
    download_to_file "$BUILD_CONFIG_SOURCE" "$TMP_BUILD_CONFIG"
  fi
elif [[ $INSTALL_BUILD_CONFIG -eq 1 && -n "$SOURCE" ]]; then
  die "--source requires a matching --build-config; backend metadata cannot be inferred"
elif [[ $INSTALL_BUILD_CONFIG -eq 1 && -n "$BASE_URL" ]]; then
  download_to_file "${BASE_URL%/}/${BUILD_CONFIG_NAME}" "$TMP_BUILD_CONFIG"
elif [[ $INSTALL_BUILD_CONFIG -eq 1 && ( "$DEFAULT_SOURCE_TYPE" == "github_release" || -n "$GITHUB_REPO" || -n "$RELEASE_TAG" ) ]]; then
  download_github_asset "$BUILD_CONFIG_NAME" "$TMP_BUILD_CONFIG"
elif [[ $INSTALL_BUILD_CONFIG -eq 1 ]]; then
  die "unable to resolve matching Skia build metadata"
fi

if [[ $INSTALL_BUILD_CONFIG -eq 1 ]]; then
  verify_sha256 "$TMP_BUILD_CONFIG" "$BUILD_CONFIG_SHA" "build-config-${ARTIFACT_KEY}"
  python3 "$ROOT_DIR/scripts/validate-build-config.py" \
    --build-config "$TMP_BUILD_CONFIG" \
    --library "$TMP_FILE" \
    --platform "$PLATFORM" \
    --architecture "$ARCH"
else
  echo "warning: installing legacy Skia artifact without machine build metadata" >&2
fi

TARGET_TMP=$(mktemp "$(dirname "$TARGET_PATH")/.libskia-install.XXXXXX")
cp "$TMP_FILE" "$TARGET_TMP"
if [[ $INSTALL_BUILD_CONFIG -eq 1 ]]; then
  BUILD_CONFIG_TARGET_TMP=$(mktemp "$(dirname "$BUILD_CONFIG_TARGET")/.skia-build-config-install.XXXXXX")
  cp "$TMP_BUILD_CONFIG" "$BUILD_CONFIG_TARGET_TMP"
fi
mv -f "$TARGET_TMP" "$TARGET_PATH"
TARGET_TMP=""
if [[ $INSTALL_BUILD_CONFIG -eq 1 ]]; then
  mv -f "$BUILD_CONFIG_TARGET_TMP" "$BUILD_CONFIG_TARGET"
  BUILD_CONFIG_TARGET_TMP=""
fi

echo "Installed ${ARTIFACT_KEY} artifact at:"
echo "  $TARGET_PATH"
if [[ $INSTALL_BUILD_CONFIG -eq 1 ]]; then
  echo "  $BUILD_CONFIG_TARGET"
fi

ACTUAL_SHA="$(tc_github_release_sha256_file "$TARGET_PATH")"
tc_artifact_write_marker "$TARGET_ROOT" skia "$GITHUB_REPO" "$RELEASE_TAG" "$ARTIFACT_NAME" "$ACTUAL_SHA"

if [[ $INSTALL_DEV_BUNDLE -eq 1 ]]; then
  install_shared_release
fi
