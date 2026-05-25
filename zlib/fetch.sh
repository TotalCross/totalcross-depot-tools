#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
SRC_DIR="${ROOT_DIR}/src"
URL="${ZLIB_URL:-https://zlib.net/fossils/zlib-1.3.1.tar.gz}"
ARCHIVE="${BUILD_DIR}/zlib-1.3.1.tar.gz"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}"

if [ ! -f "${ARCHIVE}" ]; then
  curl -L "${URL}" -o "${ARCHIVE}"
fi

rm -rf "${SRC_DIR}/zlib-1.3.1"
tar -xzf "${ARCHIVE}" -C "${SRC_DIR}"

