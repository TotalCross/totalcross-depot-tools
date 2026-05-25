#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${1:-${ROOT_DIR}/install}"
OUT_DIR="${2:-${ROOT_DIR}/dist}"
VERSION="${MBEDTLS_VERSION:-3.5.2}"

mkdir -p "${OUT_DIR}"
tar -C "${INSTALL_DIR}" -czf "${OUT_DIR}/mbedtls-${VERSION}.tar.gz" .

