# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)

project(totalcross-zlib-static
  VERSION 1.3.1
  LANGUAGES C
)

include(FetchContent)
include(GNUInstallDirs)

set(ZLIB_SOURCE_DIR "" CACHE PATH "Directory containing zlib sources")
set(ZLIB_GIT_REPOSITORY "https://github.com/madler/zlib.git" CACHE STRING "zlib Git repository")
set(ZLIB_GIT_TAG "v1.3.1" CACHE STRING "zlib Git tag")

if(ZLIB_SOURCE_DIR)
  set(zlib_SOURCE_DIR "${ZLIB_SOURCE_DIR}")
else()
  FetchContent_Declare(
    zlib
    GIT_REPOSITORY "${ZLIB_GIT_REPOSITORY}"
    GIT_TAG "${ZLIB_GIT_TAG}"
    GIT_SHALLOW TRUE
    GIT_PROGRESS TRUE
    USES_TERMINAL_DOWNLOAD TRUE
  )

  FetchContent_GetProperties(zlib)
  if(NOT zlib_POPULATED)
    FetchContent_Populate(zlib)
  endif()
endif()

set(zlib_BINARY_DIR "${CMAKE_BINARY_DIR}/zlib-build")
file(MAKE_DIRECTORY "${zlib_BINARY_DIR}")

file(READ "${zlib_SOURCE_DIR}/zconf.h" FILE_CONTENTS)
string(REPLACE "#define ZCONF_H" "#define ZCONF_H\n\n#define Z_SOLO\n" FILE_CONTENTS "${FILE_CONTENTS}")
file(WRITE "${zlib_BINARY_DIR}/zconf.h" "${FILE_CONTENTS}")
configure_file("${zlib_SOURCE_DIR}/zlib.h" "${zlib_BINARY_DIR}/zlib.h" COPYONLY)

set(ZLIB_PUBLIC_HDRS
  "${zlib_BINARY_DIR}/zconf.h"
  "${zlib_BINARY_DIR}/zlib.h"
)
set(ZLIB_PRIVATE_HDRS
  "${zlib_SOURCE_DIR}/crc32.h"
  "${zlib_SOURCE_DIR}/deflate.h"
  "${zlib_SOURCE_DIR}/inffast.h"
  "${zlib_SOURCE_DIR}/inffixed.h"
  "${zlib_SOURCE_DIR}/inflate.h"
  "${zlib_SOURCE_DIR}/inftrees.h"
  "${zlib_SOURCE_DIR}/trees.h"
  "${zlib_SOURCE_DIR}/zutil.h"
)
set(ZLIB_SRCS
  "${zlib_SOURCE_DIR}/adler32.c"
  "${zlib_SOURCE_DIR}/compress.c"
  "${zlib_SOURCE_DIR}/crc32.c"
  "${zlib_SOURCE_DIR}/deflate.c"
  "${zlib_SOURCE_DIR}/inflate.c"
  "${zlib_SOURCE_DIR}/infback.c"
  "${zlib_SOURCE_DIR}/inftrees.c"
  "${zlib_SOURCE_DIR}/inffast.c"
  "${zlib_SOURCE_DIR}/trees.c"
  "${zlib_SOURCE_DIR}/uncompr.c"
  "${zlib_SOURCE_DIR}/zutil.c"
)

add_library(zlibstatic STATIC ${ZLIB_SRCS} ${ZLIB_PUBLIC_HDRS} ${ZLIB_PRIVATE_HDRS})

target_include_directories(zlibstatic
  PUBLIC
    "$<BUILD_INTERFACE:${zlib_BINARY_DIR}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)

target_compile_definitions(zlibstatic PRIVATE Z_SOLO)

set_target_properties(zlibstatic
  PROPERTIES
    OUTPUT_NAME z
    POSITION_INDEPENDENT_CODE ON
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0
)

install(TARGETS zlibstatic
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

install(FILES
  "${zlib_BINARY_DIR}/zlib.h"
  "${zlib_BINARY_DIR}/zconf.h"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)
