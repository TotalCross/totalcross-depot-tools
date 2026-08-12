#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fetch.sh [options]

Options:
  --platform PLATFORM      Target platform: linux, windows, android, ios, ios-simulator, macos
  --arch ARCH              Target architecture, e.g. x86_64, armv7l, aarch64
  --release-tag TAG        GitHub release tag, default: sqlite3-3.32.3
  --github-repo OWNER/REPO GitHub repository, default: TotalCross/totalcross-depot-tools
  --github-token-env NAME  Environment variable containing a GitHub token,
                           default: SQLITE3_GITHUB_TOKEN, then GITHUB_TOKEN
  --dest DIR               Destination root, default: sqlite3/local.
                           Artifacts install under DIR/<release-tag>-<repo-hash12>/<platform>/<arch>
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

platform=""
arch=""
release_tag="sqlite3-3.32.3"
github_repo="TotalCross/totalcross-depot-tools"
github_token_env=""
dest_root="${script_dir}/local"

log() {
  echo "[sqlite3-fetch] $*" >&2
}

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
  echo "Invalid SQLite3 GitHub repository value. Expected OWNER/REPO." >&2
  exit 2
fi

if [[ "${release_tag}" == *"{"* ||
      "${release_tag}" == *"}"* ||
      "${release_tag}" == *" "* ||
      "${release_tag}" == *"/"* ||
      "${release_tag}" == *"\\"* ||
      "${release_tag}" == *".."* ]]; then
  echo "Invalid SQLite3 release tag value." >&2
  exit 2
fi

repo_hash="$(
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "${github_repo}" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "${github_repo}" | shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "${github_repo}" | openssl dgst -sha256 | awk '{print $NF}'
  else
    echo "Unable to compute SQLite3 repository hash; sha256sum, shasum, or openssl is required." >&2
    exit 1
  fi
)"
repo_hash="${repo_hash:0:12}"
install_namespace="${release_tag}-${repo_hash}"

log "platform input: ${platform}"
log "arch input: ${arch}"
log "release tag: ${release_tag}"
log "repo hash: ${repo_hash}"
log "destination root: ${dest_root}"

case "${platform}" in
  linux)
    case "${arch}" in
      amd64) arch="x86_64" ;;
      arm64) arch="aarch64" ;;
      arm|armv7) arch="armv7l" ;;
    esac
    ;;
  macos|ios|ios-simulator)
    case "${arch}" in
      aarch64) arch="arm64" ;;
      amd64) arch="x86_64" ;;
    esac
    ;;
  windows)
    case "${arch}" in
      Win32|win32) arch="x86" ;;
      x86_64) arch="x64" ;;
      ARM64) arch="arm64" ;;
    esac
    ;;
esac

log "normalized platform: ${platform}"
log "normalized arch: ${arch}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

source "${script_dir}/../scripts/github-release.sh"
source "${script_dir}/../scripts/artifact-install.sh"

download_release_asset() {
  tc_github_release_download "${github_repo}" "${release_tag}" "$1" "$2" \
    "${github_token_env}" SQLITE3_GITHUB_TOKEN
}

asset_name="sqlite3-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"
dest="${dest_root}/${install_namespace}/${platform}/${arch}"
requirements=(
  'include/sqlite3.h'
  'include/sqlite3ext.h'
  'lib/libsqlite3.a|lib/sqlite3.lib'
)
if tc_artifact_marker_matches "$dest" "sqlite3" "$github_repo" "$release_tag" "$asset_name" "" "${requirements[@]}"; then
  echo "Reusing SQLite3 ${platform}/${arch} from ${dest}"
  exit 0
fi


if ! download_release_asset "${asset_name}" "${archive}"; then
  echo "Unable to download a SQLite3 artifact for ${github_repo}@${release_tag}/${platform}/${arch}" >&2
  exit 1
fi

log "validating downloaded archive"
echo "SQLite3 release: ${github_repo}@${release_tag}"
echo "SQLite3 namespace: ${install_namespace}"
echo "SQLite3 artifact: ${asset_name}"

tar -tzf "${archive}" >/dev/null
tar -xzf "${archive}" -C "${tmp_dir}"

include_header="$(find "${tmp_dir}" -path "*/include/sqlite3.h" -type f | head -n 1)"
if [ -z "${include_header}" ]; then
  echo "Unable to find include/sqlite3.h in ${asset_name}" >&2
  exit 1
fi
log "found sqlite3 header: ${include_header#${tmp_dir}/}"

artifact_root="$(cd "$(dirname "${include_header}")/.." && pwd)"
if ! find "${artifact_root}/lib" -type f \( -name "libsqlite3.a" -o -name "sqlite3.lib" \) | grep -q .; then
  echo "Unable to find sqlite3 static library under ${artifact_root}/lib" >&2
  exit 1
fi
log "artifact root: ${artifact_root#${tmp_dir}/}"

tc_artifact_replace_tree "${artifact_root}" "$dest" "sqlite3" "$github_repo" "$release_tag" "$asset_name" \
  "$TC_GITHUB_RELEASE_DOWNLOADED_SHA256" "${requirements[@]}"

echo "Installed SQLite3 ${github_repo}@${release_tag}/${platform}/${arch} into ${dest}"
log "done"
