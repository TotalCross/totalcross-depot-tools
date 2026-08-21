# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)
project(sdl2_depot_consumer C)

if(NOT DEFINED DEPOT_TOOLS_ROOT)
  message(FATAL_ERROR "DEPOT_TOOLS_ROOT is required")
endif()
list(PREPEND CMAKE_MODULE_PATH "${DEPOT_TOOLS_ROOT}/sdl2/cmake")

if(SDL2_TEST_AUTO_FETCH)
  include(AutoFetchSDL2)
  tcvm_auto_fetch_sdl2()
endif()
find_package(SDL2 REQUIRED)

if(NOT TARGET SDL2::SDL2 OR NOT TARGET SDL2::SDL2-static)
  message(FATAL_ERROR "Expected SDL2::SDL2 and SDL2::SDL2-static")
endif()
get_target_property(SDL2_TEST_RESOLVED_ROOT SDL2::SDL2-static TC_SDL2_DEPOT_ROOT)
if(NOT SDL2_TEST_RESOLVED_ROOT STREQUAL SDL2_DEPOT_ROOT)
  message(FATAL_ERROR
    "SDL2 resolved outside the requested depot root: ${SDL2_TEST_RESOLVED_ROOT}")
endif()

add_executable(sdl2-depot-consumer main.c)
target_link_libraries(sdl2-depot-consumer PRIVATE SDL2::SDL2)
