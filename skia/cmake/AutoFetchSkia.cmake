# Copyright (C) 2020 TotalCross Global Mobile Platform Ltda.
#
# SPDX-License-Identifier: LGPL-2.1-only

get_filename_component(TCVM_SKIA_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_SKIA_AUTOFETCH_DEP_DIR "${TCVM_SKIA_AUTOFETCH_DIR}/.." ABSOLUTE)
set(TCVM_SKIA_RELEASE_HELPER "${TCVM_SKIA_AUTOFETCH_DEP_DIR}/../cmake/DepotDependencyRelease.cmake")
if(EXISTS "${TCVM_SKIA_RELEASE_HELPER}")
  include("${TCVM_SKIA_RELEASE_HELPER}")
endif()

function(tcvm_auto_fetch_skia_dependencies)
  set(TCVM_SKIA_LIBPNG_AUTOFETCH_SCRIPT "${TCVM_SKIA_AUTOFETCH_DEP_DIR}/../libpng/cmake/AutoFetchLibPng.cmake")
  set(TCVM_SKIA_ZLIB_AUTOFETCH_SCRIPT "${TCVM_SKIA_AUTOFETCH_DEP_DIR}/../zlib-ng/cmake/AutoFetchZlibNg.cmake")

  if(EXISTS "${TCVM_SKIA_LIBPNG_AUTOFETCH_SCRIPT}")
    include("${TCVM_SKIA_LIBPNG_AUTOFETCH_SCRIPT}")
    tcvm_auto_fetch_libpng()
  elseif(EXISTS "${TCVM_SKIA_ZLIB_AUTOFETCH_SCRIPT}")
    include("${TCVM_SKIA_ZLIB_AUTOFETCH_SCRIPT}")
    tcvm_auto_fetch_zlibng()
  endif()
endfunction()

