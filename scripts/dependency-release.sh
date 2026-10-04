#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

tc_dependency_release_from_deps() {
  local deps_file="${1:?deps.yml path is required}"
  local dependency="${2:?dependency name is required}"

  [ -f "${deps_file}" ] || return 1

  awk -v dependency="${dependency}" '
    $0 == "  " dependency ":" { found = 1; next }
    found && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { found = 0 }
    found && /^    release:[[:space:]]*/ {
      sub(/^    release:[[:space:]]*/, "")
      print
      exit
    }
  ' "${deps_file}"
}
