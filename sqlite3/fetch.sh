#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
SRC_DIR="${ROOT_DIR}/src"
URL="${SQLITE3_URL:-https://www.sqlite.org/2020/sqlite-amalgamation-3320300.zip}"
ARCHIVE="${BUILD_DIR}/sqlite-amalgamation-3320300.zip"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}"

if [ ! -f "${ARCHIVE}" ]; then
  curl -L "${URL}" -o "${ARCHIVE}"
fi

rm -rf "${SRC_DIR}/sqlite-amalgamation-3320300"
unzip -q "${ARCHIVE}" -d "${SRC_DIR}"

