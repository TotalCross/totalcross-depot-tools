cmake_minimum_required(VERSION 3.16)
project(totalcross_zlib C)

set(ZLIB_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/src/zlib-1.3.1" CACHE PATH "zlib source directory")
add_subdirectory("${ZLIB_SOURCE_DIR}" zlib-build)

