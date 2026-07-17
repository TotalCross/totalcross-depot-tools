# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
#

get_filename_component(JPEG_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(JPEG_LOCAL_ROOT "${JPEG_DEPENDENCY_DIR}/local")

if(DEFINED ANDROID_ABI)
  set(JPEG_PLATFORM "android")
  set(JPEG_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
  if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
    set(JPEG_PLATFORM "ios-simulator")
  else()
    set(JPEG_PLATFORM "ios")
  endif()
  set(JPEG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(JPEG_ARCH)
    list(GET JPEG_ARCH 0 JPEG_ARCH)
  else()
    set(JPEG_ARCH "arm64")
  endif()
  if(JPEG_ARCH STREQUAL "aarch64")
    set(JPEG_ARCH "arm64")
  endif()
elseif(WIN32)
  set(JPEG_PLATFORM "windows")
  set(JPEG_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT JPEG_WINDOWS_PLATFORM)
    set(JPEG_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${JPEG_WINDOWS_PLATFORM}" JPEG_WINDOWS_PLATFORM_LOWER)
  if(JPEG_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(JPEG_ARCH "x86")
  elseif(JPEG_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(JPEG_ARCH "x64")
  elseif(JPEG_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(JPEG_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(JPEG_ARCH "x64")
  else()
    set(JPEG_ARCH "x86")
  endif()
elseif(APPLE)
  set(JPEG_PLATFORM "macos")
  set(JPEG_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(JPEG_ARCH)
    list(GET JPEG_ARCH 0 JPEG_ARCH)
  else()
    set(JPEG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(JPEG_ARCH STREQUAL "amd64")
    set(JPEG_ARCH "x86_64")
  elseif(JPEG_ARCH STREQUAL "aarch64")
    set(JPEG_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(JPEG_PLATFORM "linux")
  set(JPEG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(JPEG_ARCH STREQUAL "amd64")
    set(JPEG_ARCH "x86_64")
  elseif(JPEG_ARCH STREQUAL "arm64")
    set(JPEG_ARCH "aarch64")
  elseif(JPEG_ARCH STREQUAL "arm" OR JPEG_ARCH STREQUAL "armv7")
    set(JPEG_ARCH "armv7l")
  endif()
endif()

set(JPEG_DEFAULT_DIR "${JPEG_LOCAL_ROOT}/${JPEG_PLATFORM}/${JPEG_ARCH}")

if(NOT DEFINED JPEG_DIR)
  set(JPEG_DIR "${JPEG_DEFAULT_DIR}" CACHE PATH "libjpeg-turbo prebuilt directory")
endif()

foreach(JPEG_CACHED_VAR JPEG_INCLUDE_DIR JPEG_LIBRARY TurboJPEG_LIBRARY)
  if(DEFINED ${JPEG_CACHED_VAR})
    string(FIND "${${JPEG_CACHED_VAR}}" "${JPEG_DIR}" JPEG_CACHED_VAR_DEPOT_INDEX)
    if("${${JPEG_CACHED_VAR}}" MATCHES "-NOTFOUND$" OR NOT JPEG_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${JPEG_CACHED_VAR} CACHE)
      unset(${JPEG_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(JPEG_INCLUDE_DIR
  NAMES jpeglib.h turbojpeg.h
  HINTS "${JPEG_DIR}/include"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(JPEG_LIBRARY
  NAMES jpeg jpeg-static libjpeg
  HINTS "${JPEG_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(TurboJPEG_LIBRARY
  NAMES turbojpeg turbojpeg-static libturbojpeg
  HINTS "${JPEG_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(JPEG
  REQUIRED_VARS JPEG_INCLUDE_DIR JPEG_LIBRARY TurboJPEG_LIBRARY
)

if(JPEG_FOUND)
  if(NOT TARGET JPEG::JPEG)
    add_library(JPEG::JPEG UNKNOWN IMPORTED)
    set_target_properties(JPEG::JPEG PROPERTIES
      IMPORTED_LOCATION "${JPEG_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${JPEG_INCLUDE_DIR}"
    )
  endif()

  if(NOT TARGET TurboJPEG::TurboJPEG)
    add_library(TurboJPEG::TurboJPEG UNKNOWN IMPORTED)
    set_target_properties(TurboJPEG::TurboJPEG PROPERTIES
      IMPORTED_LOCATION "${TurboJPEG_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${JPEG_INCLUDE_DIR}"
    )
  endif()
endif()
