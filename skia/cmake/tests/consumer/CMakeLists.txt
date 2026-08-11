# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.16)
project(skia_metal_consumer LANGUAGES CXX)

if(NOT SKIA_MODULE_DIR)
  message(FATAL_ERROR "SKIA_MODULE_DIR must point to the depot-tools Skia CMake modules")
endif()

list(PREPEND CMAKE_MODULE_PATH "${SKIA_MODULE_DIR}")
find_package(Skia REQUIRED)

add_executable(skia-metal-smoke metal-smoke.cpp)
target_compile_features(skia-metal-smoke PRIVATE cxx_std_17)
target_link_libraries(skia-metal-smoke PRIVATE Skia::Skia)
