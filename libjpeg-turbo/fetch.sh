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
  --release-tag TAG        GitHub release tag, default: libjpeg-turbo-3.1.4.1
  --github-repo OWNER/REPO GitHub repository, default: TotalCross/totalcross-depot-tools
  --github-token-env NAME  Environment variable containing a GitHub token,
                           default: LIBJPEG_TURBO_GITHUB_TOKEN, then GITHUB_TOKEN
  --dest DIR               Destination root, default: libjpeg-turbo/local
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

platform=""
arch=""
release_tag="libjpeg-turbo-3.1.4.1"
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

if [ -z "$platform" ] || [ -z "$arch" ]; then
  usage >&2
  exit 2
fi

if [[ ! "${github_repo}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid libjpeg-turbo GitHub repository value. Expected OWNER/REPO." >&2
  exit 2
fi

if [[ "${release_tag}" == *"{"* || "${release_tag}" == *"}"* || "${release_tag}" == *" "* ]]; then
  echo "Invalid libjpeg-turbo release tag value." >&2
  exit 2
fi

case "$platform" in
  linux)
    case "$arch" in
      amd64) arch="x86_64" ;;
      arm64) arch="aarch64" ;;
      arm|armv7) arch="armv7l" ;;
    esac
    ;;
  windows)
    case "$arch" in
      amd64|x86_64) arch="x64" ;;
      i386|i686|Win32|win32) arch="x86" ;;
      ARM64) arch="arm64" ;;
    esac
    ;;
  macos|ios|ios-simulator)
    case "$arch" in
      aarch64) arch="arm64" ;;
      amd64) arch="x86_64" ;;
    esac
    ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

source "${script_dir}/../scripts/github-release.sh"
source "${script_dir}/../scripts/artifact-install.sh"

asset_name="libjpeg-turbo-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"
dest="${dest_root}/${platform}/${arch}"
requirements=(
  'include/jconfig.h'
  'include/jerror.h'
  'include/jmorecfg.h'
  'include/jpeglib.h'
  'include/turbojpeg.h'
  'lib/libjpeg.a|lib/jpeg-static.lib|lib/jpeg.lib|lib/libjpeg.lib'
  'lib/libturbojpeg.a|lib/turbojpeg-static.lib|lib/turbojpeg.lib|lib/libturbojpeg.lib'
)
if tc_artifact_marker_matches "$dest" "libjpeg-turbo" "$github_repo" "$release_tag" "$asset_name" "" "${requirements[@]}"; then
  echo "Reusing libjpeg-turbo ${platform}/${arch} from ${dest}"
  exit 0
fi


if ! tc_github_release_download "${github_repo}" "${release_tag}" "${asset_name}" "${archive}" \
  "${github_token_env}" LIBJPEG_TURBO_GITHUB_TOKEN; then
  echo "Unable to download a libjpeg-turbo artifact for ${platform}/${arch}" >&2
  exit 1
fi

tar -tzf "${archive}" >/dev/null
tar -xzf "${archive}" -C "${tmp_dir}"

include_header="$(find "${tmp_dir}" -path "*/include/jpeglib.h" -type f | head -n 1)"
if [ -z "${include_header}" ]; then
  echo "Unable to find include/jpeglib.h in ${asset_name}" >&2
  exit 1
fi

artifact_root="$(cd "$(dirname "${include_header}")/.." && pwd)"
if ! find "${artifact_root}/lib" -type f \( -name "libjpeg.a" -o -name "jpeg-static.lib" -o -name "jpeg.lib" -o -name "libjpeg.lib" \) | grep -q .; then
  echo "Unable to find libjpeg-turbo JPEG API static library under ${artifact_root}/lib" >&2
  exit 1
fi
if ! find "${artifact_root}/lib" -type f \( -name "libturbojpeg.a" -o -name "turbojpeg-static.lib" -o -name "turbojpeg.lib" -o -name "libturbojpeg.lib" \) | grep -q .; then
  echo "Unable to find libjpeg-turbo TurboJPEG API static library under ${artifact_root}/lib" >&2
  exit 1
fi

for header_name in jconfig.h jerror.h jmorecfg.h jpeglib.h turbojpeg.h; do
  if [ ! -f "${artifact_root}/include/${header_name}" ]; then
    echo "Unable to find include/${header_name} in ${asset_name}" >&2
    exit 1
  fi
done

tc_artifact_replace_tree "${artifact_root}" "$dest" "libjpeg-turbo" "$github_repo" "$release_tag" "$asset_name" \
  "$TC_GITHUB_RELEASE_DOWNLOADED_SHA256" "${requirements[@]}"

echo "Installed libjpeg-turbo ${platform}/${arch} into ${dest}"
