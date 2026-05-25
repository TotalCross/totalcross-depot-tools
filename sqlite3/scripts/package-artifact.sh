#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${1:-${ROOT_DIR}/install}"
OUT_DIR="${2:-${ROOT_DIR}/dist}"
VERSION="${SQLITE3_VERSION:-3.32.3}"

mkdir -p "${OUT_DIR}"
tar -C "${INSTALL_DIR}" -czf "${OUT_DIR}/sqlite3-${VERSION}.tar.gz" .

