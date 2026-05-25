find_path(MbedTLS_INCLUDE_DIR NAMES mbedtls/ssl.h)
find_library(MbedTLS_LIBRARY NAMES mbedtls)
find_library(MbedCrypto_LIBRARY NAMES mbedcrypto)
find_library(MbedX509_LIBRARY NAMES mbedx509)

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

