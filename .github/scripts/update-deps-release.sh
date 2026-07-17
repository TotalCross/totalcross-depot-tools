#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") DEPENDENCY RELEASE_TAG" >&2
  exit 2
fi

dependency="$1"
release_tag="$2"
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
deps_file=$(cd "$script_dir/../.." && pwd)/deps.yml

ruby -e '
  dependency, release_tag, path = ARGV
  lines = File.readlines(path)
  start = lines.index { |line| line == "  #{dependency}:\n" }
  abort("dependency #{dependency.inspect} was not found in #{path}") unless start
  finish = ((start + 1)...lines.length).find { |index| lines[index] =~ /^  \S.*:$/ } || lines.length
  release_line = ((start + 1)...finish).find { |index| lines[index] =~ /^    release:\s*/ }
  abort("dependency #{dependency.inspect} has no release pin in #{path}") unless release_line
  lines[release_line] = "    release: #{release_tag}\n"
  File.write(path, lines.join)
' "$dependency" "$release_tag" "$deps_file"
