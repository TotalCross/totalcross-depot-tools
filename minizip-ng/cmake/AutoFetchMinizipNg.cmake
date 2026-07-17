# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
#

get_filename_component(TCVM_MINIZIP_NG_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_MINIZIP_NG_AUTOFETCH_DEP_DIR "${TCVM_MINIZIP_NG_AUTOFETCH_DIR}/.." ABSOLUTE)
set(TCVM_MINIZIP_NG_RELEASE_HELPER "${TCVM_MINIZIP_NG_AUTOFETCH_DEP_DIR}/../cmake/DepotDependencyRelease.cmake")
if(EXISTS "${TCVM_MINIZIP_NG_RELEASE_HELPER}")
  include("${TCVM_MINIZIP_NG_RELEASE_HELPER}")
endif()

function(tcvm_auto_fetch_minizipng)
  set(TCVM_MINIZIP_NG_DEP_DIR "${TCVM_MINIZIP_NG_AUTOFETCH_DEP_DIR}")
  set(TCVM_MINIZIP_NG_LOCAL_ROOT "${TCVM_MINIZIP_NG_DEP_DIR}/local")

  if(NOT DEFINED MINIZIP_NG_RELEASE_TAG AND DEFINED ENV{MINIZIP_NG_RELEASE_TAG})
    set(MINIZIP_NG_RELEASE_TAG "$ENV{MINIZIP_NG_RELEASE_TAG}")
  elseif(NOT DEFINED MINIZIP_NG_RELEASE_TAG)
    if(COMMAND tcvm_get_dependency_release)
      tcvm_get_dependency_release(minizip-ng MINIZIP_NG_RELEASE_TAG "minizip-ng-4.2.2")
    else()
      set(MINIZIP_NG_RELEASE_TAG "minizip-ng-4.2.2")
    endif()
  endif()

  if(NOT DEFINED MINIZIP_NG_GITHUB_REPO AND DEFINED ENV{MINIZIP_NG_GITHUB_REPO})
    set(MINIZIP_NG_GITHUB_REPO "$ENV{MINIZIP_NG_GITHUB_REPO}")
  elseif(NOT DEFINED MINIZIP_NG_GITHUB_REPO)
    set(MINIZIP_NG_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()

  if(NOT DEFINED MINIZIP_NG_GITHUB_TOKEN_ENV AND DEFINED ENV{MINIZIP_NG_GITHUB_TOKEN_ENV})
    set(MINIZIP_NG_GITHUB_TOKEN_ENV "$ENV{MINIZIP_NG_GITHUB_TOKEN_ENV}")
  elseif(NOT DEFINED MINIZIP_NG_GITHUB_TOKEN_ENV)
    set(MINIZIP_NG_GITHUB_TOKEN_ENV "MINIZIP_NG_GITHUB_TOKEN")
  endif()

  set(TCVM_MINIZIP_NG_ZLIB_AUTOFETCH_SCRIPT "${TCVM_MINIZIP_NG_DEP_DIR}/../zlib-ng/cmake/AutoFetchZlibNg.cmake")
  if(EXISTS "${TCVM_MINIZIP_NG_ZLIB_AUTOFETCH_SCRIPT}")
    include("${TCVM_MINIZIP_NG_ZLIB_AUTOFETCH_SCRIPT}")
    tcvm_auto_fetch_zlibng()
  endif()

  if(DEFINED ANDROID_ABI)
    set(TCVM_MINIZIP_NG_PLATFORM "android")
    set(TCVM_MINIZIP_NG_ARCH "${ANDROID_ABI}")
  elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
    if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
      set(TCVM_MINIZIP_NG_PLATFORM "ios-simulator")
    else()
      set(TCVM_MINIZIP_NG_PLATFORM "ios")
    endif()
    set(TCVM_MINIZIP_NG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_MINIZIP_NG_ARCH)
      list(LENGTH TCVM_MINIZIP_NG_ARCH TCVM_MINIZIP_NG_ARCH_LEN)
      if(TCVM_MINIZIP_NG_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "minizip-ng auto-fetch expects a single iOS architecture, got: ${TCVM_MINIZIP_NG_ARCH}")
      endif()
      list(GET TCVM_MINIZIP_NG_ARCH 0 TCVM_MINIZIP_NG_ARCH)
    else()
      set(TCVM_MINIZIP_NG_ARCH "arm64")
    endif()
    if(TCVM_MINIZIP_NG_ARCH STREQUAL "aarch64")
      set(TCVM_MINIZIP_NG_ARCH "arm64")
    endif()
  elseif(WIN32)
    set(TCVM_MINIZIP_NG_PLATFORM "windows")
    set(TCVM_MINIZIP_NG_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
    if(NOT TCVM_MINIZIP_NG_WINDOWS_PLATFORM)
      set(TCVM_MINIZIP_NG_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    string(TOLOWER "${TCVM_MINIZIP_NG_WINDOWS_PLATFORM}" TCVM_MINIZIP_NG_WINDOWS_PLATFORM_LOWER)
    if(TCVM_MINIZIP_NG_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
      set(TCVM_MINIZIP_NG_ARCH "x86")
    elseif(TCVM_MINIZIP_NG_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
      set(TCVM_MINIZIP_NG_ARCH "x64")
    elseif(TCVM_MINIZIP_NG_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
      set(TCVM_MINIZIP_NG_ARCH "arm64")
    elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(TCVM_MINIZIP_NG_ARCH "x64")
    else()
      set(TCVM_MINIZIP_NG_ARCH "x86")
    endif()
  elseif(APPLE)
    set(TCVM_MINIZIP_NG_PLATFORM "macos")
    set(TCVM_MINIZIP_NG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_MINIZIP_NG_ARCH)
      list(LENGTH TCVM_MINIZIP_NG_ARCH TCVM_MINIZIP_NG_ARCH_LEN)
      if(TCVM_MINIZIP_NG_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "minizip-ng auto-fetch expects a single macOS architecture, got: ${TCVM_MINIZIP_NG_ARCH}")
      endif()
      list(GET TCVM_MINIZIP_NG_ARCH 0 TCVM_MINIZIP_NG_ARCH)
    else()
      set(TCVM_MINIZIP_NG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    if(TCVM_MINIZIP_NG_ARCH STREQUAL "amd64")
      set(TCVM_MINIZIP_NG_ARCH "x86_64")
    elseif(TCVM_MINIZIP_NG_ARCH STREQUAL "aarch64")
      set(TCVM_MINIZIP_NG_ARCH "arm64")
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(TCVM_MINIZIP_NG_PLATFORM "linux")
    set(TCVM_MINIZIP_NG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(TCVM_MINIZIP_NG_ARCH STREQUAL "amd64")
      set(TCVM_MINIZIP_NG_ARCH "x86_64")
    elseif(TCVM_MINIZIP_NG_ARCH STREQUAL "arm64")
      set(TCVM_MINIZIP_NG_ARCH "aarch64")
    elseif(TCVM_MINIZIP_NG_ARCH STREQUAL "arm" OR TCVM_MINIZIP_NG_ARCH STREQUAL "armv7")
      set(TCVM_MINIZIP_NG_ARCH "armv7l")
    endif()
  else()
    message(FATAL_ERROR "Unable to auto-fetch minizip-ng for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  set(TCVM_DEFAULT_MINIZIP_NG_DIR "${TCVM_MINIZIP_NG_LOCAL_ROOT}/${TCVM_MINIZIP_NG_PLATFORM}/${TCVM_MINIZIP_NG_ARCH}")

  if(DEFINED MINIZIP_DIR AND NOT MINIZIP_DIR STREQUAL "${TCVM_DEFAULT_MINIZIP_NG_DIR}")
    return()
  endif()

  set(MINIZIP_DIR "${TCVM_DEFAULT_MINIZIP_NG_DIR}" CACHE PATH "minizip-ng prebuilt directory" FORCE)

  set(TCVM_MINIZIP_NG_LIBRARY_CANDIDATES
    "${MINIZIP_DIR}/lib/libminizip.a"
    "${MINIZIP_DIR}/lib/minizip.lib"
    "${MINIZIP_DIR}/lib/libminizip.lib"
    "${MINIZIP_DIR}/lib/minizipstatic.lib"
  )

  if(EXISTS "${MINIZIP_DIR}/include/ioapi.h"
      AND EXISTS "${MINIZIP_DIR}/include/mz.h"
      AND EXISTS "${MINIZIP_DIR}/include/mz_zip.h"
      AND EXISTS "${MINIZIP_DIR}/include/mz_zip_rw.h"
      AND EXISTS "${MINIZIP_DIR}/include/unzip.h"
      AND EXISTS "${MINIZIP_DIR}/include/zip.h")
    foreach(TCVM_MINIZIP_NG_LIBRARY_CANDIDATE ${TCVM_MINIZIP_NG_LIBRARY_CANDIDATES})
      if(EXISTS "${TCVM_MINIZIP_NG_LIBRARY_CANDIDATE}")
        return()
      endif()
    endforeach()
  endif()

  find_program(TCVM_BASH_EXECUTABLE bash)
  if(NOT TCVM_BASH_EXECUTABLE)
    message(FATAL_ERROR "Unable to auto-fetch minizip-ng because 'bash' was not found")
  endif()

  set(TCVM_MINIZIP_NG_FETCH_SCRIPT "${TCVM_MINIZIP_NG_DEP_DIR}/fetch.sh")
  if(NOT EXISTS "${TCVM_MINIZIP_NG_FETCH_SCRIPT}")
    message(FATAL_ERROR "Unable to auto-fetch minizip-ng because '${TCVM_MINIZIP_NG_FETCH_SCRIPT}' does not exist")
  endif()

  message(STATUS "minizip-ng artifacts not found locally. Fetching ${TCVM_MINIZIP_NG_PLATFORM}/${TCVM_MINIZIP_NG_ARCH}...")

  execute_process(
    COMMAND
      "${TCVM_BASH_EXECUTABLE}" "${TCVM_MINIZIP_NG_FETCH_SCRIPT}"
      --platform "${TCVM_MINIZIP_NG_PLATFORM}"
      --arch "${TCVM_MINIZIP_NG_ARCH}"
      --release-tag "${MINIZIP_NG_RELEASE_TAG}"
      --github-repo "${MINIZIP_NG_GITHUB_REPO}"
      --github-token-env "${MINIZIP_NG_GITHUB_TOKEN_ENV}"
      --dest "${TCVM_MINIZIP_NG_LOCAL_ROOT}"
    WORKING_DIRECTORY "${TCVM_MINIZIP_NG_DEP_DIR}"
    RESULT_VARIABLE TCVM_MINIZIP_NG_FETCH_RESULT
    OUTPUT_VARIABLE TCVM_MINIZIP_NG_FETCH_STDOUT
    ERROR_VARIABLE TCVM_MINIZIP_NG_FETCH_STDERR
  )

  if(NOT TCVM_MINIZIP_NG_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR
      "Failed to auto-fetch minizip-ng.\n"
      "stdout:\n${TCVM_MINIZIP_NG_FETCH_STDOUT}\n"
      "stderr:\n${TCVM_MINIZIP_NG_FETCH_STDERR}"
    )
  endif()

  message(STATUS "${TCVM_MINIZIP_NG_FETCH_STDOUT}")
endfunction()
