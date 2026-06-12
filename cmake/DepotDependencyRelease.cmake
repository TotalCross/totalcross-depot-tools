# Copyright (C) 2026 Amalgam Solucoes em TI Ltda
#
# SPDX-License-Identifier: LGPL-2.1-only

get_filename_component(TCVM_DEPOT_RELEASE_HELPER_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_DEPOT_RELEASE_ROOT "${TCVM_DEPOT_RELEASE_HELPER_DIR}/.." ABSOLUTE)

function(tcvm_get_dependency_release dependency_name out_var fallback_release)
  set(TCVM_DEPOT_RELEASE_VALUE "")
  set(TCVM_DEPOT_DEPS_FILE "${TCVM_DEPOT_RELEASE_ROOT}/deps.yml")

  if(EXISTS "${TCVM_DEPOT_DEPS_FILE}")
    file(STRINGS "${TCVM_DEPOT_DEPS_FILE}" TCVM_DEPOT_DEPS_LINES)
    set(TCVM_DEPOT_IN_DEPENDENCY OFF)

    foreach(TCVM_DEPOT_DEPS_LINE IN LISTS TCVM_DEPOT_DEPS_LINES)
      if(TCVM_DEPOT_DEPS_LINE MATCHES "^  ${dependency_name}:[ ]*$")
        set(TCVM_DEPOT_IN_DEPENDENCY ON)
      elseif(TCVM_DEPOT_IN_DEPENDENCY AND TCVM_DEPOT_DEPS_LINE MATCHES "^  [A-Za-z0-9_.-]+:[ ]*$")
        set(TCVM_DEPOT_IN_DEPENDENCY OFF)
      elseif(TCVM_DEPOT_IN_DEPENDENCY AND TCVM_DEPOT_DEPS_LINE MATCHES "^    release:[ ]*([^ ]+)[ ]*$")
        set(TCVM_DEPOT_RELEASE_VALUE "${CMAKE_MATCH_1}")
        break()
      endif()
    endforeach()
  endif()

  if(NOT TCVM_DEPOT_RELEASE_VALUE)
    set(TCVM_DEPOT_RELEASE_VALUE "${fallback_release}")
  endif()

  set("${out_var}" "${TCVM_DEPOT_RELEASE_VALUE}" PARENT_SCOPE)
endfunction()
