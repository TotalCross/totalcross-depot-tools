# Copyright (C) 2026 Amalgam Solucoes em TI Ltda
#
# SPDX-License-Identifier: LGPL-2.1-only

get_filename_component(TCVM_ZLIB_NG_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_ZLIB_NG_AUTOFETCH_DEP_DIR "${TCVM_ZLIB_NG_AUTOFETCH_DIR}/.." ABSOLUTE)

function(tcvm_auto_fetch_zlibng)
  set(TCVM_ZLIB_NG_DEP_DIR "${TCVM_ZLIB_NG_AUTOFETCH_DEP_DIR}")
  set(TCVM_ZLIB_NG_LOCAL_ROOT "${TCVM_ZLIB_NG_DEP_DIR}/local")

  if(NOT DEFINED ZLIB_NG_RELEASE_TAG AND DEFINED ENV{ZLIB_NG_RELEASE_TAG})
    set(ZLIB_NG_RELEASE_TAG "$ENV{ZLIB_NG_RELEASE_TAG}")
  elseif(NOT DEFINED ZLIB_NG_RELEASE_TAG)
    set(ZLIB_NG_RELEASE_TAG "zlib-ng-2.1.6")
  endif()

  if(NOT DEFINED ZLIB_NG_GITHUB_REPO AND DEFINED ENV{ZLIB_NG_GITHUB_REPO})
    set(ZLIB_NG_GITHUB_REPO "$ENV{ZLIB_NG_GITHUB_REPO}")
  elseif(NOT DEFINED ZLIB_NG_GITHUB_REPO)
    set(ZLIB_NG_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()

  if(NOT DEFINED ZLIB_NG_GITHUB_TOKEN_ENV AND DEFINED ENV{ZLIB_NG_GITHUB_TOKEN_ENV})
    set(ZLIB_NG_GITHUB_TOKEN_ENV "$ENV{ZLIB_NG_GITHUB_TOKEN_ENV}")
  elseif(NOT DEFINED ZLIB_NG_GITHUB_TOKEN_ENV)
    set(ZLIB_NG_GITHUB_TOKEN_ENV "ZLIB_NG_GITHUB_TOKEN")
  endif()

  if(DEFINED ANDROID_ABI)
    set(TCVM_ZLIB_NG_PLATFORM "android")
    set(TCVM_ZLIB_NG_ARCH "${ANDROID_ABI}")
  elseif(CMAKE_GENERATOR STREQUAL Xcode)
    set(TCVM_ZLIB_NG_PLATFORM "ios")
    set(TCVM_ZLIB_NG_ARCH "xcframework")
  elseif(WIN32)
    set(TCVM_ZLIB_NG_PLATFORM "windows")
    if(CMAKE_GENERATOR_PLATFORM MATCHES "x64")
      set(TCVM_ZLIB_NG_ARCH "x86_64")
    else()
      set(TCVM_ZLIB_NG_ARCH "x86")
    endif()
  elseif(APPLE)
    set(TCVM_ZLIB_NG_PLATFORM "macos")
    set(TCVM_ZLIB_NG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_ZLIB_NG_ARCH)
      list(LENGTH TCVM_ZLIB_NG_ARCH TCVM_ZLIB_NG_ARCH_LEN)
      if(TCVM_ZLIB_NG_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "zlib-ng auto-fetch expects a single macOS architecture, got: ${TCVM_ZLIB_NG_ARCH}")
      endif()
      list(GET TCVM_ZLIB_NG_ARCH 0 TCVM_ZLIB_NG_ARCH)
    else()
      set(TCVM_ZLIB_NG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    if(TCVM_ZLIB_NG_ARCH STREQUAL "amd64")
      set(TCVM_ZLIB_NG_ARCH "x86_64")
    elseif(TCVM_ZLIB_NG_ARCH STREQUAL "aarch64")
      set(TCVM_ZLIB_NG_ARCH "arm64")
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(TCVM_ZLIB_NG_PLATFORM "linux")
    set(TCVM_ZLIB_NG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(TCVM_ZLIB_NG_ARCH STREQUAL "amd64")
      set(TCVM_ZLIB_NG_ARCH "x86_64")
    elseif(TCVM_ZLIB_NG_ARCH STREQUAL "arm64")
      set(TCVM_ZLIB_NG_ARCH "aarch64")
    elseif(TCVM_ZLIB_NG_ARCH STREQUAL "arm" OR TCVM_ZLIB_NG_ARCH STREQUAL "armv7")
      set(TCVM_ZLIB_NG_ARCH "armv7l")
    endif()
  else()
    message(FATAL_ERROR "Unable to auto-fetch zlib-ng for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  set(TCVM_DEFAULT_ZLIB_NG_DIR "${TCVM_ZLIB_NG_LOCAL_ROOT}/${TCVM_ZLIB_NG_PLATFORM}/${TCVM_ZLIB_NG_ARCH}")

  if(DEFINED ZLIB_DIR AND NOT ZLIB_DIR STREQUAL "${TCVM_DEFAULT_ZLIB_NG_DIR}")
    return()
  endif()

  set(ZLIB_DIR "${TCVM_DEFAULT_ZLIB_NG_DIR}" CACHE PATH "zlib-ng prebuilt directory" FORCE)

  set(TCVM_ZLIB_NG_LIBRARY_CANDIDATES
    "${ZLIB_DIR}/lib/libz.xcframework"
    "${ZLIB_DIR}/lib/libz.a"
    "${ZLIB_DIR}/lib/zlib.lib"
    "${ZLIB_DIR}/lib/zlibstatic.lib"
  )

  if(EXISTS "${ZLIB_DIR}/include/zlib.h"
      AND EXISTS "${ZLIB_DIR}/include/zconf.h"
      AND EXISTS "${ZLIB_DIR}/include/zlib_name_mangling.h")
    foreach(TCVM_ZLIB_NG_LIBRARY_CANDIDATE ${TCVM_ZLIB_NG_LIBRARY_CANDIDATES})
      if(EXISTS "${TCVM_ZLIB_NG_LIBRARY_CANDIDATE}")
        return()
      endif()
    endforeach()
  endif()

  find_program(TCVM_BASH_EXECUTABLE bash)
  if(NOT TCVM_BASH_EXECUTABLE)
    message(FATAL_ERROR "Unable to auto-fetch zlib-ng because 'bash' was not found")
  endif()

  set(TCVM_ZLIB_NG_FETCH_SCRIPT "${TCVM_ZLIB_NG_DEP_DIR}/fetch.sh")
  if(NOT EXISTS "${TCVM_ZLIB_NG_FETCH_SCRIPT}")
    message(FATAL_ERROR "Unable to auto-fetch zlib-ng because '${TCVM_ZLIB_NG_FETCH_SCRIPT}' does not exist")
  endif()

  message(STATUS "zlib-ng artifacts not found locally. Fetching ${TCVM_ZLIB_NG_PLATFORM}/${TCVM_ZLIB_NG_ARCH}...")

  execute_process(
    COMMAND
      "${TCVM_BASH_EXECUTABLE}" "${TCVM_ZLIB_NG_FETCH_SCRIPT}"
      --platform "${TCVM_ZLIB_NG_PLATFORM}"
      --arch "${TCVM_ZLIB_NG_ARCH}"
      --release-tag "${ZLIB_NG_RELEASE_TAG}"
      --github-repo "${ZLIB_NG_GITHUB_REPO}"
      --github-token-env "${ZLIB_NG_GITHUB_TOKEN_ENV}"
      --dest "${TCVM_ZLIB_NG_LOCAL_ROOT}"
    WORKING_DIRECTORY "${TCVM_ZLIB_NG_DEP_DIR}"
    RESULT_VARIABLE TCVM_ZLIB_NG_FETCH_RESULT
    OUTPUT_VARIABLE TCVM_ZLIB_NG_FETCH_STDOUT
    ERROR_VARIABLE TCVM_ZLIB_NG_FETCH_STDERR
  )

  if(NOT TCVM_ZLIB_NG_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR
      "Failed to auto-fetch zlib-ng.\n"
      "stdout:\n${TCVM_ZLIB_NG_FETCH_STDOUT}\n"
      "stderr:\n${TCVM_ZLIB_NG_FETCH_STDERR}"
    )
  endif()

  message(STATUS "${TCVM_ZLIB_NG_FETCH_STDOUT}")
endfunction()
