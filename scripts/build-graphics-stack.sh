#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

operation="${1:-build}"
if [ "$#" -gt 1 ]; then
  echo "Usage: scripts/build-graphics-stack.sh [build|release|force-release]" >&2
  exit 2
fi
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/native-stack.py" graphics "${operation}"
