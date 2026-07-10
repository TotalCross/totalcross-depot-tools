cmake_minimum_required(VERSION 3.16)

project(totalcross-axtls-static VERSION 2.1.5 LANGUAGES C)
set(AXTLS_UPSTREAM_VERSION "2.1.5")
set(AXTLS_DISTRIBUTION_VERSION "2.1.5-tc.1")

include(GNUInstallDirs)
include(CTest)

set(AXTLS_SOURCE_DIR "" CACHE PATH "Directory containing an axTLS 2.1.5 source tree")
set(AXTLS_SOURCE_ARCHIVE "" CACHE FILEPATH "axTLS 2.1.5 source archive")
set(AXTLS_SOURCE_URL
  "https://sourceforge.net/projects/axtls/files/2.1.5/axTLS-2.1.5.tar.gz/download"
  CACHE STRING "axTLS 2.1.5 source archive URL"
)
set(AXTLS_SOURCE_SHA256
  "cf00b07617bfbf903cbe60821b54dc000415fae737f1db84b7f8da69537a2910"
  CACHE STRING "Expected SHA-256 for the axTLS 2.1.5 source archive"
)

if(AXTLS_SOURCE_DIR)
  get_filename_component(TC_AXTLS_INPUT_SOURCE_DIR "${AXTLS_SOURCE_DIR}" ABSOLUTE)
  if(NOT EXISTS "${TC_AXTLS_INPUT_SOURCE_DIR}/crypto/aes.c")
    message(FATAL_ERROR "AXTLS_SOURCE_DIR must contain crypto/ and ssl/ from axTLS 2.1.5")
  endif()
  set(TC_AXTLS_UNPACK_DIR "${CMAKE_BINARY_DIR}/axtls-unpacked")
  file(REMOVE_RECURSE "${TC_AXTLS_UNPACK_DIR}")
  file(MAKE_DIRECTORY "${TC_AXTLS_UNPACK_DIR}")
  file(COPY "${TC_AXTLS_INPUT_SOURCE_DIR}/"
    DESTINATION "${TC_AXTLS_UNPACK_DIR}/axtls-code")
  set(TC_AXTLS_SOURCE_DIR "${TC_AXTLS_UNPACK_DIR}/axtls-code")
else()
  if(AXTLS_SOURCE_ARCHIVE)
    get_filename_component(TC_AXTLS_SOURCE_ARCHIVE "${AXTLS_SOURCE_ARCHIVE}" ABSOLUTE)
  else()
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/sources")
    set(TC_AXTLS_SOURCE_ARCHIVE "${CMAKE_BINARY_DIR}/sources/axTLS-2.1.5.tar.gz")
    file(DOWNLOAD "${AXTLS_SOURCE_URL}" "${TC_AXTLS_SOURCE_ARCHIVE}"
      EXPECTED_HASH "SHA256=${AXTLS_SOURCE_SHA256}"
      SHOW_PROGRESS
      STATUS TC_AXTLS_DOWNLOAD_STATUS
    )
    list(GET TC_AXTLS_DOWNLOAD_STATUS 0 TC_AXTLS_DOWNLOAD_CODE)
    list(GET TC_AXTLS_DOWNLOAD_STATUS 1 TC_AXTLS_DOWNLOAD_MESSAGE)
    if(NOT TC_AXTLS_DOWNLOAD_CODE EQUAL 0)
      message(FATAL_ERROR "Failed to download axTLS source: ${TC_AXTLS_DOWNLOAD_MESSAGE}")
    endif()
  endif()

  file(SHA256 "${TC_AXTLS_SOURCE_ARCHIVE}" TC_AXTLS_ARCHIVE_SHA256)
  if(NOT TC_AXTLS_ARCHIVE_SHA256 STREQUAL AXTLS_SOURCE_SHA256)
    message(FATAL_ERROR "axTLS source SHA-256 mismatch: ${TC_AXTLS_ARCHIVE_SHA256}")
  endif()

  set(TC_AXTLS_UNPACK_DIR "${CMAKE_BINARY_DIR}/axtls-unpacked")
  file(REMOVE_RECURSE "${TC_AXTLS_UNPACK_DIR}")
  file(MAKE_DIRECTORY "${TC_AXTLS_UNPACK_DIR}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "${TC_AXTLS_SOURCE_ARCHIVE}"
    WORKING_DIRECTORY "${TC_AXTLS_UNPACK_DIR}"
    RESULT_VARIABLE TC_AXTLS_EXTRACT_RESULT
  )
  if(NOT TC_AXTLS_EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to extract axTLS archive: ${TC_AXTLS_SOURCE_ARCHIVE}")
  endif()
  set(TC_AXTLS_SOURCE_DIR "${TC_AXTLS_UNPACK_DIR}/axtls-code")
endif()

if(NOT EXISTS "${TC_AXTLS_SOURCE_DIR}/crypto/aes.c" OR
   NOT EXISTS "${TC_AXTLS_SOURCE_DIR}/ssl/tls1.c")
  message(FATAL_ERROR "AXTLS_SOURCE_DIR must contain crypto/ and ssl/ from axTLS 2.1.5")
endif()

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/config/config.h.in"
  "${TC_AXTLS_SOURCE_DIR}/ssl/config.h" COPYONLY)
