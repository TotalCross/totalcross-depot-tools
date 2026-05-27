get_filename_component(MbedTLS_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(MBEDTLS_DIR "${MbedTLS_DEPENDENCY_DIR}/local" CACHE PATH "mbedTLS prebuilt directory")

foreach(MbedTLS_CACHED_VAR MbedTLS_INCLUDE_DIR MbedTLS_LIBRARY MbedCrypto_LIBRARY MbedX509_LIBRARY)
  if(DEFINED ${MbedTLS_CACHED_VAR})
    string(FIND "${${MbedTLS_CACHED_VAR}}" "${MBEDTLS_DIR}" MbedTLS_CACHED_VAR_DEPOT_INDEX)
    if("${${MbedTLS_CACHED_VAR}}" MATCHES "-NOTFOUND$" OR NOT MbedTLS_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${MbedTLS_CACHED_VAR} CACHE)
      unset(${MbedTLS_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(MbedTLS_INCLUDE_DIR
  NAMES mbedtls/ssl.h
  HINTS "${MBEDTLS_DIR}/include"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(MbedTLS_LIBRARY
  NAMES mbedtls
  HINTS "${MBEDTLS_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(MbedCrypto_LIBRARY
  NAMES mbedcrypto
  HINTS "${MBEDTLS_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(MbedX509_LIBRARY
  NAMES mbedx509
  HINTS "${MBEDTLS_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
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
