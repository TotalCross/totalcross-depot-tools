# Copyright (C) 2000-2013 SuperWaba Ltda.
# Copyright (C) 2014-2020 TotalCross Global Mobile Platform Ltda.
#
# SPDX-License-Identifier: LGPL-2.1-only

include(FindPackageHandleStandardArgs)

get_filename_component(SKIA_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(SKIA_LOCAL_ROOT "${SKIA_DEPENDENCY_DIR}/local")

if(NOT DEFINED SKIA_DIR)
  set(SKIA_DIR "${SKIA_LOCAL_ROOT}" CACHE PATH "Skia prebuilt directory")
endif()

if(DEFINED ANDROID_ABI)
  set(SKIA_PLATFORM "android")
  set(SKIA_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "iphone"))
  if(CMAKE_OSX_SYSROOT MATCHES "iphonesimulator")
    set(SKIA_PLATFORM "ios-simulator")
  else()
    set(SKIA_PLATFORM "ios")
  endif()
  set(SKIA_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(SKIA_ARCH)
    list(LENGTH SKIA_ARCH SKIA_ARCH_LEN)
    if(SKIA_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "Skia expects a single iOS architecture, got: ${SKIA_ARCH}")
    endif()
    list(GET SKIA_ARCH 0 SKIA_ARCH)
  else()
    set(SKIA_ARCH "arm64")
  endif()
  if(SKIA_ARCH STREQUAL "aarch64")
    set(SKIA_ARCH "arm64")
  endif()
elseif(WIN32)
  set(SKIA_PLATFORM "windows")
  set(SKIA_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT SKIA_WINDOWS_PLATFORM)
    set(SKIA_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${SKIA_WINDOWS_PLATFORM}" SKIA_WINDOWS_PLATFORM_LOWER)
  if(SKIA_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(SKIA_ARCH "x86")
  elseif(SKIA_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(SKIA_ARCH "x64")
  elseif(SKIA_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(SKIA_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(SKIA_ARCH "x64")
  else()
    set(SKIA_ARCH "x86")
  endif()
elseif(APPLE)
  set(SKIA_PLATFORM "macos")
  set(SKIA_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(SKIA_ARCH)
    list(LENGTH SKIA_ARCH SKIA_ARCH_LEN)
    if(SKIA_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "Skia expects a single macOS architecture, got: ${SKIA_ARCH}")
    endif()
    list(GET SKIA_ARCH 0 SKIA_ARCH)
  else()
    set(SKIA_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(SKIA_ARCH STREQUAL "amd64")
    set(SKIA_ARCH "x86_64")
  elseif(SKIA_ARCH STREQUAL "aarch64")
    set(SKIA_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(SKIA_PLATFORM "linux")
  set(SKIA_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(SKIA_ARCH STREQUAL "amd64")
    set(SKIA_ARCH "x86_64")
  elseif(SKIA_ARCH STREQUAL "arm64")
    set(SKIA_ARCH "aarch64")
  elseif(SKIA_ARCH STREQUAL "arm" OR SKIA_ARCH STREQUAL "armv7")
    set(SKIA_ARCH "armv7l")
  endif()
endif()

if(NOT SKIA_PLATFORM OR NOT SKIA_ARCH)
  message(FATAL_ERROR "Unsupported Skia platform '${CMAKE_SYSTEM_NAME}' / '${CMAKE_SYSTEM_PROCESSOR}'")
endif()

set(SKIA_LIBRARY_DIRS "${SKIA_DIR}/out/Release/${SKIA_PLATFORM}/${SKIA_ARCH}" CACHE PATH "Skia library directory" FORCE)

foreach(SKIA_CACHED_VAR
    SKIA_CONFIG_INCLUDE_DIR
    SKIA_CORE_INCLUDE_DIR
    SKIA_UTILS_INCLUDE_DIR
    SKIA_EFFECTS_INCLUDE_DIR
    SKIA_GPU_INCLUDE_DIR
    SKIA_GPU2_INCLUDE_DIR
    SKIA_LIBRARY
    SKIA_LIBRARY_DIRS
    SKIA_LIBRARIES)
  if(DEFINED ${SKIA_CACHED_VAR})
    string(FIND "${${SKIA_CACHED_VAR}}" "${SKIA_DIR}" SKIA_CACHED_VAR_DEPOT_INDEX)
    if("${${SKIA_CACHED_VAR}}" MATCHES "-NOTFOUND$" OR NOT SKIA_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${SKIA_CACHED_VAR} CACHE)
      unset(${SKIA_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(
  SKIA_CONFIG_INCLUDE_DIR
  SkUserConfig.h
  HINTS "${SKIA_DIR}/include/config"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
  )
find_path(
  SKIA_CORE_INCLUDE_DIR
  SkCanvas.h
  HINTS "${SKIA_DIR}/include/core"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
  )
find_path(
  SKIA_UTILS_INCLUDE_DIR
  SkRandom.h
  HINTS "${SKIA_DIR}/include/utils"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
  )
find_path(
  SKIA_EFFECTS_INCLUDE_DIR
  SkImageSource.h
  HINTS "${SKIA_DIR}/include/effects"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
  )
find_path(
  SKIA_GPU_INCLUDE_DIR
  GrContext.h
  HINTS "${SKIA_DIR}/include/gpu"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
  )
find_path(
  SKIA_GPU2_INCLUDE_DIR
  gl/GrGLDefines.h
  HINTS "${SKIA_DIR}/src/gpu"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
  )

set(SKIA_INCLUDE_DIRS
  "${SKIA_DIR}"
  "${SKIA_CONFIG_INCLUDE_DIR}"
  "${SKIA_CORE_INCLUDE_DIR}"
  "${SKIA_UTILS_INCLUDE_DIR}"
  "${SKIA_EFFECTS_INCLUDE_DIR}"
  "${SKIA_GPU_INCLUDE_DIR}"
  "${SKIA_GPU2_INCLUDE_DIR}"
)
list(REMOVE_DUPLICATES SKIA_INCLUDE_DIRS)

if(WIN32)
  find_library(SKIA_LIBRARY
    NAMES libskia skia
    HINTS "${SKIA_LIBRARY_DIRS}"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )
else()
  find_library(SKIA_LIBRARY
    NAMES skia libskia
    HINTS "${SKIA_LIBRARY_DIRS}"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )
endif()

set(SKIA_LIBRARIES "${SKIA_LIBRARY}" CACHE PATH "Skia library" FORCE)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND SKIA_LIBRARY)
  set(SKIA_LIBRARIES -Wl,--start-group "${SKIA_LIBRARY}" -Wl,--end-group CACHE STRING "Skia libraries" FORCE)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Skia
  REQUIRED_VARS
    SKIA_LIBRARY
    SKIA_CONFIG_INCLUDE_DIR
    SKIA_CORE_INCLUDE_DIR
    SKIA_GPU2_INCLUDE_DIR
)

if(Skia_FOUND AND NOT TARGET Skia::Skia)
  add_library(Skia::Skia UNKNOWN IMPORTED)
  set_target_properties(Skia::Skia PROPERTIES
    IMPORTED_LOCATION "${SKIA_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${SKIA_INCLUDE_DIRS}"
  )
endif()
