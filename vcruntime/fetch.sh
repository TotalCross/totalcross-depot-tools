#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fetch.sh [options]

Options:
  --platform PLATFORM      Target platform: windows
  --arch ARCH              Target architecture: x86, x64, or arm64
  --release-tag TAG        GitHub release tag, default: vcruntime-14
  --github-repo OWNER/REPO GitHub repository, default: TotalCross/totalcross-depot-tools
  --github-token-env NAME  Environment variable containing a GitHub token,
                           default: VCRUNTIME_GITHUB_TOKEN, then GITHUB_TOKEN
  --dest DIR               Destination root, default: vcruntime/local
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

platform=""
arch=""
release_tag="vcruntime-14"
github_repo="TotalCross/totalcross-depot-tools"
github_token_env=""
dest_root="${script_dir}/local"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      shift 2
      ;;
    --arch)
      arch="${2:-}"
      shift 2
      ;;
    --release-tag)
      release_tag="${2:-}"
      shift 2
      ;;
    --github-repo)
      github_repo="${2:-}"
      shift 2
      ;;
    --github-token-env)
      github_token_env="${2:-}"
      shift 2
      ;;
    --dest)
      dest_root="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "${platform}" ] || [ -z "${arch}" ]; then
  usage >&2
  exit 2
fi

if [[ ! "${github_repo}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid vcruntime GitHub repository value. Expected OWNER/REPO." >&2
  exit 2
fi

if [[ "${release_tag}" == *"{"* ||
      "${release_tag}" == *"}"* ||
      "${release_tag}" == *" "* ||
      "${release_tag}" == *"/"* ||
      "${release_tag}" == *"\\"* ||
      "${release_tag}" == *".."* ]]; then
  echo "Invalid vcruntime release tag value." >&2
  exit 2
fi

case "${platform}" in
  windows|win32) platform="windows" ;;
  *)
    echo "Unsupported vcruntime platform: ${platform}" >&2
    usage >&2
    exit 2
    ;;
esac

case "${arch}" in
  Win32|win32|i386|i686) arch="x86" ;;
  amd64|x86_64) arch="x64" ;;
  ARM64) arch="arm64" ;;
esac

case "${arch}" in
  x86|x64|arm64) ;;
  *)
    echo "Unsupported vcruntime architecture: ${arch}" >&2
    usage >&2
    exit 2
    ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

source "${script_dir}/../scripts/github-release.sh"
source "${script_dir}/../scripts/artifact-install.sh"

asset_name="vcruntime-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"
dest="${dest_root}/${platform}/${arch}"
requirements=(
  'vcruntime140.dll'
  'manifest.txt'
  'NOTICE.txt'
)
if tc_artifact_marker_matches "$dest" "vcruntime" "$github_repo" "$release_tag" "$asset_name" "" "${requirements[@]}"; then
  echo "Reusing vcruntime ${platform}/${arch} from ${dest}"
  exit 0
fi


if ! tc_github_release_download "${github_repo}" "${release_tag}" "${asset_name}" "${archive}" \
  "${github_token_env}" VCRUNTIME_GITHUB_TOKEN; then
  echo "Unable to download a vcruntime artifact for ${platform}/${arch}" >&2
  exit 1
fi

tar -tzf "${archive}" >/dev/null
tar -xzf "${archive}" -C "${tmp_dir}"

dll_path="$(find "${tmp_dir}" -path "*/vcruntime140.dll" -type f | head -n 1)"
if [ -z "${dll_path}" ]; then
  echo "Unable to find vcruntime140.dll in ${asset_name}" >&2
  exit 1
fi

artifact_root="$(cd "$(dirname "${dll_path}")" && pwd)"
for required_file in manifest.txt NOTICE.txt; do
  if [ ! -f "${artifact_root}/${required_file}" ]; then
    echo "Unable to find ${required_file} in ${asset_name}" >&2
    exit 1
  fi
done

tc_artifact_replace_tree "${artifact_root}" "$dest" "vcruntime" "$github_repo" "$release_tag" "$asset_name" \
  "$TC_GITHUB_RELEASE_DOWNLOADED_SHA256" "${requirements[@]}"

echo "Installed vcruntime ${platform}/${arch} into ${dest}"
