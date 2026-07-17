#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") DEPENDENCY" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
dependency="$1"

release=$(awk -v dependency="$dependency" '
  $0 == "  " dependency ":" { in_dependency = 1; next }
  in_dependency && /^  [^[:space:]][^:]*:$/ { exit }
  in_dependency && /^    release:[[:space:]]*/ { print $2; exit }
' "$ROOT_DIR/deps.yml")

if [[ -z "$release" ]]; then
  echo "error: deps.yml has no release pin for dependency '$dependency'" >&2
  exit 1
fi

printf '%s\n' "$release"
