cmake_minimum_required(VERSION 3.16)
project(totalcross_sqlite3_see C)

set(SQLITE_SEE_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/src/see" CACHE PATH "SQLite SEE source directory")

find_file(SQLITE_SEE_SOURCE_FILE
  NAMES sqlite3.c
  PATHS "${SQLITE_SEE_SOURCE_DIR}"
  PATH_SUFFIXES . sqlite-amalgamation see
)

if(NOT SQLITE_SEE_SOURCE_FILE)
  message(FATAL_ERROR "sqlite3.c was not found under ${SQLITE_SEE_SOURCE_DIR}")
endif()

get_filename_component(SQLITE_SEE_INCLUDE_DIR "${SQLITE_SEE_SOURCE_FILE}" DIRECTORY)

add_library(sqlite3-see STATIC "${SQLITE_SEE_SOURCE_FILE}")

target_include_directories(sqlite3-see PUBLIC
  "$<BUILD_INTERFACE:${SQLITE_SEE_INCLUDE_DIR}>"
  "$<INSTALL_INTERFACE:include>"
)

target_compile_definitions(sqlite3-see PRIVATE
  SQLITE_HAS_CODEC
  SQLITE_ENABLE_COLUMN_METADATA
  SQLITE_ENABLE_FTS5
  SQLITE_ENABLE_RTREE
)

install(TARGETS sqlite3-see ARCHIVE DESTINATION lib)
install(FILES
  "${SQLITE_SEE_INCLUDE_DIR}/sqlite3.h"
  "${SQLITE_SEE_INCLUDE_DIR}/sqlite3ext.h"
  DESTINATION include
)
