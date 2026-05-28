# Copyright (C) 2026 Amalgam Solucoes em TI Ltda
#
# SPDX-License-Identifier: LGPL-2.1-only

get_filename_component(TCVM_LIBPNG_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_LIBPNG_AUTOFETCH_DEP_DIR "${TCVM_LIBPNG_AUTOFETCH_DIR}/.." ABSOLUTE)

function(tcvm_auto_fetch_libpng)
  set(TCVM_LIBPNG_DEP_DIR "${TCVM_LIBPNG_AUTOFETCH_DEP_DIR}")
  set(TCVM_LIBPNG_LOCAL_ROOT "${TCVM_LIBPNG_DEP_DIR}/local")

  if(NOT DEFINED LIBPNG_RELEASE_TAG AND DEFINED ENV{LIBPNG_RELEASE_TAG})
    set(LIBPNG_RELEASE_TAG "$ENV{LIBPNG_RELEASE_TAG}")
  elseif(NOT DEFINED LIBPNG_RELEASE_TAG)
    set(LIBPNG_RELEASE_TAG "libpng-1.6.48")
  endif()

  if(NOT DEFINED LIBPNG_GITHUB_REPO AND DEFINED ENV{LIBPNG_GITHUB_REPO})
    set(LIBPNG_GITHUB_REPO "$ENV{LIBPNG_GITHUB_REPO}")
  elseif(NOT DEFINED LIBPNG_GITHUB_REPO)
    set(LIBPNG_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()

  if(NOT DEFINED LIBPNG_GITHUB_TOKEN_ENV AND DEFINED ENV{LIBPNG_GITHUB_TOKEN_ENV})
    set(LIBPNG_GITHUB_TOKEN_ENV "$ENV{LIBPNG_GITHUB_TOKEN_ENV}")
  elseif(NOT DEFINED LIBPNG_GITHUB_TOKEN_ENV)
    set(LIBPNG_GITHUB_TOKEN_ENV "LIBPNG_GITHUB_TOKEN")
  endif()

  set(TCVM_LIBPNG_ZLIB_AUTOFETCH_SCRIPT "${TCVM_LIBPNG_DEP_DIR}/../zlib-ng/cmake/AutoFetchZlibNg.cmake")
  if(EXISTS "${TCVM_LIBPNG_ZLIB_AUTOFETCH_SCRIPT}")
    include("${TCVM_LIBPNG_ZLIB_AUTOFETCH_SCRIPT}")
    tcvm_auto_fetch_zlibng()
  endif()

  if(DEFINED ANDROID_ABI)
    set(TCVM_LIBPNG_PLATFORM "android")
    set(TCVM_LIBPNG_ARCH "${ANDROID_ABI}")
  elseif(CMAKE_GENERATOR STREQUAL Xcode)
    set(TCVM_LIBPNG_PLATFORM "ios")
    set(TCVM_LIBPNG_ARCH "arm64")
  elseif(WIN32)
    set(TCVM_LIBPNG_PLATFORM "windows")
    if(CMAKE_GENERATOR_PLATFORM MATCHES "x64")
      set(TCVM_LIBPNG_ARCH "x86_64")
    else()
      set(TCVM_LIBPNG_ARCH "x86")
    endif()
  elseif(APPLE)
    set(TCVM_LIBPNG_PLATFORM "macos")
    set(TCVM_LIBPNG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_LIBPNG_ARCH)
      list(LENGTH TCVM_LIBPNG_ARCH TCVM_LIBPNG_ARCH_LEN)
      if(TCVM_LIBPNG_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "libpng auto-fetch expects a single macOS architecture, got: ${TCVM_LIBPNG_ARCH}")
      endif()
      list(GET TCVM_LIBPNG_ARCH 0 TCVM_LIBPNG_ARCH)
    else()
      set(TCVM_LIBPNG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    if(TCVM_LIBPNG_ARCH STREQUAL "amd64")
      set(TCVM_LIBPNG_ARCH "x86_64")
    elseif(TCVM_LIBPNG_ARCH STREQUAL "aarch64")
      set(TCVM_LIBPNG_ARCH "arm64")
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(TCVM_LIBPNG_PLATFORM "linux")
    set(TCVM_LIBPNG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(TCVM_LIBPNG_ARCH STREQUAL "amd64")
      set(TCVM_LIBPNG_ARCH "x86_64")
    elseif(TCVM_LIBPNG_ARCH STREQUAL "arm64")
      set(TCVM_LIBPNG_ARCH "aarch64")
    elseif(TCVM_LIBPNG_ARCH STREQUAL "arm" OR TCVM_LIBPNG_ARCH STREQUAL "armv7")
      set(TCVM_LIBPNG_ARCH "armv7l")
    endif()
  else()
    message(FATAL_ERROR "Unable to auto-fetch libpng for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  set(TCVM_DEFAULT_LIBPNG_DIR "${TCVM_LIBPNG_LOCAL_ROOT}/${TCVM_LIBPNG_PLATFORM}/${TCVM_LIBPNG_ARCH}")

  if(DEFINED PNG_DIR AND NOT PNG_DIR STREQUAL "${TCVM_DEFAULT_LIBPNG_DIR}")
    return()
  endif()

  set(PNG_DIR "${TCVM_DEFAULT_LIBPNG_DIR}" CACHE PATH "libpng prebuilt directory" FORCE)

  if(EXISTS "${PNG_DIR}/include/png.h"
      AND EXISTS "${PNG_DIR}/include/pngconf.h"
      AND EXISTS "${PNG_DIR}/include/pnglibconf.h")
    if(EXISTS "${PNG_DIR}/lib/libpng.a"
        OR EXISTS "${PNG_DIR}/lib/libpng16.a"
        OR EXISTS "${PNG_DIR}/lib/png.lib"
        OR EXISTS "${PNG_DIR}/lib/libpng.lib")
      return()
    endif()
  endif()

  find_program(TCVM_BASH_EXECUTABLE bash)
  if(NOT TCVM_BASH_EXECUTABLE)
    message(FATAL_ERROR "Unable to auto-fetch libpng because 'bash' was not found")
  endif()

  set(TCVM_LIBPNG_FETCH_SCRIPT "${TCVM_LIBPNG_DEP_DIR}/fetch.sh")
  if(NOT EXISTS "${TCVM_LIBPNG_FETCH_SCRIPT}")
    message(FATAL_ERROR "Unable to auto-fetch libpng because '${TCVM_LIBPNG_FETCH_SCRIPT}' does not exist")
  endif()

  message(STATUS "libpng artifacts not found locally. Fetching ${TCVM_LIBPNG_PLATFORM}/${TCVM_LIBPNG_ARCH}...")

  execute_process(
    COMMAND
      "${TCVM_BASH_EXECUTABLE}" "${TCVM_LIBPNG_FETCH_SCRIPT}"
      --platform "${TCVM_LIBPNG_PLATFORM}"
      --arch "${TCVM_LIBPNG_ARCH}"
      --release-tag "${LIBPNG_RELEASE_TAG}"
      --github-repo "${LIBPNG_GITHUB_REPO}"
      --github-token-env "${LIBPNG_GITHUB_TOKEN_ENV}"
      --dest "${TCVM_LIBPNG_LOCAL_ROOT}"
    WORKING_DIRECTORY "${TCVM_LIBPNG_DEP_DIR}"
    RESULT_VARIABLE TCVM_LIBPNG_FETCH_RESULT
    OUTPUT_VARIABLE TCVM_LIBPNG_FETCH_STDOUT
    ERROR_VARIABLE TCVM_LIBPNG_FETCH_STDERR
  )

  if(NOT TCVM_LIBPNG_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR
      "Failed to auto-fetch libpng.\n"
      "stdout:\n${TCVM_LIBPNG_FETCH_STDOUT}\n"
      "stderr:\n${TCVM_LIBPNG_FETCH_STDERR}"
    )
  endif()

  message(STATUS "${TCVM_LIBPNG_FETCH_STDOUT}")
endfunction()
