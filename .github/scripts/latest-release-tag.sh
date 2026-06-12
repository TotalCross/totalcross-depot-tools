#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: latest-release-tag.sh DEP VERSION" >&2
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

latest_revision=0
latest_tag=""

while IFS= read -r tag; do
  [ -n "${tag}" ] || continue
  if [ "${tag}" = "${base_tag}" ]; then
    if [ "${latest_revision}" -lt 1 ]; then
      latest_revision=1
      latest_tag="${base_tag}"
    fi
  elif [[ "${tag}" =~ ^${base_tag_regex}-r([0-9]+)$ ]]; then
    revision="${BASH_REMATCH[1]}"
    if [ "${revision}" -gt "${latest_revision}" ]; then
      latest_revision="${revision}"
      latest_tag="${tag}"
    fi
  fi
done <<< "${tags}"

if [ -n "${latest_tag}" ]; then
  echo "${latest_tag}"
else
  echo "${base_tag}"
fi
