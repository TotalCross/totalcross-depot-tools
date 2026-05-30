cmake_minimum_required(VERSION 3.16)
cmake_policy(SET CMP0007 NEW)

project(totalcross-libpng-static
  VERSION 1.6.48
  LANGUAGES C
)

include(FetchContent)
include(GNUInstallDirs)

set(LIBPNG_SOURCE_DIR "" CACHE PATH "Directory containing libpng sources")
set(LIBPNG_GIT_REPOSITORY "https://github.com/glennrp/libpng.git" CACHE STRING "libpng Git repository")
set(LIBPNG_GIT_TAG "v1.6.48" CACHE STRING "libpng Git tag")

if(DEFINED ANDROID_ABI)
  set(TC_LIBPNG_ZLIB_PLATFORM "android")
  set(TC_LIBPNG_ZLIB_ARCH "${ANDROID_ABI}")
elseif(CMAKE_GENERATOR STREQUAL Xcode)
  set(TC_LIBPNG_ZLIB_PLATFORM "ios")
  set(TC_LIBPNG_ZLIB_ARCH "xcframework")
elseif(WIN32)
  set(TC_LIBPNG_ZLIB_PLATFORM "windows")
  if(CMAKE_GENERATOR_PLATFORM MATCHES "x64")
    set(TC_LIBPNG_ZLIB_ARCH "x86_64")
  else()
    set(TC_LIBPNG_ZLIB_ARCH "x86")
  endif()
