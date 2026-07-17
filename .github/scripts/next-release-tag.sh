#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: next-release-tag.sh DEP VERSION" >&2
  exit 2
fi

dep="$1"
version="$2"
base_tag="${dep}-${version}"
base_tag_regex="$(printf '%s' "${base_tag}" | sed 's/[][(){}.^$*+?|\\]/\\&/g')"

tags="$(
  git ls-remote --tags origin "refs/tags/${base_tag}*" |
    awk '{print $2}' |
    sed 's#refs/tags/##; s#\\^{}##' |
    sort -u
)"

highest_revision=0

while IFS= read -r tag; do
  [ -n "${tag}" ] || continue
  if [ "${tag}" = "${base_tag}" ]; then
    if [ "${highest_revision}" -lt 1 ]; then
      highest_revision=1
    fi
  elif [[ "${tag}" =~ ^${base_tag_regex}-r([0-9]+)$ ]]; then
    revision="${BASH_REMATCH[1]}"
    if [ "${revision}" -gt "${highest_revision}" ]; then
      highest_revision="${revision}"
    fi
  fi
done <<< "${tags}"

if [ "${highest_revision}" -eq 0 ]; then
  echo "${base_tag}"
else
  echo "${base_tag}-r$((highest_revision + 1))"
fi
