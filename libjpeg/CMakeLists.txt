# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)

project(totalcross-libjpeg-static
  VERSION 10
  LANGUAGES C
)

include(GNUInstallDirs)

set(LIBJPEG_SOURCE_DIR "" CACHE PATH "Directory containing IJG libjpeg sources")
set(LIBJPEG_SOURCE_ARCHIVE "" CACHE FILEPATH "IJG libjpeg source archive")
set(LIBJPEG_SOURCE_URL "https://ijg.org/files/jpegsrc.v10.tar.gz" CACHE STRING "IJG libjpeg source archive URL")

if(LIBJPEG_SOURCE_DIR)
  get_filename_component(libjpeg_SOURCE_DIR "${LIBJPEG_SOURCE_DIR}" ABSOLUTE)
else()
  if(LIBJPEG_SOURCE_ARCHIVE)
    get_filename_component(TC_LIBJPEG_SOURCE_ARCHIVE "${LIBJPEG_SOURCE_ARCHIVE}" ABSOLUTE)
  else()
    set(TC_LIBJPEG_SOURCE_ARCHIVE "${CMAKE_BINARY_DIR}/sources/jpegsrc.v10.tar.gz")
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/sources")
    set(TC_LIBJPEG_SHOULD_DOWNLOAD_SOURCE TRUE)
    if(EXISTS "${TC_LIBJPEG_SOURCE_ARCHIVE}")
      file(SIZE "${TC_LIBJPEG_SOURCE_ARCHIVE}" TC_LIBJPEG_SOURCE_ARCHIVE_SIZE)
      if(TC_LIBJPEG_SOURCE_ARCHIVE_SIZE GREATER 0)
        set(TC_LIBJPEG_SHOULD_DOWNLOAD_SOURCE FALSE)
      endif()
    endif()
    if(TC_LIBJPEG_SHOULD_DOWNLOAD_SOURCE)
      file(DOWNLOAD
        "${LIBJPEG_SOURCE_URL}"
        "${TC_LIBJPEG_SOURCE_ARCHIVE}"
        SHOW_PROGRESS
        STATUS TC_LIBJPEG_DOWNLOAD_STATUS
      )
      list(GET TC_LIBJPEG_DOWNLOAD_STATUS 0 TC_LIBJPEG_DOWNLOAD_CODE)
      list(GET TC_LIBJPEG_DOWNLOAD_STATUS 1 TC_LIBJPEG_DOWNLOAD_MESSAGE)
      if(NOT TC_LIBJPEG_DOWNLOAD_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to download IJG libjpeg source: ${TC_LIBJPEG_DOWNLOAD_MESSAGE}")
      endif()
    endif()
  endif()

  set(libjpeg_SOURCE_PARENT "${CMAKE_BINARY_DIR}/libjpeg-src")
  file(REMOVE_RECURSE "${libjpeg_SOURCE_PARENT}")
  file(MAKE_DIRECTORY "${libjpeg_SOURCE_PARENT}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "${TC_LIBJPEG_SOURCE_ARCHIVE}"
    WORKING_DIRECTORY "${libjpeg_SOURCE_PARENT}"
    RESULT_VARIABLE TC_LIBJPEG_EXTRACT_RESULT
  )
  if(NOT TC_LIBJPEG_EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to extract IJG libjpeg source archive: ${TC_LIBJPEG_SOURCE_ARCHIVE}")
  endif()

  file(GLOB TC_LIBJPEG_SOURCE_DIR_CANDIDATES
    LIST_DIRECTORIES true
    "${libjpeg_SOURCE_PARENT}/jpeg-*"
  )
  list(LENGTH TC_LIBJPEG_SOURCE_DIR_CANDIDATES TC_LIBJPEG_SOURCE_DIR_COUNT)
  if(NOT TC_LIBJPEG_SOURCE_DIR_COUNT EQUAL 1)
    message(FATAL_ERROR "Expected exactly one jpeg-* directory under ${libjpeg_SOURCE_PARENT}, found ${TC_LIBJPEG_SOURCE_DIR_COUNT}: ${TC_LIBJPEG_SOURCE_DIR_CANDIDATES}")
  endif()
  list(GET TC_LIBJPEG_SOURCE_DIR_CANDIDATES 0 libjpeg_SOURCE_DIR)
endif()

foreach(TC_LIBJPEG_REQUIRED_FILE jpeglib.h jmorecfg.h jerror.h)
  if(NOT EXISTS "${libjpeg_SOURCE_DIR}/${TC_LIBJPEG_REQUIRED_FILE}")
    message(FATAL_ERROR "Missing ${TC_LIBJPEG_REQUIRED_FILE} under IJG libjpeg source directory: ${libjpeg_SOURCE_DIR}")
  endif()
endforeach()

set(libjpeg_BINARY_DIR "${CMAKE_BINARY_DIR}/libjpeg-build")
file(MAKE_DIRECTORY "${libjpeg_BINARY_DIR}")

file(WRITE "${libjpeg_BINARY_DIR}/jconfig.h" "#ifndef JCONFIG_H\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#define JCONFIG_H\n\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#define HAVE_PROTOTYPES 1\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#define HAVE_UNSIGNED_CHAR 1\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#define HAVE_UNSIGNED_SHORT 1\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#define HAVE_STDDEF_H 1\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#define HAVE_STDLIB_H 1\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef CHAR_IS_UNSIGNED\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef NEED_BSD_STRINGS\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef NEED_SYS_TYPES_H\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef NEED_FAR_POINTERS\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef NEED_SHORT_EXTERNAL_NAMES\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef INCOMPLETE_TYPES_BROKEN\n\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#ifdef JPEG_INTERNALS\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#undef RIGHT_SHIFT_IS_UNSIGNED\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#endif\n\n")
file(APPEND "${libjpeg_BINARY_DIR}/jconfig.h" "#endif\n")

file(GLOB TC_LIBJPEG_SOURCES CONFIGURE_DEPENDS
  "${libjpeg_SOURCE_DIR}/j*.c"
)
list(FILTER TC_LIBJPEG_SOURCES EXCLUDE REGEX "/jpegtran\\.c$")
list(FILTER TC_LIBJPEG_SOURCES EXCLUDE REGEX "/jmemansi\\.c$")
list(FILTER TC_LIBJPEG_SOURCES EXCLUDE REGEX "/jmemdos\\.c$")
list(FILTER TC_LIBJPEG_SOURCES EXCLUDE REGEX "/jmemmac\\.c$")
list(FILTER TC_LIBJPEG_SOURCES EXCLUDE REGEX "/jmemname\\.c$")

if(NOT TC_LIBJPEG_SOURCES)
  message(FATAL_ERROR "No IJG libjpeg sources found under ${libjpeg_SOURCE_DIR}")
endif()

add_library(jpeg STATIC ${TC_LIBJPEG_SOURCES})
add_library(JPEG::JPEG ALIAS jpeg)

target_include_directories(jpeg
  PUBLIC
    "$<BUILD_INTERFACE:${libjpeg_BINARY_DIR}>"
    "$<BUILD_INTERFACE:${libjpeg_SOURCE_DIR}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)

set_target_properties(jpeg
  PROPERTIES
    OUTPUT_NAME jpeg
    POSITION_INDEPENDENT_CODE ON
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0
)

install(TARGETS jpeg
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

install(FILES
  "${libjpeg_BINARY_DIR}/jconfig.h"
  "${libjpeg_SOURCE_DIR}/jerror.h"
  "${libjpeg_SOURCE_DIR}/jmorecfg.h"
  "${libjpeg_SOURCE_DIR}/jpeglib.h"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)
