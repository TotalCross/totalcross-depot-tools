# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
get_filename_component(TC_SLJIT_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TC_SLJIT_DEPENDENCY_DIR "${TC_SLJIT_AUTOFETCH_DIR}/.." ABSOLUTE)

function(tcvm_auto_fetch_sljit)
  if(NOT DEFINED SLJIT_RELEASE_TAG)
    set(SLJIT_RELEASE_TAG "sljit-20260717")
  endif()
  if(NOT DEFINED SLJIT_GITHUB_REPO)
    set(SLJIT_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()
  include("${TC_SLJIT_DEPENDENCY_DIR}/cmake/FindSLJIT.cmake")
  if(SLJIT_FOUND)
    return()
  endif()
  find_program(TC_SLJIT_BASH bash REQUIRED)
  execute_process(
    COMMAND "${TC_SLJIT_BASH}" "${TC_SLJIT_DEPENDENCY_DIR}/fetch.sh"
      --platform "${SLJIT_PLATFORM}" --arch "${SLJIT_ARCH}"
      --release-tag "${SLJIT_RELEASE_TAG}" --github-repo "${SLJIT_GITHUB_REPO}"
    WORKING_DIRECTORY "${TC_SLJIT_DEPENDENCY_DIR}"
    RESULT_VARIABLE TC_SLJIT_FETCH_RESULT)
  if(NOT TC_SLJIT_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to fetch SLJIT prebuilt for ${SLJIT_PLATFORM}/${SLJIT_ARCH}")
  endif()
  include("${TC_SLJIT_DEPENDENCY_DIR}/cmake/FindSLJIT.cmake")
  if(NOT SLJIT_FOUND)
    message(FATAL_ERROR "Fetched SLJIT artifact was not found")
  endif()
endfunction()
