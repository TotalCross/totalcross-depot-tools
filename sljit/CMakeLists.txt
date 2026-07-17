# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)

if(POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()
project(totalcross-sljit-static VERSION 20260717 LANGUAGES C)

include(GNUInstallDirs)
include(CTest)

set(SLJIT_UPSTREAM_COMMIT "3907e69005ba6e30b225000f24aaef3632f88347")
set(SLJIT_SOURCE_DIR "" CACHE PATH "Directory containing unpacked SLJIT sources")
set(SLJIT_SOURCE_ARCHIVE "" CACHE FILEPATH "SLJIT source archive")
set(SLJIT_SOURCE_URL
  "https://codeload.github.com/zherczeg/sljit/tar.gz/${SLJIT_UPSTREAM_COMMIT}"
  CACHE STRING "SLJIT source archive URL")
set(SLJIT_SOURCE_SHA256
  "f3e299647a610c537296a41d8866f1e7b664401c229e6cdb67a621250086efd9"
  CACHE STRING "Expected SHA-256 for the SLJIT source archive")

if(SLJIT_SOURCE_DIR)
  get_filename_component(TC_SLJIT_SOURCE_DIR "${SLJIT_SOURCE_DIR}" ABSOLUTE)
  if(NOT EXISTS "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitLir.c" OR
     NOT EXISTS "${TC_SLJIT_SOURCE_DIR}/LICENSE")
    message(FATAL_ERROR "SLJIT_SOURCE_DIR must contain sljit_src/sljitLir.c and LICENSE")
  endif()
else()
  if(SLJIT_SOURCE_ARCHIVE)
    get_filename_component(TC_SLJIT_SOURCE_ARCHIVE "${SLJIT_SOURCE_ARCHIVE}" ABSOLUTE)
  else()
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/sources")
    set(TC_SLJIT_SOURCE_ARCHIVE "${CMAKE_BINARY_DIR}/sources/sljit-${SLJIT_UPSTREAM_COMMIT}.tar.gz")
    file(DOWNLOAD "${SLJIT_SOURCE_URL}" "${TC_SLJIT_SOURCE_ARCHIVE}"
      EXPECTED_HASH "SHA256=${SLJIT_SOURCE_SHA256}"
      SHOW_PROGRESS STATUS TC_SLJIT_DOWNLOAD_STATUS)
    list(GET TC_SLJIT_DOWNLOAD_STATUS 0 TC_SLJIT_DOWNLOAD_CODE)
    list(GET TC_SLJIT_DOWNLOAD_STATUS 1 TC_SLJIT_DOWNLOAD_MESSAGE)
    if(NOT TC_SLJIT_DOWNLOAD_CODE EQUAL 0)
      message(FATAL_ERROR "Failed to download SLJIT source: ${TC_SLJIT_DOWNLOAD_MESSAGE}")
    endif()
  endif()
  if(NOT EXISTS "${TC_SLJIT_SOURCE_ARCHIVE}")
    message(FATAL_ERROR "SLJIT source archive does not exist: ${TC_SLJIT_SOURCE_ARCHIVE}")
  endif()
  file(SHA256 "${TC_SLJIT_SOURCE_ARCHIVE}" TC_SLJIT_ARCHIVE_SHA256)
  if(NOT TC_SLJIT_ARCHIVE_SHA256 STREQUAL SLJIT_SOURCE_SHA256)
    message(FATAL_ERROR "SLJIT source SHA-256 mismatch: ${TC_SLJIT_ARCHIVE_SHA256}")
  endif()
  set(TC_SLJIT_UNPACK_DIR "${CMAKE_BINARY_DIR}/sljit-unpacked")
  file(REMOVE_RECURSE "${TC_SLJIT_UNPACK_DIR}")
  file(MAKE_DIRECTORY "${TC_SLJIT_UNPACK_DIR}")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xzf "${TC_SLJIT_SOURCE_ARCHIVE}"
    WORKING_DIRECTORY "${TC_SLJIT_UNPACK_DIR}" RESULT_VARIABLE TC_SLJIT_EXTRACT_RESULT)
  if(NOT TC_SLJIT_EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to extract SLJIT source: ${TC_SLJIT_SOURCE_ARCHIVE}")
  endif()
  set(TC_SLJIT_SOURCE_DIR "${TC_SLJIT_UNPACK_DIR}/sljit-${SLJIT_UPSTREAM_COMMIT}")
  if(NOT EXISTS "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitLir.c")
    message(FATAL_ERROR "Expected extracted SLJIT directory sljit-${SLJIT_UPSTREAM_COMMIT}")
  endif()
endif()

set(TC_SLJIT_PUBLIC_DEFINITIONS
  SLJIT_WX_EXECUTABLE_ALLOCATOR=1
  SLJIT_PROT_EXECUTABLE_ALLOCATOR=0
  SLJIT_ARGUMENT_CHECKS=1
  SLJIT_DEBUG=0
  SLJIT_VERBOSE=0)

if(MSVC)
  if(DEFINED CMAKE_MSVC_RUNTIME_LIBRARY AND
     NOT CMAKE_MSVC_RUNTIME_LIBRARY STREQUAL "" AND
     NOT CMAKE_MSVC_RUNTIME_LIBRARY STREQUAL "MultiThreaded")
    message(FATAL_ERROR "SLJIT requires CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded (/MT)")
  endif()
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded" CACHE STRING "MSVC runtime library" FORCE)
endif()

add_library(SLJIT STATIC "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitLir.c")
add_library(SLJIT::SLJIT ALIAS SLJIT)
set_target_properties(SLJIT PROPERTIES
  OUTPUT_NAME sljit
  POSITION_INDEPENDENT_CODE ON
  C_STANDARD 99
  C_STANDARD_REQUIRED ON)
if(MSVC)
  set_property(TARGET SLJIT PROPERTY MSVC_RUNTIME_LIBRARY MultiThreaded)
endif()
target_include_directories(SLJIT PUBLIC
  "$<BUILD_INTERFACE:${TC_SLJIT_SOURCE_DIR}/sljit_src>"
  "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
target_compile_definitions(SLJIT PUBLIC ${TC_SLJIT_PUBLIC_DEFINITIONS})
if(NOT WIN32)
  find_package(Threads REQUIRED)
  target_link_libraries(SLJIT PUBLIC Threads::Threads)
endif()

install(TARGETS SLJIT ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES
  "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitLir.h"
  "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitConfig.h"
  "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitConfigCPU.h"
  "${TC_SLJIT_SOURCE_DIR}/sljit_src/sljitConfigInternal.h"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
install(FILES "${TC_SLJIT_SOURCE_DIR}/LICENSE"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/licenses/sljit")

if(BUILD_TESTING)
  add_executable(sljit-smoke-test tests/sljit_smoke_test.c)
  if(MSVC)
    set_property(TARGET sljit-smoke-test PROPERTY MSVC_RUNTIME_LIBRARY MultiThreaded)
  endif()
  target_link_libraries(sljit-smoke-test PRIVATE SLJIT::SLJIT)
  add_test(NAME sljit-smoke-test COMMAND sljit-smoke-test)
endif()
