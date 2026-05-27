# Copyright (C) 2000-2013 SuperWaba Ltda.
# Copyright (C) 2014-2020 TotalCross Global Mobile Platform Ltda.
#
# SPDX-License-Identifier: LGPL-2.1-only

# Skia as graphics backend.
# Together with its dependencies.
# This should be a custom build from source, put into /opt/build/skia
include(FindPackageHandleStandardArgs)

get_filename_component(SKIA_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
SET ( SKIA_DIR "${SKIA_DEPENDENCY_DIR}/local" CACHE PATH "Skia directory")

foreach(SKIA_CACHED_VAR
    SKIA_CONFIG_INCLUDE_DIR
    SKIA_CORE_INCLUDE_DIR
    SKIA_UTILS_INCLUDE_DIR
    SKIA_EFFECTS_INCLUDE_DIR
    SKIA_GPU_INCLUDE_DIR
    SKIA_GPU2_INCLUDE_DIR
    SKIA_LIBRARY_DIRS
    SKIA_LIBRARIES)
  if(DEFINED ${SKIA_CACHED_VAR})
    string(FIND "${${SKIA_CACHED_VAR}}" "${SKIA_DIR}" SKIA_CACHED_VAR_DEPOT_INDEX)
    if(NOT SKIA_CACHED_VAR_DEPOT_INDEX EQUAL 0)
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
  NO_CMAKE_FIND_ROOT_PATH #workaround needed for Android build
  )
find_path(
  SKIA_CORE_INCLUDE_DIR 
  SkCanvas.h 
  HINTS "${SKIA_DIR}/include/core"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH #workaround needed for Android build
  )
find_path(
  SKIA_UTILS_INCLUDE_DIR 
  SkRandom.h 
  HINTS "${SKIA_DIR}/include/utils" 
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH #workaround needed for Android build
  )
find_path(
  SKIA_EFFECTS_INCLUDE_DIR 
  SkImageSource.h 
  HINTS "${SKIA_DIR}/include/effects" 
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH #workaround needed for Android build
  )
find_path(
  SKIA_GPU_INCLUDE_DIR 
  GrContext.h 
  HINTS "${SKIA_DIR}/include/gpu" 
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH #workaround needed for Android build
  )
find_path(
  SKIA_GPU2_INCLUDE_DIR 
  gl/GrGLDefines.h 
  HINTS "${SKIA_DIR}/src/gpu" 
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH #workaround needed for Android build
  )

SET ( SKIA_INCLUDE_DIRS
  "${SKIA_DIR}"
)

IF (DEFINED ANDROID_ABI)
  SET ( SKIA_LIBRARY_DIRS "${SKIA_DIR}/out/Release/android" CACHE PATH "")
  SET ( SKIA_LIBRARIES "${SKIA_LIBRARY_DIRS}/${ANDROID_ABI}/libskia.so" CACHE PATH "")
ELSEIF (APPLE)
  IF(CMAKE_GENERATOR STREQUAL Xcode)
    SET ( SKIA_LIBRARY_DIRS "${SKIA_DIR}/out/Release/ios" CACHE PATH "")
  ELSE()
    SET(SKIA_MACOS_ARCH "${CMAKE_OSX_ARCHITECTURES}")

    IF(SKIA_MACOS_ARCH)
      list(LENGTH SKIA_MACOS_ARCH SKIA_MACOS_ARCH_LEN)
      IF(SKIA_MACOS_ARCH_LEN GREATER 1)
        message(FATAL_ERROR "Skia macOS build expects a single architecture, got: ${SKIA_MACOS_ARCH}")
      ENDIF()
      list(GET SKIA_MACOS_ARCH 0 SKIA_MACOS_ARCH)
    ELSE()
      SET(SKIA_MACOS_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    ENDIF()

    IF(SKIA_MACOS_ARCH STREQUAL "amd64")
      SET(SKIA_MACOS_ARCH "x86_64")
    ELSEIF(SKIA_MACOS_ARCH STREQUAL "aarch64")
      SET(SKIA_MACOS_ARCH "arm64")
    ENDIF()

    SET ( SKIA_LIBRARY_DIRS "${SKIA_DIR}/out/Release/macos/${SKIA_MACOS_ARCH}" CACHE PATH "" FORCE)
  ENDIF(CMAKE_GENERATOR STREQUAL Xcode)
ELSEIF (UNIX AND (CMAKE_SYSTEM_NAME STREQUAL "Linux"))
  SET(SKIA_LINUX_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  IF(SKIA_LINUX_ARCH STREQUAL "amd64")
    SET(SKIA_LINUX_ARCH "x86_64")
  ELSEIF(SKIA_LINUX_ARCH STREQUAL "arm64")
    SET(SKIA_LINUX_ARCH "aarch64")
  ELSEIF(SKIA_LINUX_ARCH STREQUAL "armv7")
    SET(SKIA_LINUX_ARCH "armv7l")
  ENDIF()
  SET ( SKIA_LIBRARY_DIRS "${SKIA_DIR}/out/Release/linux/${SKIA_LINUX_ARCH}" CACHE PATH "")
ENDIF(DEFINED ANDROID_ABI)

IF (NOT DEFINED SKIA_LIBRARIES)
  SET ( SKIA_LIBRARIES
    "${SKIA_LIBRARY_DIRS}/libskia.a" CACHE PATH ""
  )
ENDIF (NOT DEFINED SKIA_LIBRARIES)

IF (DEFINED ANDROID_ABI AND NOT EXISTS "${SKIA_LIBRARIES}")
  MESSAGE(FATAL_ERROR
    "Android Skia library not found at '${SKIA_LIBRARIES}'. "
    "Run the bootstrap with 'bash skia/fetch.sh --platform android --arch ${ANDROID_ABI}' "
    "or configure again with SKIA_AUTO_FETCH=ON."
  )
ENDIF()

IF (NOT DEFINED ANDROID_ABI AND NOT EXISTS "${SKIA_LIBRARIES}")
  MESSAGE(FATAL_ERROR
    "Skia library not found at '${SKIA_LIBRARIES}'. "
    "Install the prebuilt artifact with 'bash skia/fetch.sh' "
    "or bootstrap the full dev bundle with "
    "'bash skia/fetch.sh --platform macos --arch arm64 --install-dev' "
    "or override SKIA_LIBRARIES/SKIA_DIR."
  )
ENDIF()

IF(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    FIND_LIBRARY(ApplicationServices_LIBRARY ApplicationServices )
    FIND_LIBRARY(AGL_LIBRARY AGL )
    FIND_PACKAGE ( ZLIB )
  ENDIF ( )

  IF(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    SET ( SKIA_LIBRARIES -Wl,--start-group ${SKIA_LIBRARIES} -Wl,--end-group )
  ENDIF ( )

IF(NOT DEFINED ANDROID_ABI)
  FIND_PACKAGE_HANDLE_STANDARD_ARGS(Skia REQUIRED_VARS SKIA_LIBRARIES SKIA_INCLUDE_DIRS)
ENDIF(NOT DEFINED ANDROID_ABI)
