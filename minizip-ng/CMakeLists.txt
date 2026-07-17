# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)

project(totalcross-minizip-ng-static
  VERSION 4.2.2
  LANGUAGES C
)

include(FetchContent)
include(GNUInstallDirs)

set(MINIZIP_NG_SOURCE_DIR "" CACHE PATH "Directory containing minizip-ng sources")
set(MINIZIP_NG_GIT_REPOSITORY "https://github.com/zlib-ng/minizip-ng.git" CACHE STRING "minizip-ng Git repository")
set(MINIZIP_NG_GIT_TAG "4.2.2" CACHE STRING "minizip-ng Git tag")

if(DEFINED ANDROID_ABI)
  set(TC_MINIZIP_NG_ZLIB_PLATFORM "android")
  set(TC_MINIZIP_NG_ZLIB_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
  if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
    set(TC_MINIZIP_NG_ZLIB_PLATFORM "ios-simulator")
  else()
    set(TC_MINIZIP_NG_ZLIB_PLATFORM "ios")
  endif()
  set(TC_MINIZIP_NG_ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(TC_MINIZIP_NG_ZLIB_ARCH)
    list(LENGTH TC_MINIZIP_NG_ZLIB_ARCH TC_MINIZIP_NG_ZLIB_ARCH_LEN)
    if(TC_MINIZIP_NG_ZLIB_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "minizip-ng expects a single iOS architecture, got: ${TC_MINIZIP_NG_ZLIB_ARCH}")
    endif()
    list(GET TC_MINIZIP_NG_ZLIB_ARCH 0 TC_MINIZIP_NG_ZLIB_ARCH)
  else()
    set(TC_MINIZIP_NG_ZLIB_ARCH "arm64")
  endif()
  if(TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "aarch64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "arm64")
  endif()
elseif(WIN32)
  set(TC_MINIZIP_NG_ZLIB_PLATFORM "windows")
  set(TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM)
    set(TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM}" TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM_LOWER)
  if(TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(TC_MINIZIP_NG_ZLIB_ARCH "x86")
  elseif(TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "x64")
  elseif(TC_MINIZIP_NG_ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(TC_MINIZIP_NG_ZLIB_ARCH "x64")
  else()
    set(TC_MINIZIP_NG_ZLIB_ARCH "x86")
  endif()
elseif(APPLE)
  set(TC_MINIZIP_NG_ZLIB_PLATFORM "macos")
  set(TC_MINIZIP_NG_ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(TC_MINIZIP_NG_ZLIB_ARCH)
    list(LENGTH TC_MINIZIP_NG_ZLIB_ARCH TC_MINIZIP_NG_ZLIB_ARCH_LEN)
    if(TC_MINIZIP_NG_ZLIB_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "minizip-ng expects a single macOS architecture, got: ${TC_MINIZIP_NG_ZLIB_ARCH}")
    endif()
    list(GET TC_MINIZIP_NG_ZLIB_ARCH 0 TC_MINIZIP_NG_ZLIB_ARCH)
  else()
    set(TC_MINIZIP_NG_ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "amd64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "x86_64")
  elseif(TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "aarch64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(TC_MINIZIP_NG_ZLIB_PLATFORM "linux")
  set(TC_MINIZIP_NG_ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "amd64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "x86_64")
  elseif(TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "arm64")
    set(TC_MINIZIP_NG_ZLIB_ARCH "aarch64")
  elseif(TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "arm" OR TC_MINIZIP_NG_ZLIB_ARCH STREQUAL "armv7")
    set(TC_MINIZIP_NG_ZLIB_ARCH "armv7l")
  endif()
else()
  message(FATAL_ERROR "Unable to detect the zlib-ng prebuilt path for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(TC_MINIZIP_NG_DEFAULT_ZLIB_DIR "${CMAKE_CURRENT_LIST_DIR}/../zlib-ng/local/${TC_MINIZIP_NG_ZLIB_PLATFORM}/${TC_MINIZIP_NG_ZLIB_ARCH}")
set(ZLIB_DIR "${TC_MINIZIP_NG_DEFAULT_ZLIB_DIR}" CACHE PATH "zlib-ng prebuilt directory used by minizip-ng")

set(TC_MINIZIP_NG_ZLIB_INCLUDE_DIR "${ZLIB_DIR}/include")
set(TC_MINIZIP_NG_ZLIB_LIBRARY_CANDIDATES
  "${ZLIB_DIR}/lib/libz.a"
  "${ZLIB_DIR}/lib/z.lib"
  "${ZLIB_DIR}/lib/zlib.lib"
  "${ZLIB_DIR}/lib/zlibstatic.lib"
)

unset(TC_MINIZIP_NG_ZLIB_LIBRARY)
foreach(TC_MINIZIP_NG_ZLIB_LIBRARY_CANDIDATE ${TC_MINIZIP_NG_ZLIB_LIBRARY_CANDIDATES})
  if(EXISTS "${TC_MINIZIP_NG_ZLIB_LIBRARY_CANDIDATE}")
    set(TC_MINIZIP_NG_ZLIB_LIBRARY "${TC_MINIZIP_NG_ZLIB_LIBRARY_CANDIDATE}")
    break()
  endif()
endforeach()

if(NOT EXISTS "${TC_MINIZIP_NG_ZLIB_INCLUDE_DIR}/zlib.h" OR NOT EXISTS "${TC_MINIZIP_NG_ZLIB_INCLUDE_DIR}/zconf.h")
  message(FATAL_ERROR "ZLIB_DIR must point to a zlib-ng prebuilt with include/zlib.h and include/zconf.h: ${ZLIB_DIR}")
endif()

if(NOT TC_MINIZIP_NG_ZLIB_LIBRARY)
  message(FATAL_ERROR "Unable to find the zlib-ng static library under ${ZLIB_DIR}/lib")
endif()

set(ZLIB_INCLUDE_DIR "${TC_MINIZIP_NG_ZLIB_INCLUDE_DIR}" CACHE PATH "zlib-ng include directory" FORCE)
set(ZLIB_LIBRARY "${TC_MINIZIP_NG_ZLIB_LIBRARY}" CACHE FILEPATH "zlib-ng static library" FORCE)
set(ZLIB_FOUND TRUE CACHE BOOL "zlib-ng found for minizip-ng" FORCE)

if(NOT TARGET ZLIB::ZLIB)
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)
  set_target_properties(ZLIB::ZLIB PROPERTIES
    IMPORTED_LOCATION "${TC_MINIZIP_NG_ZLIB_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${TC_MINIZIP_NG_ZLIB_INCLUDE_DIR}"
  )
endif()

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(MZ_BUILD_SO OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_FUZZ_TESTS OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(MZ_FETCH_LIBS OFF CACHE BOOL "" FORCE)
set(MZ_COMPAT ON CACHE BOOL "" FORCE)
set(MZ_ZLIB ON CACHE BOOL "" FORCE)
set(MZ_ZLIB_FLAVOR "zlib" CACHE STRING "" FORCE)
set(MZ_BZIP2 OFF CACHE BOOL "" FORCE)
set(MZ_LZMA OFF CACHE BOOL "" FORCE)
set(MZ_PPMD OFF CACHE BOOL "" FORCE)
set(MZ_ZSTD OFF CACHE BOOL "" FORCE)
set(MZ_LIBCOMP OFF CACHE BOOL "" FORCE)
set(MZ_PKCRYPT ON CACHE BOOL "" FORCE)
set(MZ_WZAES OFF CACHE BOOL "" FORCE)
set(MZ_OPENSSL OFF CACHE BOOL "" FORCE)
set(MZ_LIBBSD OFF CACHE BOOL "" FORCE)
set(MZ_ICONV OFF CACHE BOOL "" FORCE)
set(MZ_INSTALL OFF CACHE BOOL "" FORCE)

if(MINIZIP_NG_SOURCE_DIR)
  set(minizip_ng_SOURCE_DIR "${MINIZIP_NG_SOURCE_DIR}")
else()
  FetchContent_Declare(
    minizip_ng
    GIT_REPOSITORY "${MINIZIP_NG_GIT_REPOSITORY}"
    GIT_TAG "${MINIZIP_NG_GIT_TAG}"
    GIT_SHALLOW TRUE
    GIT_PROGRESS TRUE
    USES_TERMINAL_DOWNLOAD TRUE
  )

  FetchContent_GetProperties(minizip_ng)
  if(NOT minizip_ng_POPULATED)
    FetchContent_Populate(minizip_ng)
  endif()
endif()

add_subdirectory("${minizip_ng_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/minizip-ng-build")

set(TC_MINIZIP_NG_TARGET "")
foreach(TC_MINIZIP_NG_TARGET_CANDIDATE minizip minizip_static minizip-ng)
  if(TARGET "${TC_MINIZIP_NG_TARGET_CANDIDATE}")
    set(TC_MINIZIP_NG_TARGET "${TC_MINIZIP_NG_TARGET_CANDIDATE}")
    break()
  endif()
endforeach()

if(NOT TC_MINIZIP_NG_TARGET)
  message(FATAL_ERROR "Unable to find the minizip-ng static library target")
endif()

target_include_directories("${TC_MINIZIP_NG_TARGET}"
  PUBLIC
    "$<BUILD_INTERFACE:${minizip_ng_SOURCE_DIR}>"
    "$<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/minizip-ng-build>"
    "$<BUILD_INTERFACE:${TC_MINIZIP_NG_ZLIB_INCLUDE_DIR}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)
target_link_libraries("${TC_MINIZIP_NG_TARGET}" PUBLIC ZLIB::ZLIB)

set_target_properties("${TC_MINIZIP_NG_TARGET}"
  PROPERTIES
    OUTPUT_NAME minizip
    POSITION_INDEPENDENT_CODE ON
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0
)

install(TARGETS "${TC_MINIZIP_NG_TARGET}"
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

set(TC_MINIZIP_NG_PUBLIC_HEADERS
  "${minizip_ng_SOURCE_DIR}/compat/crypt.h"
  "${minizip_ng_SOURCE_DIR}/compat/ioapi.h"
  "${minizip_ng_SOURCE_DIR}/compat/unzip.h"
  "${minizip_ng_SOURCE_DIR}/compat/zip.h"
  "${minizip_ng_SOURCE_DIR}/mz.h"
  "${minizip_ng_SOURCE_DIR}/mz_crypt.h"
  "${minizip_ng_SOURCE_DIR}/mz_os.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm_buf.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm_mem.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm_os.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm_pkcrypt.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm_split.h"
  "${minizip_ng_SOURCE_DIR}/mz_strm_zlib.h"
  "${minizip_ng_SOURCE_DIR}/mz_zip.h"
  "${minizip_ng_SOURCE_DIR}/mz_zip_rw.h"
  "${CMAKE_BINARY_DIR}/minizip-ng-build/mz_config.h"
)

install(FILES ${TC_MINIZIP_NG_PUBLIC_HEADERS}
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)
