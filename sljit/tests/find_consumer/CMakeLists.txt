# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)
project(sljit-find-consumer LANGUAGES C)

include(CTest)
get_filename_component(TC_DEPOT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${TC_DEPOT_ROOT}/cmake")
find_package(SLJIT REQUIRED)

add_executable(sljit-find-consumer main.c)
target_link_libraries(sljit-find-consumer PRIVATE SLJIT::SLJIT)
if(BUILD_TESTING)
  add_test(NAME sljit-find-consumer COMMAND sljit-find-consumer)
endif()
