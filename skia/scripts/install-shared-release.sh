#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

SKIA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SKIA_DIR/../scripts/github-release.sh"
source "$SKIA_DIR/../scripts/artifact-install.sh"

manifest="$SKIA_DIR/artifacts.json"
github_repo="${SKIA_GITHUB_REPO:-}"
release_tag="${SKIA_RELEASE_TAG:-}"
token_env="${SKIA_GITHUB_TOKEN_ENV:-}"
base_url="${SKIA_ARTIFACT_BASE_URL:-}"
local_root="${SKIA_LOCAL_ROOT:-$SKIA_DIR/local}"

usage() {
  cat <<'EOF'
Usage: install-shared-release.sh [options]

Install the release-wide Skia development bundle and build manifests once.

Options:
  --manifest FILE          Artifact manifest, default: skia/artifacts.json
  --github-repo OWNER/REPO GitHub repository
  --release-tag TAG        GitHub release tag
  --github-token-env NAME  Dependency-specific token environment variable
  --base-url URL           Alternate artifact base URL
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest) manifest="${2:-}"; shift 2 ;;
    --github-repo) github_repo="${2:-}"; shift 2 ;;
    --release-tag) release_tag="${2:-}"; shift 2 ;;
    --github-token-env) token_env="${2:-}"; shift 2 ;;
    --base-url) base_url="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

shared_info="$(python3 - "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], "r") as handle:
    data = json.load(handle)
source = data.get("defaults", {}).get("source", {})
dev = data.get("defaults", {}).get("dev_bundle", {})
print(source.get("repo", ""))
print(source.get("tag", ""))
print(dev.get("artifact_name", ""))
print(dev.get("sha256", ""))
for key, item in sorted(data.get("metadata", {}).get("build-manifests", {}).items()):
    print("manifest\t%s\t%s\t%s\t%s" % (key, item["artifact_name"], item["target_path"], item.get("sha256", "")))
PY
)"

default_repo="$(printf '%s\n' "$shared_info" | sed -n '1p')"
default_tag="$(printf '%s\n' "$shared_info" | sed -n '2p')"
dev_asset="$(printf '%s\n' "$shared_info" | sed -n '3p')"
dev_sha="$(printf '%s\n' "$shared_info" | sed -n '4p')"
[ -n "$github_repo" ] || github_repo="$default_repo"
[ -n "$release_tag" ] || release_tag="$default_tag"
[ -n "$dev_asset" ] || { echo "Skia artifact manifest has no dev bundle" >&2; exit 2; }

identity_repo="$github_repo"
if [ -n "$base_url" ]; then
  identity_repo="base-url:${base_url}"
elif [ -z "$github_repo" ] || [ -z "$release_tag" ]; then
  echo "Skia shared installation requires a GitHub release or --base-url" >&2
  exit 2
fi

requirements=(include/core/SkCanvas.h src/gpu/gl/GrGLDefines.h)
while IFS=$'\t' read -r kind key asset target sha; do
  [ "$kind" = manifest ] || continue
  case "$target" in
    local/*) requirements+=("${target#local/}") ;;
    *) echo "Invalid Skia shared target path: ${target}" >&2; exit 2 ;;
  esac
done <<< "$(printf '%s\n' "$shared_info" | sed -n '5,$p')"

if tc_artifact_marker_matches "$local_root" skia-shared "$identity_repo" "$release_tag" "$dev_asset" "$dev_sha" "${requirements[@]}"; then
  echo "Reusing shared Skia release content from $local_root"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
dev_file="$tmp_dir/$dev_asset"
download_asset() {
  local asset_name="$1"
  local destination="$2"
  if [ -n "$base_url" ]; then
    tc_github_release_download_url "${base_url%/}/${asset_name}" "$destination" "Skia shared ${asset_name}" ''
  else
    tc_github_release_download "$github_repo" "$release_tag" "$asset_name" "$destination" "$token_env" SKIA_GITHUB_TOKEN
  fi
}
verify_asset() {
  local path="$1"
  local expected="$2"
  local label="$3"
  local actual
  actual="$(tc_github_release_sha256_file "$path")"
  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
    echo "Skia checksum mismatch for ${label}: expected ${expected}, got ${actual}" >&2
    return 1
  fi
}

download_asset "$dev_asset" "$dev_file"
verify_asset "$dev_file" "$dev_sha" "$dev_asset"
manifest_records="$tmp_dir/manifest-records"
: > "$manifest_records"
while IFS=$'\t' read -r kind key asset target sha; do
  [ "$kind" = manifest ] || continue
  downloaded="$tmp_dir/$asset"
  download_asset "$asset" "$downloaded"
  verify_asset "$downloaded" "$sha" "$asset"
  printf '%s\t%s\n' "$downloaded" "$target" >> "$manifest_records"
done <<< "$(printf '%s\n' "$shared_info" | sed -n '5,$p')"

dev_tree="$tmp_dir/dev"
mkdir -p "$dev_tree"
case "$dev_asset" in
  *.zip)
    python3 - "$dev_file" "$dev_tree" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    archive.extractall(sys.argv[2])
PY
    ;;
  *) tar -xzf "$dev_file" -C "$dev_tree" ;;
esac
tc_artifact_requirements_present "$dev_tree/modules/skia" include/core/SkCanvas.h src/gpu/gl/GrGLDefines.h || {
  echo "Skia dev bundle is incomplete" >&2
  exit 1
}

mkdir -p "$local_root"
if command -v rsync >/dev/null 2>&1; then
  rsync -a "$dev_tree/modules/skia/" "$local_root/"
else
  cp -R "$dev_tree/modules/skia/." "$local_root/"
fi
while IFS=$'\t' read -r downloaded target; do
  target_path="$local_root/${target#local/}"
  mkdir -p "$(dirname "$target_path")"
  target_tmp="$(mktemp "$(dirname "$target_path")/.skia-shared.XXXXXX")"
  cp "$downloaded" "$target_tmp"
  mv -f "$target_tmp" "$target_path"
done < "$manifest_records"

dev_actual="$(tc_github_release_sha256_file "$dev_file")"
tc_artifact_write_marker "$local_root" skia-shared "$identity_repo" "$release_tag" "$dev_asset" "$dev_actual"
tc_artifact_requirements_present "$local_root" "${requirements[@]}"
echo "Installed shared Skia release content into $local_root"
