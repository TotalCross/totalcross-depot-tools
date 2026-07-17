#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  echo "Usage: fetch.sh --platform PLATFORM --arch ARCH [--release-tag TAG] [--github-repo OWNER/REPO] [--github-token-env ENV] [--dest DIR]" >&2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
platform=""
arch=""
release_tag="sljit-20260717"
github_repo="TotalCross/totalcross-depot-tools"
token_env="SLJIT_GITHUB_TOKEN"
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
[ -n "${platform}" ] && [ -n "${arch}" ] && [ -n "${dest_root}" ] || { usage; exit 2; }

case "${platform}/${arch}" in
  linux/amd64) arch=x86_64 ;;
  linux/arm64) arch=aarch64 ;;
  windows/amd64) arch=x64 ;;
  macos/aarch64) arch=arm64 ;;
esac
case "${platform}/${arch}" in
  linux/x86_64|linux/armv7l|linux/aarch64|windows/x86|windows/x64|windows/arm64|android/arm64-v8a|macos/arm64) ;;
  *)
    echo "Unsupported SLJIT platform/architecture: ${platform}/${arch}" >&2
    exit 2 ;;
esac
if ! [[ "${token_env}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Invalid token environment variable name" >&2
  exit 2
fi

asset="sljit-${platform}-${arch}.tar.gz"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
token="${!token_env:-${GITHUB_TOKEN:-}}"
curl_args=(-fsSL --retry 3 --retry-delay 2)
[ -z "${token}" ] || curl_args+=(-H "Authorization: Bearer ${token}")
curl "${curl_args[@]}" -o "${tmp_dir}/${asset}" \
  "https://github.com/${github_repo}/releases/download/${release_tag}/${asset}"
tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}"

root="${tmp_dir}/sljit/${platform}/${arch}"
for header in sljitLir.h sljitConfig.h sljitConfigCPU.h sljitConfigInternal.h; do
  [ -f "${root}/include/${header}" ] || {
    echo "Invalid SLJIT artifact: missing header ${header}" >&2
    exit 1
  }
done
if [ "${platform}" = windows ]; then
  library_name=sljit.lib
else
  library_name=libsljit.a
fi
[ -f "${root}/lib/${library_name}" ] || {
  echo "Invalid SLJIT artifact: missing ${library_name}" >&2
  exit 1
}
[ -f "${root}/share/licenses/sljit/LICENSE" ] || {
  echo "Invalid SLJIT artifact: missing license" >&2
  exit 1
}
package_manifest="${root}/manifest.txt"
[ -f "${package_manifest}" ] || { echo "Invalid SLJIT artifact: missing manifest" >&2; exit 1; }
grep -qx 'name=sljit' "${package_manifest}"
grep -qx 'upstream_commit=3907e69005ba6e30b225000f24aaef3632f88347' "${package_manifest}"
grep -qx 'executable_allocator=wx' "${package_manifest}"
grep -qx "platform_arch=${platform}/${arch}" "${package_manifest}"
case "${platform}" in
  windows) grep -qx 'msvc_runtime=MT' "${package_manifest}" ;;
  android)
    grep -qx 'android_abi=arm64-v8a' "${package_manifest}"
    grep -qx 'android_ndk=28.2.13676358' "${package_manifest}"
    grep -qx 'android_min_sdk=23' "${package_manifest}" ;;
esac

dest="${dest_root}/${platform}/${arch}"
rm -rf "${dest}"
mkdir -p "${dest}"
cp -a "${root}/." "${dest}/"
echo "Installed sljit ${platform}/${arch} into ${dest}"
