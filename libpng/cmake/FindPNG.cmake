find_path(PNG_INCLUDE_DIR NAMES png.h)
find_library(PNG_LIBRARY NAMES png libpng)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PNG
  REQUIRED_VARS PNG_INCLUDE_DIR PNG_LIBRARY
)

if(PNG_FOUND AND NOT TARGET PNG::PNG)
  add_library(PNG::PNG UNKNOWN IMPORTED)
  set_target_properties(PNG::PNG PROPERTIES
    IMPORTED_LOCATION "${PNG_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${PNG_INCLUDE_DIR}"
  )
endif()

