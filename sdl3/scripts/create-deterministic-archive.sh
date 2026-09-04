#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 ROOT TREE OUTPUT" >&2
  exit 2
fi

root="$1"
tree="$2"
output="$3"
tree_root="${root}/${tree}"

if [ ! -d "${tree_root}" ]; then
  echo "Artifact tree does not exist: ${tree_root}" >&2
  exit 1
fi
for tool in find sort tar gzip touch; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Unable to create deterministic archive: ${tool} is required" >&2
    exit 1
  fi
done

list_file="$(mktemp)"
trap 'rm -f "${list_file}"' EXIT
(
  cd "${root}"
  find "${tree}" \( -type f -o -type l \) -print | LC_ALL=C sort > "${list_file}"
)
if [ ! -s "${list_file}" ]; then
  echo "Artifact tree contains no files: ${tree_root}" >&2
  exit 1
fi

# Archives contain files rather than explicit directory entries. Extractors
# recreate the directory tree, while file mtimes and gzip headers remain stable.
find "${tree_root}" -type f -exec touch -t 200001010000 {} +

if tar --version 2>/dev/null | grep -q 'GNU tar'; then
  tar -C "${root}" --format=ustar --owner=0 --group=0 --numeric-owner \
    --mtime='2000-01-01 00:00:00 UTC' -cf - -T "${list_file}" |
    gzip -n > "${output}"
else
  COPYFILE_DISABLE=1 tar -C "${root}" --format ustar -cf - -T "${list_file}" |
    gzip -n > "${output}"
fi