elseif(APPLE)
  set(TC_LIBPNG_ZLIB_PLATFORM "macos")
  set(TC_LIBPNG_ZLIB_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(TC_LIBPNG_ZLIB_ARCH)
    list(LENGTH TC_LIBPNG_ZLIB_ARCH TC_LIBPNG_ZLIB_ARCH_LEN)
    if(TC_LIBPNG_ZLIB_ARCH_LEN GREATER 1)
      message(FATAL_ERROR "libpng expects a single macOS architecture, got: ${TC_LIBPNG_ZLIB_ARCH}")
    endif()
    list(GET TC_LIBPNG_ZLIB_ARCH 0 TC_LIBPNG_ZLIB_ARCH)
  else()
    set(TC_LIBPNG_ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  if(TC_LIBPNG_ZLIB_ARCH STREQUAL "amd64")
    set(TC_LIBPNG_ZLIB_ARCH "x86_64")
  elseif(TC_LIBPNG_ZLIB_ARCH STREQUAL "aarch64")
    set(TC_LIBPNG_ZLIB_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(TC_LIBPNG_ZLIB_PLATFORM "linux")
  set(TC_LIBPNG_ZLIB_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(TC_LIBPNG_ZLIB_ARCH STREQUAL "amd64")
    set(TC_LIBPNG_ZLIB_ARCH "x86_64")
  elseif(TC_LIBPNG_ZLIB_ARCH STREQUAL "arm64")
    set(TC_LIBPNG_ZLIB_ARCH "aarch64")
  elseif(TC_LIBPNG_ZLIB_ARCH STREQUAL "arm" OR TC_LIBPNG_ZLIB_ARCH STREQUAL "armv7")
    set(TC_LIBPNG_ZLIB_ARCH "armv7l")
  endif()
else()
  message(FATAL_ERROR "Unable to detect the zlib-ng prebuilt path for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(TC_LIBPNG_DEFAULT_ZLIB_DIR "${CMAKE_CURRENT_LIST_DIR}/../zlib-ng/local/${TC_LIBPNG_ZLIB_PLATFORM}/${TC_LIBPNG_ZLIB_ARCH}")
set(ZLIB_DIR "${TC_LIBPNG_DEFAULT_ZLIB_DIR}" CACHE PATH "zlib-ng prebuilt directory used by libpng")

set(TC_LIBPNG_ZLIB_INCLUDE_DIR "${ZLIB_DIR}/include")
set(TC_LIBPNG_ZLIB_LIBRARY_CANDIDATES
  "${ZLIB_DIR}/lib/libz.xcframework"
  "${ZLIB_DIR}/lib/libz.a"
  "${ZLIB_DIR}/lib/zlib.lib"
  "${ZLIB_DIR}/lib/zlibstatic.lib"
)

unset(TC_LIBPNG_ZLIB_LIBRARY)
foreach(TC_LIBPNG_ZLIB_LIBRARY_CANDIDATE ${TC_LIBPNG_ZLIB_LIBRARY_CANDIDATES})
  if(EXISTS "${TC_LIBPNG_ZLIB_LIBRARY_CANDIDATE}")
    set(TC_LIBPNG_ZLIB_LIBRARY "${TC_LIBPNG_ZLIB_LIBRARY_CANDIDATE}")
    break()
  endif()
endforeach()

if(NOT EXISTS "${TC_LIBPNG_ZLIB_INCLUDE_DIR}/zlib.h" OR NOT EXISTS "${TC_LIBPNG_ZLIB_INCLUDE_DIR}/zconf.h")
  message(FATAL_ERROR "ZLIB_DIR must point to a zlib-ng prebuilt with include/zlib.h and include/zconf.h: ${ZLIB_DIR}")
endif()

if(NOT TC_LIBPNG_ZLIB_LIBRARY)
  message(FATAL_ERROR "Unable to find the zlib-ng static library under ${ZLIB_DIR}/lib")
endif()

set(ZLIB_INCLUDE_DIR "${TC_LIBPNG_ZLIB_INCLUDE_DIR}" CACHE PATH "zlib-ng include directory" FORCE)
if(TC_LIBPNG_ZLIB_LIBRARY MATCHES "\\.xcframework$")
  set(ZLIB_LIBRARY "${TC_LIBPNG_ZLIB_LIBRARY}" CACHE PATH "zlib-ng XCFramework" FORCE)
else()
  set(ZLIB_LIBRARY "${TC_LIBPNG_ZLIB_LIBRARY}" CACHE FILEPATH "zlib-ng static library" FORCE)
endif()
set(ZLIB_FOUND TRUE CACHE BOOL "zlib-ng found for libpng" FORCE)

if(NOT TARGET ZLIB::ZLIB)
  if(TC_LIBPNG_ZLIB_LIBRARY MATCHES "\\.xcframework$")
    add_library(ZLIB::ZLIB INTERFACE IMPORTED GLOBAL)
    set_target_properties(ZLIB::ZLIB PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${TC_LIBPNG_ZLIB_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${TC_LIBPNG_ZLIB_LIBRARY}"
    )
  else()
    add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)
    set_target_properties(ZLIB::ZLIB PROPERTIES
      IMPORTED_LOCATION "${TC_LIBPNG_ZLIB_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${TC_LIBPNG_ZLIB_INCLUDE_DIR}"
    )
  endif()
endif()

if(LIBPNG_SOURCE_DIR)
  set(libpng_SOURCE_DIR "${LIBPNG_SOURCE_DIR}")
else()
  FetchContent_Declare(
    libpng
    GIT_REPOSITORY "${LIBPNG_GIT_REPOSITORY}"
    GIT_TAG "${LIBPNG_GIT_TAG}"
    GIT_SHALLOW TRUE
    GIT_PROGRESS TRUE
    USES_TERMINAL_DOWNLOAD TRUE
  )

  FetchContent_GetProperties(libpng)
  if(NOT libpng_POPULATED)
    FetchContent_Populate(libpng)
  endif()
endif()

set(SKIP_INSTALL_ALL TRUE)
set(PNG_LIBCONF_HEADER "${libpng_SOURCE_DIR}/scripts/pnglibconf.h.prebuilt" CACHE FILEPATH "" FORCE)
set(PNG_TOOLS OFF CACHE BOOL "" FORCE)
set(PNG_SHARED OFF CACHE BOOL "" FORCE)
set(PNG_FRAMEWORK OFF CACHE BOOL "" FORCE)
set(PNG_TESTS OFF CACHE BOOL "" FORCE)
set(PNG_DEBUG_POSTFIX "" CACHE STRING "" FORCE)

add_subdirectory("${libpng_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/libpng-build")

target_include_directories(png_static
  PUBLIC
    "$<BUILD_INTERFACE:${libpng_SOURCE_DIR}>"
    "$<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/libpng-build>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)

target_link_libraries(png_static PUBLIC ZLIB::ZLIB)

set_target_properties(png_static
  PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0
)

install(TARGETS png_static
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

install(FILES
  "${libpng_SOURCE_DIR}/png.h"
  "${libpng_SOURCE_DIR}/pngconf.h"
  "${CMAKE_BINARY_DIR}/libpng-build/pnglibconf.h"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)
