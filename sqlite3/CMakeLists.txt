cmake_minimum_required(VERSION 3.16)
project(totalcross_sqlite3 C)

set(SQLITE3_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/src/sqlite-amalgamation-3320300" CACHE PATH "SQLite amalgamation source directory")

add_library(sqlite3 STATIC
  "${SQLITE3_SOURCE_DIR}/sqlite3.c"
)

target_include_directories(sqlite3 PUBLIC
  "$<BUILD_INTERFACE:${SQLITE3_SOURCE_DIR}>"
  "$<INSTALL_INTERFACE:include>"
)

target_compile_definitions(sqlite3 PRIVATE
  SQLITE_ENABLE_COLUMN_METADATA
  SQLITE_ENABLE_FTS5
  SQLITE_ENABLE_RTREE
)

install(TARGETS sqlite3 ARCHIVE DESTINATION lib)
install(FILES
  "${SQLITE3_SOURCE_DIR}/sqlite3.h"
  "${SQLITE3_SOURCE_DIR}/sqlite3ext.h"
  DESTINATION include
)

