# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

get_filename_component(TCVM_SDL3_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_SDL3_AUTOFETCH_DEP_DIR "${TCVM_SDL3_AUTOFETCH_DIR}/.." ABSOLUTE)
set(TCVM_SDL3_RELEASE_HELPER "${TCVM_SDL3_AUTOFETCH_DEP_DIR}/../cmake/DepotDependencyRelease.cmake")
if(EXISTS "${TCVM_SDL3_RELEASE_HELPER}")
  include("${TCVM_SDL3_RELEASE_HELPER}")
endif()

function(tcvm_auto_fetch_sdl3)
  if(WIN32)
    set(TCVM_SDL3_PLATFORM windows)
    set(TCVM_SDL3_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
    if(NOT TCVM_SDL3_WINDOWS_PLATFORM)
      set(TCVM_SDL3_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    string(TOLOWER "${TCVM_SDL3_WINDOWS_PLATFORM}" TCVM_SDL3_WINDOWS_PLATFORM)
    if(TCVM_SDL3_WINDOWS_PLATFORM STREQUAL "win32")
      set(TCVM_SDL3_ARCH x86)
    elseif(TCVM_SDL3_WINDOWS_PLATFORM STREQUAL "arm64")
      set(TCVM_SDL3_ARCH arm64)
    elseif(TCVM_SDL3_WINDOWS_PLATFORM STREQUAL "x64" OR CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(TCVM_SDL3_ARCH x64)
    else()
      message(FATAL_ERROR "Unsupported sdl3 Windows architecture: ${TCVM_SDL3_WINDOWS_PLATFORM}")
    endif()
  elseif(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" AND NOT CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone")
    set(TCVM_SDL3_PLATFORM macos)
    set(TCVM_SDL3_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(TCVM_SDL3_ARCH)
      list(LENGTH TCVM_SDL3_ARCH TCVM_SDL3_ARCH_COUNT)
      if(NOT TCVM_SDL3_ARCH_COUNT EQUAL 1)
        message(FATAL_ERROR "sdl3 auto-fetch expects one macOS architecture: ${TCVM_SDL3_ARCH}")
      endif()
      list(GET TCVM_SDL3_ARCH 0 TCVM_SDL3_ARCH)
    else()
      set(TCVM_SDL3_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    if(TCVM_SDL3_ARCH STREQUAL "aarch64")
      set(TCVM_SDL3_ARCH arm64)
    endif()
    if(NOT TCVM_SDL3_ARCH STREQUAL "arm64")
      message(FATAL_ERROR "Unsupported sdl3 macOS architecture: ${TCVM_SDL3_ARCH}")
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(TCVM_SDL3_PLATFORM linux)
    set(TCVM_SDL3_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(TCVM_SDL3_ARCH STREQUAL "amd64")
      set(TCVM_SDL3_ARCH x86_64)
    elseif(TCVM_SDL3_ARCH STREQUAL "arm64")
      set(TCVM_SDL3_ARCH aarch64)
    elseif(TCVM_SDL3_ARCH STREQUAL "arm" OR TCVM_SDL3_ARCH STREQUAL "armv7")
      set(TCVM_SDL3_ARCH armv7l)
    endif()
    if(NOT TCVM_SDL3_ARCH MATCHES "^(x86_64|armv7l|aarch64)$")
      message(FATAL_ERROR "Unsupported sdl3 Linux architecture: ${TCVM_SDL3_ARCH}")
    endif()
  else()
    message(FATAL_ERROR "Unsupported sdl3 target ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  set(TCVM_SDL3_DEFAULT_ROOT
    "${TCVM_SDL3_AUTOFETCH_DEP_DIR}/local/${TCVM_SDL3_PLATFORM}/${TCVM_SDL3_ARCH}")
  set(TCVM_SDL3_CUSTOM_ROOT OFF)
  if(DEFINED SDL3_DEPOT_ROOT AND NOT SDL3_DEPOT_ROOT STREQUAL TCVM_SDL3_DEFAULT_ROOT)
    set(TCVM_SDL3_CUSTOM_ROOT ON)
  else()
    set(SDL3_DEPOT_ROOT "${TCVM_SDL3_DEFAULT_ROOT}" CACHE PATH "Staged depot-tools SDL3 artifact" FORCE)
  endif()

  set(TCVM_SDL3_COMPLETE OFF)
  if(EXISTS "${SDL3_DEPOT_ROOT}/include/SDL3/SDL.h" AND
     EXISTS "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3/SDL3Config.cmake" AND
     EXISTS "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3/SDL3staticTargets.cmake" AND
     EXISTS "${SDL3_DEPOT_ROOT}/manifest.txt" AND
     (EXISTS "${SDL3_DEPOT_ROOT}/lib/libSDL3.a" OR
      EXISTS "${SDL3_DEPOT_ROOT}/lib/SDL3-static.lib" OR
      EXISTS "${SDL3_DEPOT_ROOT}/lib/SDL3.lib"))
    set(TCVM_SDL3_COMPLETE ON)
  endif()
  if(TCVM_SDL3_COMPLETE)
    set(SDL3_DIR "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3" CACHE PATH
      "Depot-tools SDL3 config directory" FORCE)
    return()
  endif()
  if(TCVM_SDL3_CUSTOM_ROOT)
    message(FATAL_ERROR "Explicit SDL3_DEPOT_ROOT is incomplete: ${SDL3_DEPOT_ROOT}")
  endif()

  if(NOT DEFINED SDL3_RELEASE_TAG AND DEFINED ENV{SDL3_RELEASE_TAG})
    set(SDL3_RELEASE_TAG "$ENV{SDL3_RELEASE_TAG}")
  elseif(NOT DEFINED SDL3_RELEASE_TAG)
    if(COMMAND tcvm_get_dependency_release)
      tcvm_get_dependency_release(sdl3 SDL3_RELEASE_TAG "")
    else()
      set(SDL3_RELEASE_TAG "")
    endif()
  endif()
  if(NOT SDL3_RELEASE_TAG)
    message(FATAL_ERROR
      "No sdl3 release is pinned in deps.yml. Stage SDL3_DEPOT_ROOT locally or set SDL3_RELEASE_TAG for an explicit release handoff.")
  endif()

  if(NOT DEFINED SDL3_GITHUB_REPO AND DEFINED ENV{SDL3_GITHUB_REPO})
    set(SDL3_GITHUB_REPO "$ENV{SDL3_GITHUB_REPO}")
  elseif(NOT DEFINED SDL3_GITHUB_REPO)
    set(SDL3_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()
  if(NOT DEFINED SDL3_GITHUB_TOKEN_ENV AND DEFINED ENV{SDL3_GITHUB_TOKEN_ENV})
    set(SDL3_GITHUB_TOKEN_ENV "$ENV{SDL3_GITHUB_TOKEN_ENV}")
  elseif(NOT DEFINED SDL3_GITHUB_TOKEN_ENV)
    set(SDL3_GITHUB_TOKEN_ENV SDL3_GITHUB_TOKEN)
  endif()

  find_program(TCVM_SDL3_BASH bash)
  if(NOT TCVM_SDL3_BASH)
    message(FATAL_ERROR "Unable to auto-fetch sdl3 because bash was not found")
  endif()
  execute_process(
    COMMAND "${TCVM_SDL3_BASH}" "${TCVM_SDL3_AUTOFETCH_DEP_DIR}/fetch.sh"
      --platform "${TCVM_SDL3_PLATFORM}"
      --arch "${TCVM_SDL3_ARCH}"
      --release-tag "${SDL3_RELEASE_TAG}"
      --github-repo "${SDL3_GITHUB_REPO}"
      --github-token-env "${SDL3_GITHUB_TOKEN_ENV}"
      --dest "${TCVM_SDL3_AUTOFETCH_DEP_DIR}/local"
    WORKING_DIRECTORY "${TCVM_SDL3_AUTOFETCH_DEP_DIR}"
    RESULT_VARIABLE TCVM_SDL3_FETCH_RESULT
    OUTPUT_VARIABLE TCVM_SDL3_FETCH_STDOUT
    ERROR_VARIABLE TCVM_SDL3_FETCH_STDERR
  )
  if(NOT TCVM_SDL3_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR
      "Failed to auto-fetch sdl3.\nstdout:\n${TCVM_SDL3_FETCH_STDOUT}\nstderr:\n${TCVM_SDL3_FETCH_STDERR}")
  endif()
  if(NOT EXISTS "${SDL3_DEPOT_ROOT}/include/SDL3/SDL.h" OR
     NOT EXISTS "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3/SDL3Config.cmake")
    message(FATAL_ERROR "Fetched sdl3 artifact is incomplete: ${SDL3_DEPOT_ROOT}")
  endif()
  set(SDL3_DIR "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3" CACHE PATH
    "Depot-tools SDL3 config directory" FORCE)
  message(STATUS "${TCVM_SDL3_FETCH_STDOUT}")
endfunction()
