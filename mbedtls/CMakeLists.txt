cmake_minimum_required(VERSION 3.16)
project(totalcross_mbedtls C)

set(MBEDTLS_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/src/mbedtls-3.5.2" CACHE PATH "Mbed TLS source directory")

set(ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)
add_subdirectory("${MBEDTLS_SOURCE_DIR}" mbedtls-build)

