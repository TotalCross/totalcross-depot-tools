#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

# Shared GitHub Release transport for dependency fetchers. Callers remain
# responsible for validating and installing the downloaded artifact.

tc_github_release_log() {
  printf '[github-release] %s\n' "$*" >&2
}

tc_github_release_sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$path" | awk '{print $NF}'
  else
    tc_github_release_log 'error: sha256sum, shasum, or openssl is required'
    return 1
  fi
}

tc_github_release_sha256_text() {
  local value="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "$value" | openssl dgst -sha256 | awk '{print $NF}'
  else
    tc_github_release_log 'error: sha256sum, shasum, or openssl is required'
    return 1
  fi
}

tc_github_release_token() {
  local explicit_env="${1:-}"
  local default_env="${2:-}"
  local value=''

  if [ -n "$explicit_env" ]; then
    if ! [[ "$explicit_env" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      tc_github_release_log "error: invalid token environment variable name: ${explicit_env}"
      return 2
    fi
    value="${!explicit_env:-}"
  fi
  if [ -z "$value" ] && [ -n "$default_env" ]; then
    if ! [[ "$default_env" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      tc_github_release_log "error: invalid token environment variable name: ${default_env}"
      return 2
    fi
    value="${!default_env:-}"
  fi
  if [ -z "$value" ]; then
    value="${GITHUB_TOKEN:-}"
  fi
  printf '%s' "$value"
}

tc_github_release_should_retry() {
  local curl_exit="$1"
  local http_status="$2"

  case "$http_status" in
    408|429|5??|000|'') return 0 ;;
  esac
  [ "$curl_exit" -ne 22 ]
}

tc_github_release_curl() {
  local token="$1"
  shift
  local curl_bin="${TOTALCROSS_DEPOT_CURL:-curl}"
  local args=(--silent --show-error --location --globoff --http1.1)
  if [ -n "$token" ]; then
    args+=(
      -H "Authorization: Bearer ${token}"
      -H 'X-GitHub-Api-Version: 2022-11-28'
    )
  fi
  "$curl_bin" "${args[@]}" "$@"
}

tc_github_release_download_url() {
  local url="$1"
  local destination="$2"
  local label="$3"
  local token="$4"
  shift 4
  local attempts="${TOTALCROSS_DEPOT_FETCH_ATTEMPTS:-4}"
  local delay="${TOTALCROSS_DEPOT_FETCH_RETRY_DELAY:-2}"
  local attempt=1
  local status='000'
  local curl_exit=0
  local partial="${destination}.part.$$"

  case "$attempts" in
    ''|*[!0-9]*|0) tc_github_release_log 'error: TOTALCROSS_DEPOT_FETCH_ATTEMPTS must be a positive integer'; return 2 ;;
  esac
  case "$delay" in
    ''|*[!0-9]*) tc_github_release_log 'error: TOTALCROSS_DEPOT_FETCH_RETRY_DELAY must be a non-negative integer'; return 2 ;;
  esac

  rm -f "$partial"
  while [ "$attempt" -le "$attempts" ]; do
    status='000'
    if status="$(tc_github_release_curl "$token" "$@" -w '%{http_code}' -o "$partial" "$url")"; then
      mv -f "$partial" "$destination"
      return 0
    else
      curl_exit=$?
    fi
    rm -f "$partial"
    status="${status:-000}"
    if [ "$attempt" -ge "$attempts" ] || ! tc_github_release_should_retry "$curl_exit" "$status"; then
      tc_github_release_log "download failed: ${label} (attempt ${attempt}/${attempts}, curl exit ${curl_exit}, http ${status})"
      TC_GITHUB_RELEASE_LAST_HTTP_STATUS="$status"
      TC_GITHUB_RELEASE_LAST_CURL_EXIT="$curl_exit"
      export TC_GITHUB_RELEASE_LAST_HTTP_STATUS TC_GITHUB_RELEASE_LAST_CURL_EXIT
      return 1
    fi
    tc_github_release_log "transient failure: ${label} (attempt ${attempt}/${attempts}, curl exit ${curl_exit}, http ${status}); retrying in ${delay}s"
    if [ "$delay" -gt 0 ]; then
      sleep "$delay"
    fi
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
  return 1
}

tc_github_release_cache_dir() {
  if [ -n "${TOTALCROSS_DEPOT_FETCH_CACHE_DIR:-}" ]; then
    printf '%s' "$TOTALCROSS_DEPOT_FETCH_CACHE_DIR"
    return 0
  fi
  if [ -z "${TC_GITHUB_RELEASE_PROCESS_CACHE_DIR:-}" ]; then
    TC_GITHUB_RELEASE_PROCESS_CACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/totalcross-depot-fetch.XXXXXX")"
  fi
  printf '%s' "$TC_GITHUB_RELEASE_PROCESS_CACHE_DIR"
}

tc_github_release_metadata_paths() {
  local repo="$1"
  local tag="$2"
  local cache_dir
  local cache_key
  cache_dir="$(tc_github_release_cache_dir)"
  cache_key="$(tc_github_release_sha256_text "${repo}\n${tag}")"
  mkdir -p "$cache_dir"
  printf '%s\n%s\n' "${cache_dir}/${cache_key}.json" "${cache_dir}/${cache_key}.api-only"
}

tc_github_release_metadata() {
  local repo="$1"
  local tag="$2"
  local token="$3"
  local metadata_path
  local api_only_path
  local metadata_tmp
  local paths
  paths="$(tc_github_release_metadata_paths "$repo" "$tag")"
  metadata_path="$(printf '%s\n' "$paths" | sed -n '1p')"
  api_only_path="$(printf '%s\n' "$paths" | sed -n '2p')"

  if [ ! -s "$metadata_path" ]; then
    metadata_tmp="${metadata_path}.part.$$"
    rm -f "$metadata_tmp"
    if ! tc_github_release_download_url \
      "${TOTALCROSS_GITHUB_API_BASE_URL:-https://api.github.com}/repos/${repo}/releases/tags/${tag}" \
      "$metadata_tmp" "release metadata for ${repo}@${tag}" "$token"; then
      rm -f "$metadata_tmp"
      return 1
    fi
    mv -f "$metadata_tmp" "$metadata_path"
  fi
  printf '%s\n%s\n' "$metadata_path" "$api_only_path"
}

tc_github_release_asset_info() {
  local metadata_path="$1"
  local asset_name="$2"
  local python_bin=''
  if command -v python3 >/dev/null 2>&1; then
    python_bin='python3'
  elif command -v python >/dev/null 2>&1; then
    python_bin='python'
  fi

  if [ -n "$python_bin" ]; then
    "$python_bin" - "$metadata_path" "$asset_name" <<'PY'
import json
import sys

with open(sys.argv[1], "r") as handle:
    release = json.load(handle)
for asset in release.get("assets", []):
    if asset.get("name") == sys.argv[2] and asset.get("url"):
        print(asset["url"])
        digest = asset.get("digest") or ""
        print(digest[7:] if digest.startswith("sha256:") else "")
        raise SystemExit(0)
raise SystemExit(1)
PY
    return
  fi

  awk -v asset_name="$asset_name" '
    /"assets"[[:space:]]*:/ { in_assets = 1 }
    in_assets && /"url"[[:space:]]*:/ {
      line = $0; sub(/.*"url"[[:space:]]*:[[:space:]]*"/, "", line); sub(/".*/, "", line); url = line
    }
    in_assets && /"name"[[:space:]]*:/ {
      line = $0; sub(/.*"name"[[:space:]]*:[[:space:]]*"/, "", line); sub(/".*/, "", line); name = line
    }
    in_assets && /"digest"[[:space:]]*:/ {
      line = $0; sub(/.*"digest"[[:space:]]*:[[:space:]]*"sha256:/, "", line); sub(/".*/, "", line); digest = line
    }
    name == asset_name && url != "" && /[},][[:space:]]*$/ { print url; print digest; exit }
  ' "$metadata_path"
}

