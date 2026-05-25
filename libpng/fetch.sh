#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
SRC_DIR="${ROOT_DIR}/src"
URL="${LIBPNG_URL:-https://download.sourceforge.net/libpng/libpng-1.6.43.tar.gz}"
ARCHIVE="${BUILD_DIR}/libpng-1.6.43.tar.gz"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}"

if [ ! -f "${ARCHIVE}" ]; then
  curl -L "${URL}" -o "${ARCHIVE}"
fi

rm -rf "${SRC_DIR}/libpng-1.6.43"
tar -xzf "${ARCHIVE}" -C "${SRC_DIR}"

