#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
SRC_DIR="${ROOT_DIR}/src"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}"

if [ -n "${SQLITE_SEE_ARCHIVE:-}" ]; then
  ARCHIVE="${SQLITE_SEE_ARCHIVE}"
elif [ -n "${SQLITE_SEE_URL:-}" ]; then
  ARCHIVE="${BUILD_DIR}/sqlite-see.zip"
  curl -L "${SQLITE_SEE_URL}" -o "${ARCHIVE}"
else
  echo "Set SQLITE_SEE_ARCHIVE or SQLITE_SEE_URL to fetch SQLite SEE sources." >&2
  exit 1
fi

rm -rf "${SRC_DIR}/see"
mkdir -p "${SRC_DIR}/see"
unzip -q "${ARCHIVE}" -d "${SRC_DIR}/see"

