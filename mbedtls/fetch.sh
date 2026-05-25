#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
SRC_DIR="${ROOT_DIR}/src"
URL="${MBEDTLS_URL:-https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v3.5.2.tar.gz}"
ARCHIVE="${BUILD_DIR}/mbedtls-3.5.2.tar.gz"

mkdir -p "${BUILD_DIR}" "${SRC_DIR}"

if [ ! -f "${ARCHIVE}" ]; then
  curl -L "${URL}" -o "${ARCHIVE}"
fi

rm -rf "${SRC_DIR}/mbedtls-3.5.2"
tar -xzf "${ARCHIVE}" -C "${SRC_DIR}"

