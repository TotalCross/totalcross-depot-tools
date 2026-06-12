#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fetch.sh [options]

Options:
  --platform PLATFORM      Target platform: linux, windows, android, ios, ios-simulator, macos
  --arch ARCH              Target architecture, e.g. x86_64, armv7l, aarch64
  --release-tag TAG        GitHub release tag, default: sqlite3-3.32.3-r2
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
release_tag="sqlite3-3.32.3-r2"
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

github_token=""
if [ -n "${github_token_env}" ]; then
  github_token="${!github_token_env:-}"
elif [ -n "${SQLITE3_GITHUB_TOKEN:-}" ]; then
  github_token="${SQLITE3_GITHUB_TOKEN}"
elif [ -n "${GITHUB_TOKEN:-}" ]; then
  github_token="${GITHUB_TOKEN}"
fi

if [ -n "${github_token}" ]; then
  log "GitHub token: set"
else
  log "GitHub token: missing"
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

find_asset_api_url() {
  local asset_name="$1"
  local release_json="$2"
  local python_bin=""

  if command -v python3 >/dev/null 2>&1; then
    python_bin="python3"
  elif command -v python >/dev/null 2>&1; then
    python_bin="python"
  fi

  if [ -n "${python_bin}" ]; then
    log "Parsing release JSON with ${python_bin}"
    "${python_bin}" - "${asset_name}" "${release_json}" <<'PY'
import json
import sys

asset_name = sys.argv[1]
release_json = sys.argv[2]

with open(release_json, "r") as fh:
    release = json.load(fh)

for asset in release.get("assets", []):
    if asset.get("name") == asset_name and asset.get("url"):
        print(asset["url"])
        sys.exit(0)

sys.exit(1)
PY
    return
  fi

  log "Parsing release JSON with awk fallback"
  awk -v asset_name="${asset_name}" '
    /"assets"[[:space:]]*:/ {
      in_assets = 1
    }
    in_assets && /"url"[[:space:]]*:[[:space:]]*"https:\/\/api.github.com\/repos\/[^"]+\/releases\/assets\// {
      line = $0
      sub(/.*"url"[[:space:]]*:[[:space:]]*"/, "", line)
      sub(/".*/, "", line)
      current_url = line
    }
    in_assets && /"name"[[:space:]]*:/ {
      line = $0
      sub(/.*"name"[[:space:]]*:[[:space:]]*"/, "", line)
      sub(/".*/, "", line)
      if (line == asset_name && current_url != "") {
        print current_url
        exit
      }
    }
  ' "${release_json}"
}

list_sqlite_assets() {
  local release_json="$1"
  grep '"name": "sqlite3-' "${release_json}" >&2 || true
}

download_release_asset() {
  local candidate="$1"
  local archive_path="$2"
  local direct_url="https://github.com/${github_repo}/releases/download/${release_tag}/${candidate}"
  local release_json="${tmp_dir}/release.json"
  local asset_api_url=""

  log "candidate artifact: ${candidate}"
  log "trying direct release download"
  echo "Downloading SQLite3 artifact ${candidate} from ${github_repo}@${release_tag}"

  if github_curl -o "${archive_path}" "${direct_url}"; then
    log "direct release download succeeded"
    return 0
  fi

  log "direct release download failed"
  echo "Direct SQLite3 artifact download failed; trying GitHub release asset API"

  log "fetching release metadata through GitHub API"
  if ! github_curl \
    -o "${release_json}" \
    "https://api.github.com/repos/${github_repo}/releases/tags/${release_tag}"; then
    log "failed to fetch release metadata"
    return 1
  fi

  log "release metadata downloaded"
  log "SQLite3 assets visible in release metadata:"
  list_sqlite_assets "${release_json}" || true

  asset_api_url="$(find_asset_api_url "${candidate}" "${release_json}")"
  if [ -z "${asset_api_url}" ]; then
    echo "Unable to find SQLite3 release asset named ${candidate}" >&2
    echo "SQLite3 assets listed by the release API:" >&2
    list_sqlite_assets "${release_json}"
    return 1
  fi

  log "found asset API URL for candidate"
  log "downloading asset through GitHub asset API"
  if ! github_curl \
    -H "Accept: application/octet-stream" \
    -o "${archive_path}" \
    "${asset_api_url}"; then
    log "GitHub asset API download failed"
    return 1
  fi
  log "GitHub asset API download completed"
}

asset_name="sqlite3-${platform}-${arch}.tar.gz"
archive="${tmp_dir}/${asset_name}"

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

dest="${dest_root}/${install_namespace}/${platform}/${arch}"
log "installing artifact into ${dest}"
rm -rf "${dest}"
mkdir -p "${dest}"
cp -a "${artifact_root}/." "${dest}/"

echo "Installed SQLite3 ${github_repo}@${release_tag}/${platform}/${arch} into ${dest}"
log "done"
