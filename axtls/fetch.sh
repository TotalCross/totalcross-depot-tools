#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  echo "Usage: fetch.sh --platform PLATFORM --arch ARCH [--release-tag TAG] [--github-repo OWNER/REPO] [--dest DIR]" >&2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/../scripts/github-release.sh"
source "${script_dir}/../scripts/artifact-install.sh"
platform=""
arch=""
release_tag="axtls-2.1.5-tc.1"
github_repo="TotalCross/totalcross-depot-tools"
token_env="AXTLS_GITHUB_TOKEN"
dest_root="${script_dir}/local"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform) platform="${2:-}"; shift 2 ;;
    --arch) arch="${2:-}"; shift 2 ;;
    --release-tag) release_tag="${2:-}"; shift 2 ;;
    --github-repo) github_repo="${2:-}"; shift 2 ;;
    --github-token-env) token_env="${2:-}"; shift 2 ;;
    --dest) dest_root="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "${platform}" ] && [ -n "${arch}" ] || { usage; exit 2; }

case "${platform}/${arch}" in
  linux/amd64) arch=x86_64 ;;
  linux/arm64) arch=aarch64 ;;
  linux/arm|linux/armv7) arch=armv7l ;;
  windows/amd64|windows/x86_64) arch=x64 ;;
  windows/i386|windows/i686) arch=x86 ;;
  macos/aarch64|ios/aarch64|ios-simulator/aarch64) arch=arm64 ;;
esac

asset="axtls-${platform}-${arch}.tar.gz"
dest="${dest_root}/${platform}/${arch}"
requirements=(
  'include/axtls/axtls.h'
  'lib/libaxtls.a|lib/axtls.lib'
)
if tc_artifact_marker_matches "$dest" "axtls" "$github_repo" "$release_tag" "$asset" "" "${requirements[@]}"; then
  echo "Reusing axTLS ${platform}/${arch} from ${dest}"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
tc_github_release_download "${github_repo}" "${release_tag}" "${asset}" "${tmp_dir}/${asset}" \
  "${token_env}" AXTLS_GITHUB_TOKEN
tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}"

root="${tmp_dir}/axtls/${platform}/${arch}"
[ -f "${root}/include/axtls/axtls.h" ] || { echo "Invalid axTLS artifact: missing header" >&2; exit 1; }
find "${root}/lib" -type f \( -name 'libaxtls.a' -o -name 'axtls.lib' \) | grep -q . ||
  { echo "Invalid axTLS artifact: missing static library" >&2; exit 1; }

tc_artifact_replace_tree "${root}" "$dest" "axtls" "$github_repo" "$release_tag" "$asset" \
  "$TC_GITHUB_RELEASE_DOWNLOADED_SHA256" "${requirements[@]}"
echo "Installed axTLS ${platform}/${arch} into ${dest}"