function(tcvm_auto_fetch_skia)
  set(TCVM_SKIA_DEP_DIR "${TCVM_SKIA_AUTOFETCH_DEP_DIR}")
  set(TCVM_DEFAULT_SKIA_DIR "${TCVM_SKIA_DEP_DIR}/local")

  if(NOT DEFINED SKIA_RELEASE_TAG AND DEFINED ENV{SKIA_RELEASE_TAG})
    set(SKIA_RELEASE_TAG "$ENV{SKIA_RELEASE_TAG}")
  elseif(NOT DEFINED SKIA_RELEASE_TAG)
    if(COMMAND tcvm_get_dependency_release)
      tcvm_get_dependency_release(skia SKIA_RELEASE_TAG "skia-158dc9d7-r3")
    else()
      set(SKIA_RELEASE_TAG "skia-158dc9d7-r3")
    endif()
  endif()

  if(NOT DEFINED SKIA_GITHUB_REPO AND DEFINED ENV{SKIA_GITHUB_REPO})
    set(SKIA_GITHUB_REPO "$ENV{SKIA_GITHUB_REPO}")
  elseif(NOT DEFINED SKIA_GITHUB_REPO)
    set(SKIA_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()

  if(NOT DEFINED SKIA_GITHUB_TOKEN_ENV AND DEFINED ENV{SKIA_GITHUB_TOKEN_ENV})
    set(SKIA_GITHUB_TOKEN_ENV "$ENV{SKIA_GITHUB_TOKEN_ENV}")
  elseif(NOT DEFINED SKIA_GITHUB_TOKEN_ENV)
    set(SKIA_GITHUB_TOKEN_ENV "SKIA_GITHUB_TOKEN")
  endif()

  if(NOT DEFINED SKIA_ARTIFACT_BASE_URL AND DEFINED ENV{SKIA_ARTIFACT_BASE_URL})
    set(SKIA_ARTIFACT_BASE_URL "$ENV{SKIA_ARTIFACT_BASE_URL}")
  endif()

  if(NOT SKIA_GITHUB_REPO MATCHES "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
    message(FATAL_ERROR "Invalid Skia GitHub repository value. Expected OWNER/REPO.")
  endif()

  foreach(TCVM_SKIA_RELEASE_TAG_FORBIDDEN " " "{" "}" "/" "\\")
    string(FIND "${SKIA_RELEASE_TAG}" "${TCVM_SKIA_RELEASE_TAG_FORBIDDEN}" TCVM_SKIA_RELEASE_TAG_FORBIDDEN_INDEX)
    if(NOT TCVM_SKIA_RELEASE_TAG_FORBIDDEN_INDEX EQUAL -1)
      message(FATAL_ERROR "Invalid Skia release tag value: ${SKIA_RELEASE_TAG}")
    endif()
  endforeach()
  string(FIND "${SKIA_RELEASE_TAG}" ".." TCVM_SKIA_RELEASE_TAG_PARENT_INDEX)
  if(NOT TCVM_SKIA_RELEASE_TAG_PARENT_INDEX EQUAL -1)
    message(FATAL_ERROR "Invalid Skia release tag value: ${SKIA_RELEASE_TAG}")
  endif()

  if(DEFINED SKIA_LIBRARY)
    if(EXISTS "${SKIA_LIBRARY}")
      string(FIND "${SKIA_LIBRARY}" "${TCVM_DEFAULT_SKIA_DIR}" TCVM_SKIA_LIBRARY_DEPOT_INDEX)
      if(NOT TCVM_SKIA_LIBRARY_DEPOT_INDEX EQUAL 0)
        return()
      endif()
    endif()
    unset(SKIA_LIBRARY CACHE)
  endif()

  if(DEFINED SKIA_LIBRARIES)
    list(LENGTH SKIA_LIBRARIES TCVM_SKIA_LIBRARIES_LEN)
    if(TCVM_SKIA_LIBRARIES_LEN EQUAL 1 AND EXISTS "${SKIA_LIBRARIES}")
      string(FIND "${SKIA_LIBRARIES}" "${TCVM_DEFAULT_SKIA_DIR}" TCVM_SKIA_LIBRARIES_DEPOT_INDEX)
      if(NOT TCVM_SKIA_LIBRARIES_DEPOT_INDEX EQUAL 0)
        return()
      endif()
    endif()
    unset(SKIA_LIBRARIES CACHE)
  endif()

  if(DEFINED SKIA_DIR AND NOT SKIA_DIR STREQUAL "${TCVM_DEFAULT_SKIA_DIR}")
    return()
  endif()

  find_program(TCVM_BASH_EXECUTABLE bash)
  if(NOT TCVM_BASH_EXECUTABLE)
    message(FATAL_ERROR "Unable to auto-fetch Skia because 'bash' was not found")
  endif()

  set(TCVM_FETCH_SCRIPT "${TCVM_SKIA_DEP_DIR}/fetch.sh")
  if(NOT EXISTS "${TCVM_FETCH_SCRIPT}")
    message(FATAL_ERROR "Unable to auto-fetch Skia because '${TCVM_FETCH_SCRIPT}' does not exist")
  endif()

  set(TCVM_SKIA_DIR "${TCVM_DEFAULT_SKIA_DIR}")
  set(TCVM_FETCH_NEEDED OFF)
  set(TCVM_FETCH_PLATFORM "")
  set(TCVM_FETCH_ARCH "")
  set(TCVM_FETCH_INSTALL_DEV OFF)

  if(DEFINED ANDROID_ABI)
    set(TCVM_FETCH_PLATFORM "android")
    set(TCVM_FETCH_ARCH "${ANDROID_ABI}")
    set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/android/${ANDROID_ABI}/libskia.a")
  elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
    set(TCVM_FETCH_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_FETCH_ARCH)
      list(LENGTH TCVM_FETCH_ARCH TCVM_FETCH_ARCH_LEN)
      if(TCVM_FETCH_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "Skia auto-fetch expects a single iOS architecture, got: ${TCVM_FETCH_ARCH}")
      endif()
      list(GET TCVM_FETCH_ARCH 0 TCVM_FETCH_ARCH)
    else()
      set(TCVM_FETCH_ARCH "arm64")
    endif()

    if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
      set(TCVM_FETCH_PLATFORM "ios-simulator")
      set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/ios-simulator/${TCVM_FETCH_ARCH}/libskia.a")
    else()
      set(TCVM_FETCH_PLATFORM "ios")
      set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/ios/${TCVM_FETCH_ARCH}/libskia.a")
    endif()

    set(TCVM_FETCH_INSTALL_DEV ON)
  elseif(APPLE)
    set(TCVM_FETCH_PLATFORM "macos")
    set(TCVM_FETCH_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_FETCH_ARCH)
      list(LENGTH TCVM_FETCH_ARCH TCVM_FETCH_ARCH_LEN)
      if(TCVM_FETCH_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "Skia auto-fetch expects a single macOS architecture, got: ${TCVM_FETCH_ARCH}")
      endif()
      list(GET TCVM_FETCH_ARCH 0 TCVM_FETCH_ARCH)
    else()
      set(TCVM_FETCH_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    if(TCVM_FETCH_ARCH STREQUAL "amd64")
      set(TCVM_FETCH_ARCH "x86_64")
    elseif(TCVM_FETCH_ARCH STREQUAL "aarch64")
      set(TCVM_FETCH_ARCH "arm64")
    endif()

    set(TCVM_FETCH_INSTALL_DEV ON)
    set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/macos/${TCVM_FETCH_ARCH}/libskia.a")
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(TCVM_FETCH_PLATFORM "wasm")
    set(TCVM_FETCH_ARCH "wasm32")
    set(TCVM_FETCH_INSTALL_DEV ON)
    set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/wasm/wasm32/libskia.a")
  elseif(UNIX AND (CMAKE_SYSTEM_NAME STREQUAL "Linux"))
    set(TCVM_FETCH_PLATFORM "linux")
    set(TCVM_FETCH_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(TCVM_FETCH_ARCH STREQUAL "amd64")
      set(TCVM_FETCH_ARCH "x86_64")
    elseif(TCVM_FETCH_ARCH STREQUAL "arm64")
      set(TCVM_FETCH_ARCH "aarch64")
    elseif(TCVM_FETCH_ARCH STREQUAL "armv7")
      set(TCVM_FETCH_ARCH "armv7l")
    endif()

    set(TCVM_FETCH_INSTALL_DEV ON)
    set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/linux/${TCVM_FETCH_ARCH}/libskia.a")
  elseif(WIN32)
    set(TCVM_FETCH_PLATFORM "windows")
    if(CMAKE_VS_PLATFORM_NAME)
      set(TCVM_FETCH_ARCH "${CMAKE_VS_PLATFORM_NAME}")
    elseif(CMAKE_GENERATOR_PLATFORM)
      set(TCVM_FETCH_ARCH "${CMAKE_GENERATOR_PLATFORM}")
    elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(TCVM_FETCH_ARCH "x64")
    else()
      set(TCVM_FETCH_ARCH "x86")
    endif()

    if(TCVM_FETCH_ARCH STREQUAL "Win32")
      set(TCVM_FETCH_ARCH "x86")
    elseif(TCVM_FETCH_ARCH STREQUAL "ARM64")
      set(TCVM_FETCH_ARCH "arm64")
    endif()

    set(TCVM_FETCH_INSTALL_DEV ON)
    set(TCVM_SKIA_ARTIFACT "${TCVM_SKIA_DIR}/out/Release/windows/${TCVM_FETCH_ARCH}/libskia.lib")
  else()
    return()
  endif()

  if(NOT TCVM_FETCH_PLATFORM STREQUAL "wasm")
    tcvm_auto_fetch_skia_dependencies()
  endif()

  if(TCVM_FETCH_INSTALL_DEV)
    if(NOT EXISTS "${TCVM_SKIA_DIR}/include/core/SkCanvas.h" OR NOT EXISTS "${TCVM_SKIA_DIR}/src/gpu/gl/GrGLDefines.h")
      set(TCVM_FETCH_NEEDED ON)
    endif()
  endif()

  if(NOT EXISTS "${TCVM_SKIA_ARTIFACT}")
    set(TCVM_FETCH_NEEDED ON)
  endif()

  if(NOT TCVM_FETCH_NEEDED)
    return()
  endif()

  set(TCVM_FETCH_ARGS
    "${TCVM_FETCH_SCRIPT}"
    --platform "${TCVM_FETCH_PLATFORM}"
    --arch "${TCVM_FETCH_ARCH}"
  )

  if(TCVM_FETCH_INSTALL_DEV)
    list(APPEND TCVM_FETCH_ARGS --install-dev)
  endif()

  if(DEFINED SKIA_ARTIFACT_BASE_URL AND NOT SKIA_ARTIFACT_BASE_URL STREQUAL "")
    list(APPEND TCVM_FETCH_ARGS --base-url "${SKIA_ARTIFACT_BASE_URL}")
  endif()

  message(STATUS "Skia artifacts not found locally. Fetching ${SKIA_GITHUB_REPO}@${SKIA_RELEASE_TAG}/${TCVM_FETCH_PLATFORM}/${TCVM_FETCH_ARCH}...")
  execute_process(
    COMMAND
      "${TCVM_BASH_EXECUTABLE}" ${TCVM_FETCH_ARGS}
      --release-tag "${SKIA_RELEASE_TAG}"
      --github-repo "${SKIA_GITHUB_REPO}"
      --github-token-env "${SKIA_GITHUB_TOKEN_ENV}"
    WORKING_DIRECTORY "${TCVM_SKIA_DEP_DIR}"
    RESULT_VARIABLE TCVM_FETCH_RESULT
    OUTPUT_VARIABLE TCVM_FETCH_STDOUT
    ERROR_VARIABLE TCVM_FETCH_STDERR
  )

  if(NOT TCVM_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR
      "Failed to auto-fetch Skia.\n"
      "stdout:\n${TCVM_FETCH_STDOUT}\n"
      "stderr:\n${TCVM_FETCH_STDERR}"
    )
  endif()

  message(STATUS "${TCVM_FETCH_STDOUT}")
endfunction()
