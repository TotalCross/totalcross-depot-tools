# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

get_filename_component(SDL3_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

if(NOT DEFINED SDL3_DEPOT_ROOT)
  if(WIN32)
    set(SDL3_DEPOT_PLATFORM windows)
    set(SDL3_DEPOT_ARCH "${CMAKE_VS_PLATFORM_NAME}")
    if(NOT SDL3_DEPOT_ARCH)
      set(SDL3_DEPOT_ARCH "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    string(TOLOWER "${SDL3_DEPOT_ARCH}" SDL3_DEPOT_ARCH)
    if(SDL3_DEPOT_ARCH STREQUAL "win32")
      set(SDL3_DEPOT_ARCH x86)
    elseif(SDL3_DEPOT_ARCH STREQUAL "arm64")
      set(SDL3_DEPOT_ARCH arm64)
    elseif(SDL3_DEPOT_ARCH STREQUAL "x64" OR CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(SDL3_DEPOT_ARCH x64)
    else()
      set(SDL3_DEPOT_ARCH x86)
    endif()
  elseif(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" AND NOT CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone")
    set(SDL3_DEPOT_PLATFORM macos)
    set(SDL3_DEPOT_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    if(SDL3_DEPOT_ARCH)
      list(GET SDL3_DEPOT_ARCH 0 SDL3_DEPOT_ARCH)
    else()
      set(SDL3_DEPOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    if(SDL3_DEPOT_ARCH STREQUAL "aarch64")
      set(SDL3_DEPOT_ARCH arm64)
    endif()
  elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(SDL3_DEPOT_PLATFORM linux)
    set(SDL3_DEPOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    if(SDL3_DEPOT_ARCH STREQUAL "amd64")
      set(SDL3_DEPOT_ARCH x86_64)
    elseif(SDL3_DEPOT_ARCH STREQUAL "arm64")
      set(SDL3_DEPOT_ARCH aarch64)
    elseif(SDL3_DEPOT_ARCH STREQUAL "arm" OR SDL3_DEPOT_ARCH STREQUAL "armv7")
      set(SDL3_DEPOT_ARCH armv7l)
    endif()
  else()
    message(FATAL_ERROR "Unsupported sdl3 target ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  set(SDL3_DEPOT_ROOT
    "${SDL3_DEPENDENCY_DIR}/local/${SDL3_DEPOT_PLATFORM}/${SDL3_DEPOT_ARCH}"
    CACHE PATH "Staged depot-tools SDL3 artifact")
endif()

get_filename_component(SDL3_DEPOT_ROOT "${SDL3_DEPOT_ROOT}" ABSOLUTE)
set(SDL3_DEPOT_HEADER "")
if(EXISTS "${SDL3_DEPOT_ROOT}/include/SDL3/SDL.h")
  set(SDL3_DEPOT_HEADER "${SDL3_DEPOT_ROOT}/include/SDL3/SDL.h")
endif()
set(SDL3_DEPOT_CONFIG "")
if(EXISTS "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3/SDL3Config.cmake")
  set(SDL3_DEPOT_CONFIG "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3/SDL3Config.cmake")
endif()
set(SDL3_DEPOT_STATIC_LIBRARY "")
foreach(SDL3_DEPOT_LIBRARY_CANDIDATE
    "${SDL3_DEPOT_ROOT}/lib/libSDL3.a"
    "${SDL3_DEPOT_ROOT}/lib/SDL3-static.lib"
    "${SDL3_DEPOT_ROOT}/lib/SDL3.lib")
  if(EXISTS "${SDL3_DEPOT_LIBRARY_CANDIDATE}")
    set(SDL3_DEPOT_STATIC_LIBRARY "${SDL3_DEPOT_LIBRARY_CANDIDATE}")
    break()
  endif()
endforeach()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDL3
  REQUIRED_VARS SDL3_DEPOT_HEADER SDL3_DEPOT_CONFIG SDL3_DEPOT_STATIC_LIBRARY)
if(NOT SDL3_FOUND)
  return()
endif()

set(SDL3_DIR "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3" CACHE PATH
  "Depot-tools SDL3 config directory" FORCE)
include("${SDL3_DEPOT_CONFIG}")

if(NOT TARGET SDL3::SDL3-static OR NOT TARGET SDL3::SDL3 OR
   NOT TARGET SDL3::Headers)
  message(FATAL_ERROR
    "Depot sdl3 config must define SDL3::Headers, SDL3::SDL3-static, and SDL3::SDL3: ${SDL3_DEPOT_CONFIG}")
endif()

function(_tc_sdl3_require_depot_path candidate description)
  if(NOT candidate)
    message(FATAL_ERROR "Depot sdl3 ${description} is empty")
  endif()
  if(candidate MATCHES "^\\$<")
    message(FATAL_ERROR "Depot sdl3 ${description} is not a concrete path: ${candidate}")
  endif()
  get_filename_component(TC_SDL3_CANDIDATE_REAL "${candidate}" REALPATH)
  string(FIND "${TC_SDL3_CANDIDATE_REAL}" "${SDL3_DEPOT_ROOT}/" TC_SDL3_DEPOT_INDEX)
  if(NOT TC_SDL3_DEPOT_INDEX EQUAL 0)
    message(FATAL_ERROR
      "Depot sdl3 ${description} escapes ${SDL3_DEPOT_ROOT}: ${TC_SDL3_CANDIDATE_REAL}")
  endif()
endfunction()

get_target_property(SDL3_DEPOT_IMPORTED_CONFIGURATIONS
  SDL3::SDL3-static IMPORTED_CONFIGURATIONS)
foreach(SDL3_DEPOT_CONFIGURATION IN LISTS SDL3_DEPOT_IMPORTED_CONFIGURATIONS)
  get_target_property(SDL3_DEPOT_IMPORTED_LOCATION SDL3::SDL3-static
    "IMPORTED_LOCATION_${SDL3_DEPOT_CONFIGURATION}")
  _tc_sdl3_require_depot_path("${SDL3_DEPOT_IMPORTED_LOCATION}"
    "SDL3::SDL3-static ${SDL3_DEPOT_CONFIGURATION} location")
endforeach()
get_target_property(SDL3_DEPOT_INCLUDE_DIRECTORIES
  SDL3::Headers INTERFACE_INCLUDE_DIRECTORIES)
if(NOT SDL3_DEPOT_INCLUDE_DIRECTORIES)
  message(FATAL_ERROR "Depot SDL3::Headers has no include directory")
endif()
foreach(SDL3_DEPOT_INCLUDE_DIRECTORY IN LISTS SDL3_DEPOT_INCLUDE_DIRECTORIES)
  _tc_sdl3_require_depot_path("${SDL3_DEPOT_INCLUDE_DIRECTORY}"
    "SDL3::Headers include directory")
endforeach()

get_target_property(SDL3_DEPOT_GENERIC_ALIAS SDL3::SDL3 ALIASED_TARGET)
get_target_property(SDL3_DEPOT_GENERIC_LINKS SDL3::SDL3 INTERFACE_LINK_LIBRARIES)
if(NOT SDL3_DEPOT_GENERIC_ALIAS STREQUAL "SDL3::SDL3-static" AND
   NOT "SDL3::SDL3-static" IN_LIST SDL3_DEPOT_GENERIC_LINKS)
  message(FATAL_ERROR
    "Depot SDL3::SDL3 must be backed by SDL3::SDL3-static: ${SDL3_DEPOT_CONFIG}")
endif()

set_property(TARGET SDL3::SDL3-static PROPERTY TC_SDL3_DEPOT_ROOT "${SDL3_DEPOT_ROOT}")
set(SDL3_DEPOT_RESOLVED_ROOT "${SDL3_DEPOT_ROOT}")
message(STATUS "Found depot sdl3: ${SDL3_DEPOT_ROOT}")
