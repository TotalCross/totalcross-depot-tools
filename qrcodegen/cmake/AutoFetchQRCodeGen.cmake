# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
get_filename_component(TC_QRCODEGEN_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TC_QRCODEGEN_DEP_DIR "${TC_QRCODEGEN_AUTOFETCH_DIR}/.." ABSOLUTE)

function(tcvm_auto_fetch_qrcodegen)
  if(NOT DEFINED QRCODEGEN_RELEASE_TAG)
    set(QRCODEGEN_RELEASE_TAG "qrcodegen-20250123")
  endif()
  if(NOT DEFINED QRCODEGEN_GITHUB_REPO)
    set(QRCODEGEN_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()
  include("${TC_QRCODEGEN_DEP_DIR}/cmake/FindQRCodeGen.cmake")
  if(QRCodeGen_FOUND)
    return()
  endif()
  find_program(TC_QRCODEGEN_BASH bash REQUIRED)
  execute_process(COMMAND "${TC_QRCODEGEN_BASH}" "${TC_QRCODEGEN_DEP_DIR}/fetch.sh"
    --platform "${QRCodeGen_PLATFORM}" --arch "${QRCodeGen_ARCH}"
    --release-tag "${QRCODEGEN_RELEASE_TAG}" --github-repo "${QRCODEGEN_GITHUB_REPO}"
    WORKING_DIRECTORY "${TC_QRCODEGEN_DEP_DIR}" RESULT_VARIABLE TC_QRCODEGEN_FETCH_RESULT)
  if(NOT TC_QRCODEGEN_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to fetch qrcodegen prebuilt for ${QRCodeGen_PLATFORM}/${QRCodeGen_ARCH}")
  endif()
  include("${TC_QRCODEGEN_DEP_DIR}/cmake/FindQRCodeGen.cmake")
  if(NOT QRCodeGen_FOUND)
    message(FATAL_ERROR "Fetched qrcodegen artifact was not found")
  endif()
endfunction()
