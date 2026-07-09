cmake_minimum_required(VERSION 3.16)

project(totalcross-minizip-static
  VERSION 1.3.1
  LANGUAGES C
)

include(FetchContent)
include(GNUInstallDirs)

set(MINIZIP_SOURCE_DIR "" CACHE PATH "Directory containing zlib sources with contrib/minizip")
set(MINIZIP_GIT_REPOSITORY "https://github.com/madler/zlib.git" CACHE STRING "zlib Git repository")
set(MINIZIP_GIT_TAG "v1.3.1" CACHE STRING "zlib Git tag containing minizip")

if(DEFINED ANDROID_ABI)
  set(TC_MINIZIP_ZLIB_PLATFORM "android")
  set(TC_MINIZIP_ZLIB_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
  if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
    set(TC_MINIZIP_ZLIB_PLATFORM "ios-simulator")
  else()
    set(TC_MINIZIP_ZLIB_PLATFORM "ios")
  endif()
  set(TC_MINIZIP_ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(TC_MINIZIP_ZLIB_ARCH)
    list(LENGTH TC_MINIZIP_ZLIB_ARCH TC_MINIZIP_ZLIB_ARCH_LEN)
    if(TC_MINIZIP_ZLIB_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "minizip expects a single iOS architecture, got: ${TC_MINIZIP_ZLIB_ARCH}")
    endif()
    list(GET TC_MINIZIP_ZLIB_ARCH 0 TC_MINIZIP_ZLIB_ARCH)
  else()
    set(TC_MINIZIP_ZLIB_ARCH "arm64")
  endif()
  if(TC_MINIZIP_ZLIB_ARCH STREQUAL "aarch64")
    set(TC_MINIZIP_ZLIB_ARCH "arm64")
  endif()
elseif(WIN32)
  set(TC_MINIZIP_ZLIB_PLATFORM "windows")
  set(TC_MINIZIP_ZLIB_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT TC_MINIZIP_ZLIB_WINDOWS_PLATFORM)
    set(TC_MINIZIP_ZLIB_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${TC_MINIZIP_ZLIB_WINDOWS_PLATFORM}" TC_MINIZIP_ZLIB_WINDOWS_PLATFORM_LOWER)
  if(TC_MINIZIP_ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(TC_MINIZIP_ZLIB_ARCH "x86")
  elseif(TC_MINIZIP_ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(TC_MINIZIP_ZLIB_ARCH "x64")
  elseif(TC_MINIZIP_ZLIB_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(TC_MINIZIP_ZLIB_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(TC_MINIZIP_ZLIB_ARCH "x64")
  else()
    set(TC_MINIZIP_ZLIB_ARCH "x86")
  endif()
elseif(APPLE)
  set(TC_MINIZIP_ZLIB_PLATFORM "macos")
  set(TC_MINIZIP_ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(TC_MINIZIP_ZLIB_ARCH)
    list(LENGTH TC_MINIZIP_ZLIB_ARCH TC_MINIZIP_ZLIB_ARCH_LEN)
    if(TC_MINIZIP_ZLIB_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "minizip expects a single macOS architecture, got: ${TC_MINIZIP_ZLIB_ARCH}")
    endif()
    list(GET TC_MINIZIP_ZLIB_ARCH 0 TC_MINIZIP_ZLIB_ARCH)
  else()
    set(TC_MINIZIP_ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(TC_MINIZIP_ZLIB_ARCH STREQUAL "amd64")
    set(TC_MINIZIP_ZLIB_ARCH "x86_64")
  elseif(TC_MINIZIP_ZLIB_ARCH STREQUAL "aarch64")
    set(TC_MINIZIP_ZLIB_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(TC_MINIZIP_ZLIB_PLATFORM "linux")
  set(TC_MINIZIP_ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(TC_MINIZIP_ZLIB_ARCH STREQUAL "amd64")
    set(TC_MINIZIP_ZLIB_ARCH "x86_64")
  elseif(TC_MINIZIP_ZLIB_ARCH STREQUAL "arm64")
    set(TC_MINIZIP_ZLIB_ARCH "aarch64")
  elseif(TC_MINIZIP_ZLIB_ARCH STREQUAL "arm" OR TC_MINIZIP_ZLIB_ARCH STREQUAL "armv7")
    set(TC_MINIZIP_ZLIB_ARCH "armv7l")
  endif()
else()
  message(FATAL_ERROR "Unable to detect the zlib prebuilt path for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(TC_MINIZIP_DEFAULT_ZLIB_DIR "${CMAKE_CURRENT_LIST_DIR}/../zlib/local/${TC_MINIZIP_ZLIB_PLATFORM}/${TC_MINIZIP_ZLIB_ARCH}")
set(ZLIB_DIR "${TC_MINIZIP_DEFAULT_ZLIB_DIR}" CACHE PATH "zlib prebuilt directory used by minizip")

set(TC_MINIZIP_ZLIB_INCLUDE_DIR "${ZLIB_DIR}/include")
set(TC_MINIZIP_ZLIB_LIBRARY_CANDIDATES
  "${ZLIB_DIR}/lib/libz.a"
  "${ZLIB_DIR}/lib/z.lib"
  "${ZLIB_DIR}/lib/zlib.lib"
  "${ZLIB_DIR}/lib/zlibstatic.lib"
)

unset(TC_MINIZIP_ZLIB_LIBRARY)
foreach(TC_MINIZIP_ZLIB_LIBRARY_CANDIDATE ${TC_MINIZIP_ZLIB_LIBRARY_CANDIDATES})
  if(EXISTS "${TC_MINIZIP_ZLIB_LIBRARY_CANDIDATE}")
    set(TC_MINIZIP_ZLIB_LIBRARY "${TC_MINIZIP_ZLIB_LIBRARY_CANDIDATE}")
    break()
  endif()
endforeach()

if(NOT EXISTS "${TC_MINIZIP_ZLIB_INCLUDE_DIR}/zlib.h" OR NOT EXISTS "${TC_MINIZIP_ZLIB_INCLUDE_DIR}/zconf.h")
  message(FATAL_ERROR "ZLIB_DIR must point to a zlib prebuilt with include/zlib.h and include/zconf.h: ${ZLIB_DIR}")
endif()

if(NOT TC_MINIZIP_ZLIB_LIBRARY)
  message(FATAL_ERROR "Unable to find the zlib static library under ${ZLIB_DIR}/lib")
endif()

if(NOT TARGET ZLIB::ZLIB)
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)
  set_target_properties(ZLIB::ZLIB PROPERTIES
    IMPORTED_LOCATION "${TC_MINIZIP_ZLIB_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${TC_MINIZIP_ZLIB_INCLUDE_DIR}"
  )
endif()

if(MINIZIP_SOURCE_DIR)
  set(zlib_SOURCE_DIR "${MINIZIP_SOURCE_DIR}")
else()
  FetchContent_Declare(
    zlib
    GIT_REPOSITORY "${MINIZIP_GIT_REPOSITORY}"
    GIT_TAG "${MINIZIP_GIT_TAG}"
    GIT_SHALLOW TRUE
    GIT_PROGRESS TRUE
    USES_TERMINAL_DOWNLOAD TRUE
  )

  FetchContent_GetProperties(zlib)
  if(NOT zlib_POPULATED)
    FetchContent_Populate(zlib)
  endif()
endif()

set(MINIZIP_CONTRIB_DIR "${zlib_SOURCE_DIR}/contrib/minizip")
if(NOT EXISTS "${MINIZIP_CONTRIB_DIR}/zip.c")
  message(FATAL_ERROR "MINIZIP_SOURCE_DIR must point to zlib sources containing contrib/minizip")
endif()

set(MINIZIP_PUBLIC_HDRS
  "${MINIZIP_CONTRIB_DIR}/crypt.h"
  "${MINIZIP_CONTRIB_DIR}/ioapi.h"
  "${MINIZIP_CONTRIB_DIR}/unzip.h"
  "${MINIZIP_CONTRIB_DIR}/zip.h"
)
set(MINIZIP_SRCS
  "${MINIZIP_CONTRIB_DIR}/ioapi.c"
  "${MINIZIP_CONTRIB_DIR}/unzip.c"
  "${MINIZIP_CONTRIB_DIR}/zip.c"
)

add_library(minizipstatic STATIC ${MINIZIP_SRCS} ${MINIZIP_PUBLIC_HDRS})

target_include_directories(minizipstatic
  PUBLIC
    "$<BUILD_INTERFACE:${MINIZIP_CONTRIB_DIR}>"
    "$<BUILD_INTERFACE:${TC_MINIZIP_ZLIB_INCLUDE_DIR}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)
target_link_libraries(minizipstatic PUBLIC ZLIB::ZLIB)

set_target_properties(minizipstatic
  PROPERTIES
    OUTPUT_NAME minizip
    POSITION_INDEPENDENT_CODE ON
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0
)

install(TARGETS minizipstatic
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

install(FILES ${MINIZIP_PUBLIC_HDRS}
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)
