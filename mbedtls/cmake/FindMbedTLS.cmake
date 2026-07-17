# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
get_filename_component(MbedTLS_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(MbedTLS_LOCAL_ROOT "${MbedTLS_DEPENDENCY_DIR}/local")

if(DEFINED ANDROID_ABI)
  set(MbedTLS_PLATFORM "android")
  set(MbedTLS_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
  if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
    set(MbedTLS_PLATFORM "ios-simulator")
  else()
    set(MbedTLS_PLATFORM "ios")
  endif()
  set(MbedTLS_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(MbedTLS_ARCH)
    list(GET MbedTLS_ARCH 0 MbedTLS_ARCH)
  else()
    set(MbedTLS_ARCH "arm64")
  endif()
  if(MbedTLS_ARCH STREQUAL "aarch64")
    set(MbedTLS_ARCH "arm64")
  endif()
elseif(WIN32)
  set(MbedTLS_PLATFORM "windows")
  set(MbedTLS_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT MbedTLS_WINDOWS_PLATFORM)
    set(MbedTLS_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${MbedTLS_WINDOWS_PLATFORM}" MbedTLS_WINDOWS_PLATFORM_LOWER)
  if(MbedTLS_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(MbedTLS_ARCH "x86")
  elseif(MbedTLS_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(MbedTLS_ARCH "x64")
  elseif(MbedTLS_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(MbedTLS_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(MbedTLS_ARCH "x64")
  else()
    set(MbedTLS_ARCH "x86")
  endif()
elseif(APPLE)
  set(MbedTLS_PLATFORM "macos")
  set(MbedTLS_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(MbedTLS_ARCH)
    list(GET MbedTLS_ARCH 0 MbedTLS_ARCH)
  else()
    set(MbedTLS_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(MbedTLS_ARCH STREQUAL "amd64")
    set(MbedTLS_ARCH "x86_64")
  elseif(MbedTLS_ARCH STREQUAL "aarch64")
    set(MbedTLS_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(MbedTLS_PLATFORM "linux")
  set(MbedTLS_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(MbedTLS_ARCH STREQUAL "amd64")
    set(MbedTLS_ARCH "x86_64")
  elseif(MbedTLS_ARCH STREQUAL "arm64")
    set(MbedTLS_ARCH "aarch64")
  elseif(MbedTLS_ARCH STREQUAL "arm" OR MbedTLS_ARCH STREQUAL "armv7")
    set(MbedTLS_ARCH "armv7l")
  endif()
endif()

set(MBEDTLS_DIR "${MbedTLS_LOCAL_ROOT}/${MbedTLS_PLATFORM}/${MbedTLS_ARCH}" CACHE PATH "mbedTLS prebuilt directory" FORCE)

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

if(MbedTLS_FOUND)
  if(NOT TARGET MbedTLS::mbedcrypto)
    add_library(MbedTLS::mbedcrypto UNKNOWN IMPORTED)
    set_target_properties(MbedTLS::mbedcrypto PROPERTIES
      IMPORTED_LOCATION "${MbedCrypto_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${MbedTLS_INCLUDE_DIR}"
    )
    if(WIN32)
      set_target_properties(MbedTLS::mbedcrypto PROPERTIES
        INTERFACE_LINK_LIBRARIES "bcrypt"
      )
    endif()
  endif()

  if(NOT TARGET MbedTLS::mbedx509)
    add_library(MbedTLS::mbedx509 UNKNOWN IMPORTED)
    set_target_properties(MbedTLS::mbedx509 PROPERTIES
      IMPORTED_LOCATION "${MbedX509_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${MbedTLS_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES MbedTLS::mbedcrypto
    )
  endif()

  if(NOT TARGET MbedTLS::mbedtls)
    add_library(MbedTLS::mbedtls UNKNOWN IMPORTED)
    set_target_properties(MbedTLS::mbedtls PROPERTIES
      IMPORTED_LOCATION "${MbedTLS_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${MbedTLS_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "MbedTLS::mbedx509;MbedTLS::mbedcrypto"
    )
  endif()
endif()
