# Copyright (C) 2026 Amalgam Solucoes em TI Ltda
#
# SPDX-License-Identifier: LGPL-2.1-only

get_filename_component(PNG_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(PNG_LOCAL_ROOT "${PNG_DEPENDENCY_DIR}/local")

if(DEFINED ANDROID_ABI)
  set(PNG_PLATFORM "android")
  set(PNG_ARCH "${ANDROID_ABI}")
elseif(CMAKE_GENERATOR STREQUAL Xcode)
  set(PNG_PLATFORM "ios")
  set(PNG_ARCH "arm64")
elseif(WIN32)
  set(PNG_PLATFORM "windows")
  if(CMAKE_GENERATOR_PLATFORM MATCHES "x64")
    set(PNG_ARCH "x86_64")
  else()
    set(PNG_ARCH "x86")
  endif()
elseif(APPLE)
  set(PNG_PLATFORM "macos")
  set(PNG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(PNG_ARCH)
    list(GET PNG_ARCH 0 PNG_ARCH)
  else()
    set(PNG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(PNG_ARCH STREQUAL "amd64")
    set(PNG_ARCH "x86_64")
  elseif(PNG_ARCH STREQUAL "aarch64")
    set(PNG_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(PNG_PLATFORM "linux")
  set(PNG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(PNG_ARCH STREQUAL "amd64")
    set(PNG_ARCH "x86_64")
  elseif(PNG_ARCH STREQUAL "arm64")
    set(PNG_ARCH "aarch64")
  elseif(PNG_ARCH STREQUAL "arm" OR PNG_ARCH STREQUAL "armv7")
    set(PNG_ARCH "armv7l")
  endif()
endif()

set(PNG_DEFAULT_DIR "${PNG_LOCAL_ROOT}/${PNG_PLATFORM}/${PNG_ARCH}")

if(NOT DEFINED PNG_DIR)
  set(PNG_DIR "${PNG_DEFAULT_DIR}" CACHE PATH "libpng prebuilt directory")
endif()

foreach(PNG_CACHED_VAR PNG_INCLUDE_DIR PNG_LIBRARY)
  if(DEFINED ${PNG_CACHED_VAR})
    string(FIND "${${PNG_CACHED_VAR}}" "${PNG_DIR}" PNG_CACHED_VAR_DEPOT_INDEX)
    if("${${PNG_CACHED_VAR}}" MATCHES "-NOTFOUND$" OR NOT PNG_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${PNG_CACHED_VAR} CACHE)
      unset(${PNG_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(PNG_INCLUDE_DIR
  NAMES png.h
  HINTS "${PNG_DIR}/include"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(PNG_LIBRARY
  NAMES png png16 libpng libpng16
  HINTS "${PNG_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

set(PNG_ZLIB_MODULE_DIR "${PNG_DEPENDENCY_DIR}/../zlib-ng/cmake")
if(EXISTS "${PNG_ZLIB_MODULE_DIR}/FindZLIB.cmake")
  list(APPEND CMAKE_MODULE_PATH "${PNG_ZLIB_MODULE_DIR}")
endif()
find_package(ZLIB QUIET MODULE)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PNG
  REQUIRED_VARS PNG_INCLUDE_DIR PNG_LIBRARY
)

if(PNG_FOUND AND NOT TARGET PNG::PNG)
  add_library(PNG::PNG UNKNOWN IMPORTED)
  set_target_properties(PNG::PNG PROPERTIES
    IMPORTED_LOCATION "${PNG_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${PNG_INCLUDE_DIR}"
  )
  if(TARGET ZLIB::ZLIB)
    set_target_properties(PNG::PNG PROPERTIES
      INTERFACE_LINK_LIBRARIES "ZLIB::ZLIB"
    )
  endif()
endif()
