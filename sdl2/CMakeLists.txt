# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/TotalCrossWindowsStaticRuntime.cmake")
project(totalcross-sdl2-static VERSION 2.32.8 LANGUAGES C)
include(FetchContent)
include(GNUInstallDirs)
set(SDL2_SOURCE_DIR "" CACHE PATH "Existing upstream source directory")
# TC_DEPOT_SCAFFOLD_TODO: declare source, build static target, and install files.
message(FATAL_ERROR "Complete sdl2/CMakeLists.txt before building")
