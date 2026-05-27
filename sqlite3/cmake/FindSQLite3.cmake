get_filename_component(SQLite3_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(SQLITE3_DIR "${SQLite3_DEPENDENCY_DIR}/local" CACHE PATH "SQLite3 prebuilt directory")

foreach(SQLite3_CACHED_VAR SQLite3_INCLUDE_DIR SQLite3_LIBRARY)
  if(DEFINED ${SQLite3_CACHED_VAR})
    string(FIND "${${SQLite3_CACHED_VAR}}" "${SQLITE3_DIR}" SQLite3_CACHED_VAR_DEPOT_INDEX)
    if(NOT SQLite3_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${SQLite3_CACHED_VAR} CACHE)
      unset(${SQLite3_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(SQLite3_INCLUDE_DIR
  NAMES sqlite3.h
  HINTS "${SQLITE3_DIR}/include"
  NO_DEFAULT_PATH
)
find_library(SQLite3_LIBRARY
  NAMES sqlite3
  HINTS "${SQLITE3_DIR}/lib"
  NO_DEFAULT_PATH
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SQLite3
  REQUIRED_VARS SQLite3_INCLUDE_DIR SQLite3_LIBRARY
)

if(SQLite3_FOUND AND NOT TARGET SQLite::SQLite3)
  add_library(SQLite::SQLite3 UNKNOWN IMPORTED)
  set_target_properties(SQLite::SQLite3 PROPERTIES
    IMPORTED_LOCATION "${SQLite3_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${SQLite3_INCLUDE_DIR}"
  )
endif()
