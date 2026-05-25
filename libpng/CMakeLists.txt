cmake_minimum_required(VERSION 3.16)
project(totalcross_libpng C)

set(LIBPNG_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/src/libpng-1.6.43" CACHE PATH "libpng source directory")
set(PNG_TESTS OFF CACHE BOOL "" FORCE)
set(PNG_SHARED OFF CACHE BOOL "" FORCE)
set(PNG_STATIC ON CACHE BOOL "" FORCE)
add_subdirectory("${LIBPNG_SOURCE_DIR}" libpng-build)

