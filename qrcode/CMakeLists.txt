cmake_minimum_required(VERSION 3.16)

project(totalcross-qrcode-static VERSION 20200519 LANGUAGES C)

include(GNUInstallDirs)
include(CTest)

if(WIN32)
  message(FATAL_ERROR "ricmoo QRCode cannot be built on Windows because its C implementation requires variable-length arrays; use QRCodeGen instead")
endif()

set(QRCODE_UPSTREAM_COMMIT "eafbde494979abc2445c363cc2602230bcbe299c")
set(QRCODE_SOURCE_DIR "" CACHE PATH "Directory containing ricmoo QRCode sources")
set(QRCODE_SOURCE_ARCHIVE "" CACHE FILEPATH "ricmoo QRCode source archive")
set(QRCODE_SOURCE_URL
  "https://codeload.github.com/ricmoo/QRCode/tar.gz/${QRCODE_UPSTREAM_COMMIT}"
  CACHE STRING "ricmoo QRCode source archive URL")
set(QRCODE_SOURCE_SHA256
  "ed85acf3ea44af275139fb78e580e2918d2c265d0a78f0034e05b89625c69621"
  CACHE STRING "Expected SHA-256 for the ricmoo source archive")

if(QRCODE_SOURCE_DIR)
  get_filename_component(TC_QRCODE_INPUT_SOURCE_DIR "${QRCODE_SOURCE_DIR}" ABSOLUTE)
  if(NOT EXISTS "${TC_QRCODE_INPUT_SOURCE_DIR}/src/qrcode.c")
    message(FATAL_ERROR "QRCODE_SOURCE_DIR must contain src/qrcode.c")
  endif()
  set(TC_QRCODE_UNPACK_DIR "${CMAKE_BINARY_DIR}/qrcode-unpacked")
  file(REMOVE_RECURSE "${TC_QRCODE_UNPACK_DIR}")
  file(MAKE_DIRECTORY "${TC_QRCODE_UNPACK_DIR}")
  file(COPY "${TC_QRCODE_INPUT_SOURCE_DIR}/" DESTINATION "${TC_QRCODE_UNPACK_DIR}/source")
  set(TC_QRCODE_SOURCE_DIR "${TC_QRCODE_UNPACK_DIR}/source")
else()
  if(QRCODE_SOURCE_ARCHIVE)
    get_filename_component(TC_QRCODE_SOURCE_ARCHIVE "${QRCODE_SOURCE_ARCHIVE}" ABSOLUTE)
  else()
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/sources")
    set(TC_QRCODE_SOURCE_ARCHIVE "${CMAKE_BINARY_DIR}/sources/qrcode-${QRCODE_UPSTREAM_COMMIT}.tar.gz")
    file(DOWNLOAD "${QRCODE_SOURCE_URL}" "${TC_QRCODE_SOURCE_ARCHIVE}"
      EXPECTED_HASH "SHA256=${QRCODE_SOURCE_SHA256}"
      SHOW_PROGRESS STATUS TC_QRCODE_DOWNLOAD_STATUS)
    list(GET TC_QRCODE_DOWNLOAD_STATUS 0 TC_QRCODE_DOWNLOAD_CODE)
    list(GET TC_QRCODE_DOWNLOAD_STATUS 1 TC_QRCODE_DOWNLOAD_MESSAGE)
    if(NOT TC_QRCODE_DOWNLOAD_CODE EQUAL 0)
      message(FATAL_ERROR "Failed to download QRCode source: ${TC_QRCODE_DOWNLOAD_MESSAGE}")
    endif()
  endif()
  file(SHA256 "${TC_QRCODE_SOURCE_ARCHIVE}" TC_QRCODE_ARCHIVE_SHA256)
  if(NOT TC_QRCODE_ARCHIVE_SHA256 STREQUAL QRCODE_SOURCE_SHA256)
    message(FATAL_ERROR "QRCode source SHA-256 mismatch: ${TC_QRCODE_ARCHIVE_SHA256}")
  endif()
  set(TC_QRCODE_UNPACK_DIR "${CMAKE_BINARY_DIR}/qrcode-unpacked")
  file(REMOVE_RECURSE "${TC_QRCODE_UNPACK_DIR}")
  file(MAKE_DIRECTORY "${TC_QRCODE_UNPACK_DIR}")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xzf "${TC_QRCODE_SOURCE_ARCHIVE}"
    WORKING_DIRECTORY "${TC_QRCODE_UNPACK_DIR}" RESULT_VARIABLE TC_QRCODE_EXTRACT_RESULT)
  if(NOT TC_QRCODE_EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to extract QRCode source: ${TC_QRCODE_SOURCE_ARCHIVE}")
  endif()
  file(GLOB TC_QRCODE_EXTRACTED_DIRS "${TC_QRCODE_UNPACK_DIR}/QRCode-*")
  list(LENGTH TC_QRCODE_EXTRACTED_DIRS TC_QRCODE_EXTRACTED_DIR_COUNT)
  if(NOT TC_QRCODE_EXTRACTED_DIR_COUNT EQUAL 1)
    message(FATAL_ERROR "Expected one QRCode source directory")
  endif()
  list(GET TC_QRCODE_EXTRACTED_DIRS 0 TC_QRCODE_SOURCE_DIR)
endif()

find_program(TC_QRCODE_PATCH_EXECUTABLE patch REQUIRED)
execute_process(
  COMMAND "${TC_QRCODE_PATCH_EXECUTABLE}" -p1 --batch --forward -l
    -i "${CMAKE_CURRENT_SOURCE_DIR}/patches/0001-totalcross-header-compat.patch"
  WORKING_DIRECTORY "${TC_QRCODE_SOURCE_DIR}"
  RESULT_VARIABLE TC_QRCODE_PATCH_RESULT OUTPUT_VARIABLE TC_QRCODE_PATCH_OUTPUT
  ERROR_VARIABLE TC_QRCODE_PATCH_ERROR)
if(NOT TC_QRCODE_PATCH_RESULT EQUAL 0)
  message(FATAL_ERROR "Failed to apply qrcode compatibility patch.\n${TC_QRCODE_PATCH_OUTPUT}\n${TC_QRCODE_PATCH_ERROR}")
endif()

add_library(QRCode STATIC "${TC_QRCODE_SOURCE_DIR}/src/qrcode.c")
add_library(QRCode::QRCode ALIAS QRCode)
set_target_properties(QRCode PROPERTIES
  OUTPUT_NAME qrcode
  POSITION_INDEPENDENT_CODE ON
  C_STANDARD 99
  C_STANDARD_REQUIRED ON
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0)
target_include_directories(QRCode PUBLIC
  "$<BUILD_INTERFACE:${TC_QRCODE_SOURCE_DIR}/src>"
  "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
install(TARGETS QRCode ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES "${TC_QRCODE_SOURCE_DIR}/src/qrcode.h" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

if(BUILD_TESTING)
  add_executable(qrcode-smoke-test tests/qrcode_smoke_test.c)
  target_link_libraries(qrcode-smoke-test PRIVATE QRCode)
  add_test(NAME qrcode-smoke-test COMMAND qrcode-smoke-test)
endif()
