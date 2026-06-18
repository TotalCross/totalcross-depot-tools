# Copyright (C) 2026 Amalgam Solucoes em TI Ltda
#
# SPDX-License-Identifier: LGPL-2.1-only

get_filename_component(TCVM_LIBJPEG_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_LIBJPEG_AUTOFETCH_DEP_DIR "${TCVM_LIBJPEG_AUTOFETCH_DIR}/.." ABSOLUTE)
set(TCVM_LIBJPEG_RELEASE_HELPER "${TCVM_LIBJPEG_AUTOFETCH_DEP_DIR}/../cmake/DepotDependencyRelease.cmake")
if(EXISTS "${TCVM_LIBJPEG_RELEASE_HELPER}")
  include("${TCVM_LIBJPEG_RELEASE_HELPER}")
endif()

function(tcvm_auto_fetch_libjpeg)
  set(TCVM_LIBJPEG_DEP_DIR "${TCVM_LIBJPEG_AUTOFETCH_DEP_DIR}")
  set(TCVM_LIBJPEG_LOCAL_ROOT "${TCVM_LIBJPEG_DEP_DIR}/local")

  if(NOT DEFINED LIBJPEG_RELEASE_TAG AND DEFINED ENV{LIBJPEG_RELEASE_TAG})
    set(LIBJPEG_RELEASE_TAG "$ENV{LIBJPEG_RELEASE_TAG}")
  elseif(NOT DEFINED LIBJPEG_RELEASE_TAG)
    if(COMMAND tcvm_get_dependency_release)
      tcvm_get_dependency_release(libjpeg LIBJPEG_RELEASE_TAG "libjpeg-10")
    else()
      set(LIBJPEG_RELEASE_TAG "libjpeg-10")
    endif()
  endif()

  if(NOT DEFINED LIBJPEG_GITHUB_REPO AND DEFINED ENV{LIBJPEG_GITHUB_REPO})
    set(LIBJPEG_GITHUB_REPO "$ENV{LIBJPEG_GITHUB_REPO}")
  elseif(NOT DEFINED LIBJPEG_GITHUB_REPO)
    set(LIBJPEG_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()

  if(NOT DEFINED LIBJPEG_GITHUB_TOKEN_ENV AND DEFINED ENV{LIBJPEG_GITHUB_TOKEN_ENV})
    set(LIBJPEG_GITHUB_TOKEN_ENV "$ENV{LIBJPEG_GITHUB_TOKEN_ENV}")
  elseif(NOT DEFINED LIBJPEG_GITHUB_TOKEN_ENV)
    set(LIBJPEG_GITHUB_TOKEN_ENV "LIBJPEG_GITHUB_TOKEN")
  endif()

  if(DEFINED ANDROID_ABI)
    set(TCVM_LIBJPEG_PLATFORM "android")
    set(TCVM_LIBJPEG_ARCH "${ANDROID_ABI}")
  elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
    if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
      set(TCVM_LIBJPEG_PLATFORM "ios-simulator")
    else()
      set(TCVM_LIBJPEG_PLATFORM "ios")
    endif()
    set(TCVM_LIBJPEG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_LIBJPEG_ARCH)
      list(LENGTH TCVM_LIBJPEG_ARCH TCVM_LIBJPEG_ARCH_LEN)
      if(TCVM_LIBJPEG_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "libjpeg auto-fetch expects a single iOS architecture, got: ${TCVM_LIBJPEG_ARCH}")
      endif()
      list(GET TCVM_LIBJPEG_ARCH 0 TCVM_LIBJPEG_ARCH)
    else()
      set(TCVM_LIBJPEG_ARCH "arm64")
    endif()
    if(TCVM_LIBJPEG_ARCH STREQUAL "aarch64")
      set(TCVM_LIBJPEG_ARCH "arm64")
    endif()
  elseif(WIN32)
    set(TCVM_LIBJPEG_PLATFORM "windows")
    set(TCVM_LIBJPEG_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
    if(NOT TCVM_LIBJPEG_WINDOWS_PLATFORM)
      set(TCVM_LIBJPEG_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    string(TOLOWER "${TCVM_LIBJPEG_WINDOWS_PLATFORM}" TCVM_LIBJPEG_WINDOWS_PLATFORM_LOWER)
    if(TCVM_LIBJPEG_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
      set(TCVM_LIBJPEG_ARCH "x86")
    elseif(TCVM_LIBJPEG_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
      set(TCVM_LIBJPEG_ARCH "x64")
    elseif(TCVM_LIBJPEG_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
      set(TCVM_LIBJPEG_ARCH "arm64")
    elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(TCVM_LIBJPEG_ARCH "x64")
    else()
      set(TCVM_LIBJPEG_ARCH "x86")
    endif()
  elseif(APPLE)
    set(TCVM_LIBJPEG_PLATFORM "macos")
    set(TCVM_LIBJPEG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_LIBJPEG_ARCH)
      list(LENGTH TCVM_LIBJPEG_ARCH TCVM_LIBJPEG_ARCH_LEN)
      if(TCVM_LIBJPEG_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "libjpeg auto-fetch expects a single macOS architecture, got: ${TCVM_LIBJPEG_ARCH}")
      endif()
      list(GET TCVM_LIBJPEG_ARCH 0 TCVM_LIBJPEG_ARCH)
    else()
      set(TCVM_LIBJPEG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    if(TCVM_LIBJPEG_ARCH STREQUAL "amd64")
      set(TCVM_LIBJPEG_ARCH "x86_64")
    elseif(TCVM_LIBJPEG_ARCH STREQUAL "aarch64")
      set(TCVM_LIBJPEG_ARCH "arm64")
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(TCVM_LIBJPEG_PLATFORM "linux")
    set(TCVM_LIBJPEG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(TCVM_LIBJPEG_ARCH STREQUAL "amd64")
      set(TCVM_LIBJPEG_ARCH "x86_64")
    elseif(TCVM_LIBJPEG_ARCH STREQUAL "arm64")
      set(TCVM_LIBJPEG_ARCH "aarch64")
    elseif(TCVM_LIBJPEG_ARCH STREQUAL "arm" OR TCVM_LIBJPEG_ARCH STREQUAL "armv7")
      set(TCVM_LIBJPEG_ARCH "armv7l")
    endif()
  else()
    message(FATAL_ERROR "Unable to auto-fetch libjpeg for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  set(TCVM_DEFAULT_LIBJPEG_DIR "${TCVM_LIBJPEG_LOCAL_ROOT}/${TCVM_LIBJPEG_PLATFORM}/${TCVM_LIBJPEG_ARCH}")

  if(DEFINED JPEG_DIR AND NOT JPEG_DIR STREQUAL "${TCVM_DEFAULT_LIBJPEG_DIR}")
    return()
  endif()

  set(JPEG_DIR "${TCVM_DEFAULT_LIBJPEG_DIR}" CACHE PATH "libjpeg prebuilt directory" FORCE)

  set(TCVM_LIBJPEG_LIBRARY_CANDIDATES
    "${JPEG_DIR}/lib/libjpeg.a"
    "${JPEG_DIR}/lib/jpeg.lib"
    "${JPEG_DIR}/lib/libjpeg.lib"
  )

  if(EXISTS "${JPEG_DIR}/include/jpeglib.h"
      AND EXISTS "${JPEG_DIR}/include/jconfig.h"
      AND EXISTS "${JPEG_DIR}/include/jmorecfg.h"
      AND EXISTS "${JPEG_DIR}/include/jerror.h")
    foreach(TCVM_LIBJPEG_LIBRARY_CANDIDATE ${TCVM_LIBJPEG_LIBRARY_CANDIDATES})
      if(EXISTS "${TCVM_LIBJPEG_LIBRARY_CANDIDATE}")
        return()
      endif()
    endforeach()
  endif()

  find_program(TCVM_BASH_EXECUTABLE bash)
  if(NOT TCVM_BASH_EXECUTABLE)
    message(FATAL_ERROR "Unable to auto-fetch libjpeg because 'bash' was not found")
  endif()

  set(TCVM_LIBJPEG_FETCH_SCRIPT "${TCVM_LIBJPEG_DEP_DIR}/fetch.sh")
  if(NOT EXISTS "${TCVM_LIBJPEG_FETCH_SCRIPT}")
    message(FATAL_ERROR "Unable to auto-fetch libjpeg because '${TCVM_LIBJPEG_FETCH_SCRIPT}' does not exist")
  endif()

  message(STATUS "libjpeg artifacts not found locally. Fetching ${TCVM_LIBJPEG_PLATFORM}/${TCVM_LIBJPEG_ARCH}...")

  execute_process(
    COMMAND
      "${TCVM_BASH_EXECUTABLE}" "${TCVM_LIBJPEG_FETCH_SCRIPT}"
      --platform "${TCVM_LIBJPEG_PLATFORM}"
      --arch "${TCVM_LIBJPEG_ARCH}"
      --release-tag "${LIBJPEG_RELEASE_TAG}"
      --github-repo "${LIBJPEG_GITHUB_REPO}"
      --github-token-env "${LIBJPEG_GITHUB_TOKEN_ENV}"
      --dest "${TCVM_LIBJPEG_LOCAL_ROOT}"
    WORKING_DIRECTORY "${TCVM_LIBJPEG_DEP_DIR}"
    RESULT_VARIABLE TCVM_LIBJPEG_FETCH_RESULT
    OUTPUT_VARIABLE TCVM_LIBJPEG_FETCH_STDOUT
    ERROR_VARIABLE TCVM_LIBJPEG_FETCH_STDERR
  )

  if(NOT TCVM_LIBJPEG_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR
      "Failed to auto-fetch libjpeg.\n"
      "stdout:\n${TCVM_LIBJPEG_FETCH_STDOUT}\n"
      "stderr:\n${TCVM_LIBJPEG_FETCH_STDERR}"
    )
  endif()

  message(STATUS "${TCVM_LIBJPEG_FETCH_STDOUT}")
endfunction()
