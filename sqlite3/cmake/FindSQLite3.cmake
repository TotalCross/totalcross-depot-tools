find_path(SQLite3_INCLUDE_DIR NAMES sqlite3.h)
find_library(SQLite3_LIBRARY NAMES sqlite3)

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

