# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)
project(native_build_zlib_consumer LANGUAGES C)

if(NOT DEFINED DEPOT_TOOLS_ROOT)
  message(FATAL_ERROR "DEPOT_TOOLS_ROOT must point to totalcross-depot-tools")
endif()

list(PREPEND CMAKE_MODULE_PATH "${DEPOT_TOOLS_ROOT}/zlib/cmake")
find_package(ZLIB REQUIRED)

add_executable(native_build_zlib_consumer main.c)
target_link_libraries(native_build_zlib_consumer PRIVATE ZLIB::ZLIB)
