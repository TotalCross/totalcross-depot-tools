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
  --release-tag TAG        GitHub release tag, default: minizip-1.3.1
  --github-repo OWNER/REPO GitHub repository, default: TotalCross/totalcross-depot-tools
  --github-token-env NAME  Environment variable containing a GitHub token,
                           default: MINIZIP_GITHUB_TOKEN, then GITHUB_TOKEN
  --dest DIR               Destination root, default: minizip/local
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

platform=""
arch=""
release_tag="minizip-1.3.1"
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
  echo "Invalid minizip GitHub repository value. Expected OWNER/REPO." >&2
  exit 2
fi

if [[ "${release_tag}" == *"{"* || "${release_tag}" == *"}"* || "${release_tag}" == *" "* ]]; then
  echo "Invalid minizip release tag value." >&2
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
      i386|i686) arch="x86" ;;
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

github_token=""
if [ -n "${github_token_env}" ]; then
  github_token="${!github_token_env:-}"
elif [ -n "${MINIZIP_GITHUB_TOKEN:-}" ]; then
  github_token="${MINIZIP_GITHUB_TOKEN}"
elif [ -n "${GITHUB_TOKEN:-}" ]; then
  github_token="${GITHUB_TOKEN}"
fi

github_curl() {
  if [ -n "${github_token}" ]; then
    curl -fsSL \
      --globoff \
      --http1.1 \
      --retry 3 \
      --retry-delay 2 \
      -H "Authorization: Bearer ${github_token}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$@"
  else
    curl -fsSL \
      --globoff \
      --http1.1 \
      --retry 3 \
      --retry-delay 2 \
      "$@"
  fi
}

download_release_asset() {
  local candidate="$1"
  local archive_path="$2"
  local download_url="https://github.com/${github_repo}/releases/download/${release_tag}/${candidate}"

  echo "Downloading minizip artifact ${candidate} from ${github_repo}@${release_tag}"

  if github_curl -o "${archive_path}" "${download_url}"; then
    return 0
  fi

  if [ -z "${github_token}" ]; then
    return 1
  fi

  echo "Direct minizip artifact download failed; trying GitHub release asset API"

  local release_json="${tmp_dir}/release.json"
  local asset_id=""
  if ! github_curl \
    -o "${release_json}" \
    "https://api.github.com/repos/${github_repo}/releases/tags/${release_tag}"; then
    return 1
  fi

  asset_id="$(
    awk -v asset_name="${candidate}" '
      /"assets"[[:space:]]*:/ {
        in_assets = 1
      }
      in_assets && /"url"[[:space:]]*:[[:space:]]*"https:\/\/api.github.com\/repos\/[^"]+\/releases\/assets\// {
        line = $0
        sub(/.*\/releases\/assets\//, "", line)
        sub(/".*/, "", line)
        current_id = line
      }
      in_assets && /"name"[[:space:]]*:/ {
        line = $0
        sub(/.*"name"[[:space:]]*:[[:space:]]*"/, "", line)
        sub(/".*/, "", line)
        if (line == asset_name && current_id != "") {
          print current_id
          exit
        }
      }
    ' "${release_json}"
  )"

  if [ -z "${asset_id}" ]; then
    return 1
  fi

  github_curl \
    -H "Accept: application/octet-stream" \
    -o "${archive_path}" \
    "https://api.github.com/repos/${github_repo}/releases/assets/${asset_id}"
}

asset_name="minizip-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"

if ! download_release_asset "${asset_name}" "${archive}"; then
  echo "Unable to download a minizip artifact for ${platform}/${arch}" >&2
  exit 1
fi

tar -tzf "${archive}" >/dev/null
tar -xzf "${archive}" -C "${tmp_dir}"

include_header="$(find "${tmp_dir}" -path "*/include/zip.h" -type f | head -n 1)"
if [ -z "${include_header}" ]; then
  echo "Unable to find include/zip.h in ${asset_name}" >&2
  exit 1
fi

artifact_root="$(cd "$(dirname "${include_header}")/.." && pwd)"
if ! find "${artifact_root}/lib" -type f \( -name "libminizip*.a" -o -name "minizip*.a" -o -name "minizip*.lib" -o -name "libminizip*.lib" \) | grep -q .; then
  echo "Unable to find minizip static library under ${artifact_root}/lib" >&2
  exit 1
fi

for header_name in crypt.h ioapi.h unzip.h zip.h; do
  if [ ! -f "${artifact_root}/include/${header_name}" ]; then
    echo "Unable to find include/${header_name} in ${asset_name}" >&2
    exit 1
  fi
done

dest="${dest_root}/${platform}/${arch}"
rm -rf "${dest}"
mkdir -p "${dest}"
cp -a "${artifact_root}/." "${dest}/"

echo "Installed minizip ${platform}/${arch} into ${dest}"
