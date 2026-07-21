#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/fetch-native-dependencies.sh LIBRARY TARGET [--dry-run]

Fetch the repository-pinned artifacts required to build one native target.
EOF
}

if [ "$#" -lt 2 ]; then
  usage >&2
  exit 2
fi

library="$1"
target="$2"
shift 2
dry_run='false'

if [ "$#" -gt 0 ]; then
  if [ "$1" != '--dry-run' ] || [ "$#" -ne 1 ]; then
    usage >&2
    exit 2
  fi
  dry_run='true'
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

platform=''
arch=''
dependencies='{}'
while IFS='=' read -r key value; do
  key="${key%$'\r'}"
  value="${value%$'\r'}"
  case "${key}" in
    platform|arch) printf -v "${key}" '%s' "${value}" ;;
    dependencies) dependencies="${value}" ;;
  esac
done < <(python3 scripts/native-build.py show "${library}" "${target}" --format github-output)

dependency_names=()
while IFS= read -r dependency_name; do
  dependency_name="${dependency_name%$'\r'}"
  [ -n "${dependency_name}" ] || continue
  dependency_names+=("${dependency_name}")
done < <(python3 - "${dependencies}" <<'PY'
import json
import sys

print("\n".join(sorted(json.loads(sys.argv[1]))))
PY
)

if [ "${#dependency_names[@]}" -eq 0 ]; then
  echo "native dependencies: ${library}/${target}: none"
  exit 0
fi

for dependency in "${dependency_names[@]}"; do
  fetch_script="${dependency}/fetch.sh"
  if [ ! -x "${fetch_script}" ]; then
    echo "fetch-native-dependencies: ${dependency} does not provide executable ${fetch_script}" >&2
    exit 2
  fi
  release_tag="$(.github/scripts/read-deps-release.sh "${dependency}")"
  command=(bash "${fetch_script}" --platform "${platform}" --arch "${arch}" --release-tag "${release_tag}")
  if [ "${dry_run}" = true ]; then
    printf '%q ' "${command[@]}"
    printf '\n'
  else
    "${command[@]}"
  fi
done
