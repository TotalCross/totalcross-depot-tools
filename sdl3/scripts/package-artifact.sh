#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <build-dir> <install-dir> <platform>/<arch>" >&2
  exit 2
fi
# TC_DEPOT_SCAFFOLD_TODO: stage include/lib/manifest.txt and create declared archive.
exit 2
