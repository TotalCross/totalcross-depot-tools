# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
#

get_filename_component(ZLIB_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(ZLIB_LOCAL_ROOT "${ZLIB_DEPENDENCY_DIR}/local")

if(DEFINED ANDROID_ABI)
  set(ZLIB_PLATFORM "android")
  set(ZLIB_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
  if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
    set(ZLIB_PLATFORM "ios-simulator")
  else()
    set(ZLIB_PLATFORM "ios")
  endif()
  set(ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(ZLIB_ARCH)
    list(GET ZLIB_ARCH 0 ZLIB_ARCH)
  else()
    set(ZLIB_ARCH "arm64")
  endif()
  if(ZLIB_ARCH STREQUAL "aarch64")
    set(ZLIB_ARCH "arm64")
  endif()
elseif(WIN32)
  set(ZLIB_PLATFORM "windows")
  set(ZLIB_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT ZLIB_WINDOWS_PLATFORM)
    set(ZLIB_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${ZLIB_WINDOWS_PLATFORM}" ZLIB_WINDOWS_PLATFORM_LOWER)
  if(ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(ZLIB_ARCH "x86")
  elseif(ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(ZLIB_ARCH "x64")
  elseif(ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(ZLIB_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(ZLIB_ARCH "x64")
  else()
    set(ZLIB_ARCH "x86")
  endif()
elseif(APPLE)
  set(ZLIB_PLATFORM "macos")
  set(ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(ZLIB_ARCH)
    list(GET ZLIB_ARCH 0 ZLIB_ARCH)
  else()
    set(ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(ZLIB_ARCH STREQUAL "amd64")
    set(ZLIB_ARCH "x86_64")
  elseif(ZLIB_ARCH STREQUAL "aarch64")
    set(ZLIB_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(ZLIB_PLATFORM "linux")
  set(ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(ZLIB_ARCH STREQUAL "amd64")
    set(ZLIB_ARCH "x86_64")
  elseif(ZLIB_ARCH STREQUAL "arm64")
    set(ZLIB_ARCH "aarch64")
  elseif(ZLIB_ARCH STREQUAL "arm" OR ZLIB_ARCH STREQUAL "armv7")
    set(ZLIB_ARCH "armv7l")
  endif()
endif()

set(ZLIB_DEFAULT_DIR "${ZLIB_LOCAL_ROOT}/${ZLIB_PLATFORM}/${ZLIB_ARCH}")

if(NOT DEFINED ZLIB_DIR)
  set(ZLIB_DIR "${ZLIB_DEFAULT_DIR}" CACHE PATH "zlib-ng prebuilt directory")
endif()

foreach(ZLIB_CACHED_VAR ZLIB_INCLUDE_DIR ZLIB_LIBRARY)
  if(DEFINED ${ZLIB_CACHED_VAR})
    string(FIND "${${ZLIB_CACHED_VAR}}" "${ZLIB_DIR}" ZLIB_CACHED_VAR_DEPOT_INDEX)
    if("${${ZLIB_CACHED_VAR}}" MATCHES "-NOTFOUND$" OR NOT ZLIB_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${ZLIB_CACHED_VAR} CACHE)
      unset(${ZLIB_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(ZLIB_INCLUDE_DIR
  NAMES zlib.h
  HINTS "${ZLIB_DIR}/include"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(ZLIB_LIBRARY
  NAMES z zlib zlibstatic
  HINTS "${ZLIB_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ZLIB
  REQUIRED_VARS ZLIB_INCLUDE_DIR ZLIB_LIBRARY
)

if(ZLIB_FOUND AND NOT TARGET ZLIB::ZLIB)
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED)
  set_target_properties(ZLIB::ZLIB PROPERTIES
    IMPORTED_LOCATION "${ZLIB_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
  )
endif()