foreach(TC_AXTLS_EXTENSION axtls.h axtls_port.h axtls_port.c)
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/extensions/${TC_AXTLS_EXTENSION}"
    "${TC_AXTLS_SOURCE_DIR}/ssl/${TC_AXTLS_EXTENSION}" COPYONLY)
endforeach()
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/extensions/md2.c"
  "${TC_AXTLS_SOURCE_DIR}/crypto/md2.c" COPYONLY)
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/extensions/pbkdf2.c"
  "${TC_AXTLS_SOURCE_DIR}/crypto/pbkdf2.c" COPYONLY)
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/extensions/axtls_pbkdf2.h"
  "${TC_AXTLS_SOURCE_DIR}/crypto/axtls_pbkdf2.h" COPYONLY)

find_program(TC_AXTLS_PATCH_EXECUTABLE patch REQUIRED)
foreach(TC_AXTLS_PATCH
    0001-totalcross-functional-and-port-hooks.patch
    0002-harden-hmac-sha1.patch)
  execute_process(
    COMMAND "${TC_AXTLS_PATCH_EXECUTABLE}" -p1 --batch --forward -l
      -i "${CMAKE_CURRENT_SOURCE_DIR}/patches/${TC_AXTLS_PATCH}"
    WORKING_DIRECTORY "${TC_AXTLS_SOURCE_DIR}"
    RESULT_VARIABLE TC_AXTLS_PATCH_RESULT
    OUTPUT_VARIABLE TC_AXTLS_PATCH_OUTPUT
    ERROR_VARIABLE TC_AXTLS_PATCH_ERROR
  )
  if(NOT TC_AXTLS_PATCH_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to apply ${TC_AXTLS_PATCH}.\n${TC_AXTLS_PATCH_OUTPUT}\n${TC_AXTLS_PATCH_ERROR}")
  endif()
endforeach()

set(TC_AXTLS_SOURCES
  crypto/aes.c crypto/bigint.c crypto/crypto_misc.c crypto/hmac.c crypto/pbkdf2.c
  crypto/md2.c crypto/md5.c crypto/rc4.c crypto/rsa.c crypto/sha1.c
  crypto/sha256.c crypto/sha384.c crypto/sha512.c
  ssl/asn1.c ssl/loader.c ssl/openssl.c ssl/os_port.c ssl/p12.c
  ssl/tls1.c ssl/tls1_clnt.c ssl/tls1_svr.c ssl/x509.c ssl/axtls_port.c
)
list(TRANSFORM TC_AXTLS_SOURCES PREPEND "${TC_AXTLS_SOURCE_DIR}/")

add_library(AxTLS STATIC ${TC_AXTLS_SOURCES})
add_library(AxTLS::AxTLS ALIAS AxTLS)
set_target_properties(AxTLS PROPERTIES
  OUTPUT_NAME axtls
  POSITION_INDEPENDENT_CODE ON
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 13.0
)
target_include_directories(AxTLS
  PUBLIC
    "$<BUILD_INTERFACE:${TC_AXTLS_SOURCE_DIR}/ssl>"
    "$<BUILD_INTERFACE:${TC_AXTLS_SOURCE_DIR}/crypto>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/axtls>"
)

if(WIN32)
  # MSVC does not provide the C99 <stdbool.h> header used by axTLS.
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/extensions/windows/stdbool.h"
    "${TC_AXTLS_SOURCE_DIR}/ssl/stdbool.h" COPYONLY)
  target_compile_definitions(AxTLS PRIVATE WIN32)
  target_link_libraries(AxTLS PRIVATE ws2_32)
endif()

file(GLOB TC_AXTLS_CRYPTO_HEADERS "${TC_AXTLS_SOURCE_DIR}/crypto/*.h")
file(GLOB TC_AXTLS_SSL_HEADERS "${TC_AXTLS_SOURCE_DIR}/ssl/*.h")
install(TARGETS AxTLS ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES ${TC_AXTLS_CRYPTO_HEADERS} ${TC_AXTLS_SSL_HEADERS}
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/axtls")

if(BUILD_TESTING)
  add_executable(axtls-port-hooks-test tests/port_hooks_test.c)
  target_link_libraries(axtls-port-hooks-test PRIVATE AxTLS)
  add_test(NAME axtls-port-hooks-test COMMAND axtls-port-hooks-test)
  add_executable(axtls-pbkdf2-test tests/pbkdf2_test.c)
  target_link_libraries(axtls-pbkdf2-test PRIVATE AxTLS)
  add_test(NAME axtls-pbkdf2-test COMMAND axtls-pbkdf2-test)
endif()
