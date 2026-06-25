#!/usr/bin/env bash
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

github_token=""
if [ -n "${github_token_env}" ]; then
  github_token="${!github_token_env:-}"
elif [ -n "${VCRUNTIME_GITHUB_TOKEN:-}" ]; then
  github_token="${VCRUNTIME_GITHUB_TOKEN}"
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

  echo "Downloading vcruntime artifact ${candidate} from ${github_repo}@${release_tag}"

  if github_curl -o "${archive_path}" "${download_url}"; then
    return 0
  fi

  if [ -z "${github_token}" ]; then
    return 1
  fi

  echo "Direct vcruntime artifact download failed; trying GitHub release asset API"

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

asset_name="vcruntime-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"

if ! download_release_asset "${asset_name}" "${archive}"; then
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

dest="${dest_root}/${platform}/${arch}"
rm -rf "${dest}"
mkdir -p "${dest}"
cp -a "${artifact_root}/." "${dest}/"

echo "Installed vcruntime ${platform}/${arch} into ${dest}"
