# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

get_filename_component(SDL2_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

if(NOT DEFINED SDL2_DEPOT_ROOT)
  if(WIN32)
    set(SDL2_DEPOT_PLATFORM windows)
    set(SDL2_DEPOT_ARCH "${CMAKE_VS_PLATFORM_NAME}")
    if(NOT SDL2_DEPOT_ARCH)
      set(SDL2_DEPOT_ARCH "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    string(TOLOWER "${SDL2_DEPOT_ARCH}" SDL2_DEPOT_ARCH)
    if(SDL2_DEPOT_ARCH STREQUAL "win32")
      set(SDL2_DEPOT_ARCH x86)
    elseif(SDL2_DEPOT_ARCH STREQUAL "arm64")
      set(SDL2_DEPOT_ARCH arm64)
    elseif(SDL2_DEPOT_ARCH STREQUAL "x64" OR CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(SDL2_DEPOT_ARCH x64)
    else()
      set(SDL2_DEPOT_ARCH x86)
    endif()
  elseif(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" AND NOT CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone")
    set(SDL2_DEPOT_PLATFORM macos)
    set(SDL2_DEPOT_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(SDL2_DEPOT_ARCH)
      list(GET SDL2_DEPOT_ARCH 0 SDL2_DEPOT_ARCH)
    else()
      set(SDL2_DEPOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    if(SDL2_DEPOT_ARCH STREQUAL "aarch64")
      set(SDL2_DEPOT_ARCH arm64)
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(SDL2_DEPOT_PLATFORM linux)
    set(SDL2_DEPOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(SDL2_DEPOT_ARCH STREQUAL "amd64")
      set(SDL2_DEPOT_ARCH x86_64)
    elseif(SDL2_DEPOT_ARCH STREQUAL "arm64")
      set(SDL2_DEPOT_ARCH aarch64)
    elseif(SDL2_DEPOT_ARCH STREQUAL "arm" OR SDL2_DEPOT_ARCH STREQUAL "armv7")
      set(SDL2_DEPOT_ARCH armv7l)
    endif()
  else()
    message(FATAL_ERROR "Unsupported sdl2 target ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  set(SDL2_DEPOT_ROOT
    "${SDL2_DEPENDENCY_DIR}/local/${SDL2_DEPOT_PLATFORM}/${SDL2_DEPOT_ARCH}"
    CACHE PATH "Staged depot-tools SDL2 artifact")
endif()

get_filename_component(SDL2_DEPOT_ROOT "${SDL2_DEPOT_ROOT}" ABSOLUTE)
set(SDL2_DEPOT_HEADER "")
if(EXISTS "${SDL2_DEPOT_ROOT}/include/SDL2/SDL.h")
  set(SDL2_DEPOT_HEADER "${SDL2_DEPOT_ROOT}/include/SDL2/SDL.h")
endif()
set(SDL2_DEPOT_CONFIG "")
if(EXISTS "${SDL2_DEPOT_ROOT}/lib/cmake/SDL2/SDL2Config.cmake")
  set(SDL2_DEPOT_CONFIG "${SDL2_DEPOT_ROOT}/lib/cmake/SDL2/SDL2Config.cmake")
endif()
set(SDL2_DEPOT_STATIC_LIBRARY "")
foreach(SDL2_DEPOT_LIBRARY_CANDIDATE
    "${SDL2_DEPOT_ROOT}/lib/libSDL2.a"
    "${SDL2_DEPOT_ROOT}/lib/SDL2-static.lib"
    "${SDL2_DEPOT_ROOT}/lib/SDL2.lib")
  if(EXISTS "${SDL2_DEPOT_LIBRARY_CANDIDATE}")
    set(SDL2_DEPOT_STATIC_LIBRARY "${SDL2_DEPOT_LIBRARY_CANDIDATE}")
    break()
  endif()
endforeach()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDL2
  REQUIRED_VARS SDL2_DEPOT_HEADER SDL2_DEPOT_CONFIG SDL2_DEPOT_STATIC_LIBRARY)
if(NOT SDL2_FOUND)
  return()
endif()

set(SDL2_DIR "${SDL2_DEPOT_ROOT}/lib/cmake/SDL2" CACHE PATH
  "Depot-tools SDL2 config directory" FORCE)
include("${SDL2_DEPOT_CONFIG}")

if(NOT TARGET SDL2::SDL2-static OR NOT TARGET SDL2::SDL2)
  message(FATAL_ERROR
    "Depot sdl2 config must define SDL2::SDL2-static and SDL2::SDL2: ${SDL2_DEPOT_CONFIG}")
endif()

function(_tc_sdl2_require_depot_path candidate description)
  if(NOT candidate)
    message(FATAL_ERROR "Depot sdl2 ${description} is empty")
  endif()
  if(candidate MATCHES "^\\$<")
    message(FATAL_ERROR "Depot sdl2 ${description} is not a concrete path: ${candidate}")
  endif()
  get_filename_component(TC_SDL2_CANDIDATE_REAL "${candidate}" REALPATH)
  string(FIND "${TC_SDL2_CANDIDATE_REAL}" "${SDL2_DEPOT_ROOT}/" TC_SDL2_DEPOT_INDEX)
  if(NOT TC_SDL2_DEPOT_INDEX EQUAL 0)
    message(FATAL_ERROR
      "Depot sdl2 ${description} escapes ${SDL2_DEPOT_ROOT}: ${TC_SDL2_CANDIDATE_REAL}")
  endif()
endfunction()

get_target_property(SDL2_DEPOT_IMPORTED_CONFIGURATIONS
  SDL2::SDL2-static IMPORTED_CONFIGURATIONS)
foreach(SDL2_DEPOT_CONFIGURATION IN LISTS SDL2_DEPOT_IMPORTED_CONFIGURATIONS)
  get_target_property(SDL2_DEPOT_IMPORTED_LOCATION SDL2::SDL2-static
    "IMPORTED_LOCATION_${SDL2_DEPOT_CONFIGURATION}")
  _tc_sdl2_require_depot_path("${SDL2_DEPOT_IMPORTED_LOCATION}"
    "SDL2::SDL2-static ${SDL2_DEPOT_CONFIGURATION} location")
endforeach()
get_target_property(SDL2_DEPOT_INCLUDE_DIRECTORIES
  SDL2::SDL2-static INTERFACE_INCLUDE_DIRECTORIES)
foreach(SDL2_DEPOT_INCLUDE_DIRECTORY IN LISTS SDL2_DEPOT_INCLUDE_DIRECTORIES)
  _tc_sdl2_require_depot_path("${SDL2_DEPOT_INCLUDE_DIRECTORY}"
    "SDL2::SDL2-static include directory")
endforeach()

set_property(TARGET SDL2::SDL2-static PROPERTY TC_SDL2_DEPOT_ROOT "${SDL2_DEPOT_ROOT}")
set(SDL2_DEPOT_RESOLVED_ROOT "${SDL2_DEPOT_ROOT}")
message(STATUS "Found depot sdl2: ${SDL2_DEPOT_ROOT}")