tc_github_release_download() {
  local repo="$1"
  local tag="$2"
  local asset="$3"
  local destination="$4"
  local explicit_token_env="${5:-}"
  local default_token_env="${6:-}"
  local token
  local direct_url
  local metadata_path
  local api_only_path
  local asset_info
  local asset_api_url
  local asset_digest
  local paths

  token="$(tc_github_release_token "$explicit_token_env" "$default_token_env")" || return
  paths="$(tc_github_release_metadata_paths "$repo" "$tag")" || return
  metadata_path="$(printf '%s\n' "$paths" | sed -n '1p')"
  api_only_path="$(printf '%s\n' "$paths" | sed -n '2p')"
  direct_url="${TOTALCROSS_GITHUB_WEB_BASE_URL:-https://github.com}/${repo}/releases/download/${tag}/${asset}"

  if [ ! -f "$api_only_path" ]; then
    tc_github_release_log "downloading ${repo}@${tag}/${asset}"
    if tc_github_release_download_url "$direct_url" "$destination" "${repo}@${tag}/${asset}" "$token"; then
      TC_GITHUB_RELEASE_DOWNLOADED_SHA256="$(tc_github_release_sha256_file "$destination")" || return
      export TC_GITHUB_RELEASE_DOWNLOADED_SHA256
      return 0
    fi
    tc_github_release_log "using GitHub asset API fallback for ${repo}@${tag}/${asset}"
  else
    tc_github_release_log "reusing API-only release routing for ${repo}@${tag}/${asset}"
  fi

  paths="$(tc_github_release_metadata "$repo" "$tag" "$token")" || return
  metadata_path="$(printf '%s\n' "$paths" | sed -n '1p')"
  api_only_path="$(printf '%s\n' "$paths" | sed -n '2p')"
  asset_info="$(tc_github_release_asset_info "$metadata_path" "$asset")" || {
    tc_github_release_log "error: release ${repo}@${tag} has no asset named ${asset}"
    return 1
  }
  asset_api_url="$(printf '%s\n' "$asset_info" | sed -n '1p')"
  asset_digest="$(printf '%s\n' "$asset_info" | sed -n '2p')"
  if ! tc_github_release_download_url "$asset_api_url" "$destination" "asset API ${repo}@${tag}/${asset}" "$token" -H 'Accept: application/octet-stream'; then
    return 1
  fi
  : > "$api_only_path"
  TC_GITHUB_RELEASE_DOWNLOADED_SHA256="$(tc_github_release_sha256_file "$destination")" || return
  TC_GITHUB_RELEASE_API_SHA256="$asset_digest"
  export TC_GITHUB_RELEASE_DOWNLOADED_SHA256 TC_GITHUB_RELEASE_API_SHA256
}
