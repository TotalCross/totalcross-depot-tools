#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fetch.sh [options]

Options:
  --platform PLATFORM      Target platform: linux, windows, or macos
  --arch ARCH              Target architecture for the selected platform
  --release-tag TAG        Explicit release handoff; defaults to the deps.yml pin
  --github-repo OWNER/REPO GitHub repository, default: TotalCross/totalcross-depot-tools
  --github-token-env NAME  Environment variable containing a GitHub token,
                           default: SDL2_GITHUB_TOKEN, then GITHUB_TOKEN
  --dest DIR               Destination root, default: sdl2/local
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
platform=""
arch=""
release_tag=""
github_repo="TotalCross/totalcross-depot-tools"
github_token_env=""
dest_root="${script_dir}/local"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform|--arch|--release-tag|--github-repo|--github-token-env|--dest)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      case "$1" in
        --platform) platform="$2" ;;
        --arch) arch="$2" ;;
        --release-tag) release_tag="$2" ;;
        --github-repo) github_repo="$2" ;;
        --github-token-env) github_token_env="$2" ;;
        --dest) dest_root="$2" ;;
      esac
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
  echo "Invalid sdl2 GitHub repository value. Expected OWNER/REPO." >&2
  exit 2
fi
if [ -n "${github_token_env}" ] &&
   [[ ! "${github_token_env}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Invalid sdl2 GitHub token environment variable name." >&2
  exit 2
fi

case "${platform}" in
  linux)
    case "${arch}" in
      amd64) arch="x86_64" ;;
      arm64) arch="aarch64" ;;
      arm|armv7) arch="armv7l" ;;
    esac
    case "${arch}" in x86_64|armv7l|aarch64) ;; *) echo "Unsupported sdl2 Linux architecture: ${arch}" >&2; exit 2 ;; esac
    ;;
  windows)
    case "${arch}" in
      amd64|x86_64) arch="x64" ;;
      i386|i686|Win32|win32) arch="x86" ;;
      ARM64) arch="arm64" ;;
    esac
    case "${arch}" in x86|x64|arm64) ;; *) echo "Unsupported sdl2 Windows architecture: ${arch}" >&2; exit 2 ;; esac
    ;;
  macos)
    case "${arch}" in aarch64) arch="arm64" ;; esac
    if [ "${arch}" != "arm64" ]; then
      echo "Unsupported sdl2 macOS architecture: ${arch}" >&2
      exit 2
    fi
    ;;
  *)
    echo "Unsupported sdl2 platform: ${platform}" >&2
    exit 2
    ;;
esac

if [ -z "${release_tag}" ] && [ -f "${repo_root}/deps.yml" ]; then
  release_tag="$(awk '
    /^  sdl2:[[:space:]]*$/ { in_sdl2 = 1; next }
    in_sdl2 && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { in_sdl2 = 0 }
    in_sdl2 && /^    release:[[:space:]]*/ { sub(/^    release:[[:space:]]*/, ""); print; exit }
  ' "${repo_root}/deps.yml")"
fi
if [ -z "${release_tag}" ]; then
  echo "No sdl2 release is pinned in deps.yml; pass --release-tag for an explicit release handoff." >&2
  exit 2
fi
if [[ "${release_tag}" == *"{"* ||
      "${release_tag}" == *"}"* ||
      "${release_tag}" == *" "* ||
      "${release_tag}" == *"/"* ||
      "${release_tag}" == *"\\"* ||
      "${release_tag}" == *".."* ]]; then
  echo "Invalid sdl2 release tag value." >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

source "${repo_root}/scripts/github-release.sh"
source "${repo_root}/scripts/artifact-install.sh"

asset_name="sdl2-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"
dest="${dest_root}/${platform}/${arch}"
requirements=(
  'include/SDL2/SDL.h'
  'lib/libSDL2.a|lib/SDL2-static.lib|lib/SDL2.lib'
  'lib/cmake/SDL2/SDL2Config.cmake'
  'lib/cmake/SDL2/SDL2staticTargets.cmake'
  'manifest.txt'
)

if tc_artifact_marker_matches "${dest}" sdl2 "${github_repo}" "${release_tag}" \
  "${asset_name}" "" "${requirements[@]}"; then
  echo "Reusing sdl2 ${platform}/${arch} from ${dest}"
  exit 0
fi

if ! tc_github_release_download "${github_repo}" "${release_tag}" "${asset_name}" \
  "${archive}" "${github_token_env}" SDL2_GITHUB_TOKEN; then
  echo "Unable to download an sdl2 artifact for ${github_repo}@${release_tag}/${platform}/${arch}" >&2
  exit 1
fi

tar -tzf "${archive}" >/dev/null
tar -xzf "${archive}" -C "${tmp_dir}"
header="$(find "${tmp_dir}" -path '*/include/SDL2/SDL.h' -type f | head -n 1)"
if [ -z "${header}" ]; then
  echo "Unable to find include/SDL2/SDL.h in ${asset_name}" >&2
  exit 1
fi
artifact_root="$(cd "$(dirname "${header}")/../.." && pwd)"

tc_artifact_requirements_present "${artifact_root}" --diagnose \
  "downloaded sdl2 artifact is incomplete" "${requirements[@]}"
if find "${artifact_root}" -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.dylib' -o -name '*.dll' \) | grep -q .; then
  echo "Downloaded sdl2 artifact contains a shared library" >&2
  exit 1
fi
if find "${artifact_root}" -type f -iname '*SDL2main*' | grep -q .; then
  echo "Downloaded sdl2 artifact unexpectedly contains SDL2main" >&2
  exit 1
fi
grep -qx 'name=sdl2' "${artifact_root}/manifest.txt"
grep -qx 'version=2.32.8' "${artifact_root}/manifest.txt"
grep -qx "platform_arch=${platform}/${arch}" "${artifact_root}/manifest.txt"
grep -qx 'static=ON' "${artifact_root}/manifest.txt"
grep -qx 'pic=ON' "${artifact_root}/manifest.txt"
grep -qx 'sdl2main=OFF' "${artifact_root}/manifest.txt"

tc_artifact_replace_tree "${artifact_root}" "${dest}" sdl2 "${github_repo}" \
  "${release_tag}" "${asset_name}" "${TC_GITHUB_RELEASE_DOWNLOADED_SHA256}" \
  "${requirements[@]}"

echo "Installed sdl2 ${github_repo}@${release_tag}/${platform}/${arch} into ${dest}"
