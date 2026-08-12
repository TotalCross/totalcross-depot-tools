#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

TC_ARTIFACT_MARKER_NAME='.totalcross-artifact.json'

tc_artifact_log() {
  printf '[artifact-install] %s\n' "$*" >&2
}

tc_artifact_requirements_present() {
  local root="$1"
  shift
  local requirement
  local alternative
  local found
  local old_ifs
  for requirement in "$@"; do
    found=0
    old_ifs="$IFS"
    IFS='|'
    for alternative in $requirement; do
      IFS="$old_ifs"
      if compgen -G "${root}/${alternative}" >/dev/null 2>&1; then
        found=1
        break
      fi
      IFS='|'
    done
    IFS="$old_ifs"
    if [ "$found" -ne 1 ]; then
      return 1
    fi
  done
}

tc_artifact_marker_matches() {
  local destination="$1"
  local dependency="$2"
  local repository="$3"
  local release_tag="$4"
  local asset_name="$5"
  local expected_sha256="${6:-}"
  shift 6
  local marker="${destination}/${TC_ARTIFACT_MARKER_NAME}"
  local python_bin=''

  [ "${TOTALCROSS_DEPOT_FORCE_REFETCH:-0}" != 1 ] || return 1
  [ -d "$destination" ] && [ -s "$marker" ] || return 1
  tc_artifact_requirements_present "$destination" "$@" || return 1

  if command -v python3 >/dev/null 2>&1; then
    python_bin='python3'
  elif command -v python >/dev/null 2>&1; then
    python_bin='python'
  else
    tc_artifact_log 'error: python3 or python is required to read artifact markers'
    return 1
  fi

  "$python_bin" - "$marker" "$dependency" "$repository" "$release_tag" "$asset_name" "$expected_sha256" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r") as handle:
        marker = json.load(handle)
except (IOError, ValueError):
    raise SystemExit(1)

expected = {
    "schema": 1,
    "dependency": sys.argv[2],
    "repository": sys.argv[3],
    "release_tag": sys.argv[4],
    "asset": sys.argv[5],
}
if any(marker.get(key) != value for key, value in expected.items()):
    raise SystemExit(1)
digest = marker.get("sha256", "")
if not isinstance(digest, str) or len(digest) != 64:
    raise SystemExit(1)
if sys.argv[6] and digest != sys.argv[6]:
    raise SystemExit(1)
PY
}

tc_artifact_write_marker() {
  local destination="$1"
  local dependency="$2"
  local repository="$3"
  local release_tag="$4"
  local asset_name="$5"
  local sha256="$6"
  local marker="${destination}/${TC_ARTIFACT_MARKER_NAME}"
  local python_bin=''

  if command -v python3 >/dev/null 2>&1; then
    python_bin='python3'
  elif command -v python >/dev/null 2>&1; then
    python_bin='python'
  else
    tc_artifact_log 'error: python3 or python is required to write artifact markers'
    return 1
  fi

  "$python_bin" - "$marker" "$dependency" "$repository" "$release_tag" "$asset_name" "$sha256" <<'PY'
import json
import sys

payload = {
    "schema": 1,
    "dependency": sys.argv[2],
    "repository": sys.argv[3],
    "release_tag": sys.argv[4],
    "asset": sys.argv[5],
    "sha256": sys.argv[6],
}
with open(sys.argv[1], "w") as handle:
    json.dump(payload, handle, sort_keys=True, separators=(",", ":"))
    handle.write("\n")
PY
}

tc_artifact_replace_tree() {
  local source_root="$1"
  local destination="$2"
  local dependency="$3"
  local repository="$4"
  local release_tag="$5"
  local asset_name="$6"
  local sha256="$7"
  shift 7
  local parent
  local base
  local staging
  local backup
  local had_existing=0

  parent="$(dirname "$destination")"
  base="$(basename "$destination")"
  mkdir -p "$parent"
  staging="$(mktemp -d "${parent}/.${base}.staging.XXXXXX")"
  backup="${parent}/.${base}.backup.$$"
  cp -a "${source_root}/." "${staging}/"
  tc_artifact_requirements_present "$staging" "$@" || {
    tc_artifact_log "error: staged ${dependency} artifact is incomplete"
    rm -rf "$staging"
    return 1
  }
  tc_artifact_write_marker "$staging" "$dependency" "$repository" "$release_tag" "$asset_name" "$sha256" || {
    rm -rf "$staging"
    return 1
  }

  if [ -e "$destination" ]; then
    mv "$destination" "$backup" || {
      rm -rf "$staging"
      return 1
    }
    had_existing=1
  fi
  if mv "$staging" "$destination"; then
    if [ "$had_existing" -eq 1 ]; then
      rm -rf "$backup"
    fi
    return 0
  fi

  tc_artifact_log "error: failed to replace ${destination}; restoring previous installation"
  rm -rf "$staging"
  if [ "$had_existing" -eq 1 ]; then
    mv "$backup" "$destination"
  fi
  return 1
}
