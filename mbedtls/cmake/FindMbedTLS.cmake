get_filename_component(MbedTLS_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(MBEDTLS_DIR "${MbedTLS_DEPENDENCY_DIR}/local" CACHE PATH "mbedTLS prebuilt directory")

find_path(MbedTLS_INCLUDE_DIR
  NAMES mbedtls/ssl.h
  HINTS "${MBEDTLS_DIR}/include"
)
find_library(MbedTLS_LIBRARY
  NAMES mbedtls
  HINTS "${MBEDTLS_DIR}/lib"
)
find_library(MbedCrypto_LIBRARY
  NAMES mbedcrypto
  HINTS "${MBEDTLS_DIR}/lib"
)
find_library(MbedX509_LIBRARY
  NAMES mbedx509
  HINTS "${MBEDTLS_DIR}/lib"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MbedTLS
  REQUIRED_VARS MbedTLS_INCLUDE_DIR MbedTLS_LIBRARY MbedCrypto_LIBRARY MbedX509_LIBRARY
)

if(MbedTLS_FOUND AND NOT TARGET MbedTLS::mbedtls)
  add_library(MbedTLS::mbedtls UNKNOWN IMPORTED)
  set_target_properties(MbedTLS::mbedtls PROPERTIES
    IMPORTED_LOCATION "${MbedTLS_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${MbedTLS_INCLUDE_DIR}"
  )
endif()
