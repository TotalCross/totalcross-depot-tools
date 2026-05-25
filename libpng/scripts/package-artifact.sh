#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${1:-${ROOT_DIR}/install}"
OUT_DIR="${2:-${ROOT_DIR}/dist}"
VERSION="${LIBPNG_VERSION:-1.6.43}"

mkdir -p "${OUT_DIR}"
tar -C "${INSTALL_DIR}" -czf "${OUT_DIR}/libpng-${VERSION}.tar.gz" .

