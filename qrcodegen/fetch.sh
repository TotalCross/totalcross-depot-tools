#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  echo "Usage: fetch.sh --platform PLATFORM --arch ARCH [--release-tag TAG] [--github-repo OWNER/REPO] [--dest DIR]" >&2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
platform=""
arch=""
release_tag="qrcodegen-20250123"
github_repo="TotalCross/totalcross-depot-tools"
token_env="QRCODEGEN_GITHUB_TOKEN"
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

asset="qrcodegen-${platform}-${arch}.tar.gz"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
source "${script_dir}/../scripts/github-release.sh"
tc_github_release_download "${github_repo}" "${release_tag}" "${asset}" "${tmp_dir}/${asset}" \
  "${token_env}" QRCODEGEN_GITHUB_TOKEN
tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}"

root="${tmp_dir}/qrcodegen/${platform}/${arch}"
[ -f "${root}/include/qrcodegen.h" ] || { echo "Invalid qrcodegen artifact: missing header" >&2; exit 1; }
find "${root}/lib" -type f \( -name 'libqrcodegen.a' -o -name 'qrcodegen.lib' \) | grep -q . ||
  { echo "Invalid qrcodegen artifact: missing static library" >&2; exit 1; }
dest="${dest_root}/${platform}/${arch}"
rm -rf "${dest}"
mkdir -p "${dest}"
cp -a "${root}/." "${dest}/"
echo "Installed qrcodegen ${platform}/${arch} into ${dest}"
