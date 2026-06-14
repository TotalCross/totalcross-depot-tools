get_filename_component(SQLite3_DEPENDENCY_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(SQLite3_LOCAL_ROOT "${SQLite3_DEPENDENCY_DIR}/local")

if(NOT DEFINED SQLITE3_RELEASE_TAG AND DEFINED ENV{SQLITE3_RELEASE_TAG})
  set(SQLITE3_RELEASE_TAG "$ENV{SQLITE3_RELEASE_TAG}")
elseif(NOT DEFINED SQLITE3_RELEASE_TAG)
  set(SQLITE3_RELEASE_TAG "sqlite3-3.32.3")
endif()

if(NOT DEFINED SQLITE3_GITHUB_REPO AND DEFINED ENV{SQLITE3_GITHUB_REPO})
  set(SQLITE3_GITHUB_REPO "$ENV{SQLITE3_GITHUB_REPO}")
elseif(NOT DEFINED SQLITE3_GITHUB_REPO)
  set(SQLITE3_GITHUB_REPO "TotalCross/totalcross-depot-tools")
endif()

if(NOT SQLITE3_GITHUB_REPO MATCHES "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
  message(FATAL_ERROR "Invalid SQLite3 GitHub repository value. Expected OWNER/REPO.")
endif()

foreach(SQLite3_RELEASE_TAG_FORBIDDEN " " "{" "}" "/" "\\")
  string(FIND "${SQLITE3_RELEASE_TAG}" "${SQLite3_RELEASE_TAG_FORBIDDEN}" SQLite3_RELEASE_TAG_FORBIDDEN_INDEX)
  if(NOT SQLite3_RELEASE_TAG_FORBIDDEN_INDEX EQUAL -1)
    message(FATAL_ERROR "Invalid SQLite3 release tag value: ${SQLITE3_RELEASE_TAG}")
  endif()
endforeach()
string(FIND "${SQLITE3_RELEASE_TAG}" ".." SQLite3_RELEASE_TAG_PARENT_INDEX)
if(NOT SQLite3_RELEASE_TAG_PARENT_INDEX EQUAL -1)
  message(FATAL_ERROR "Invalid SQLite3 release tag value: ${SQLITE3_RELEASE_TAG}")
endif()

string(SHA256 SQLite3_REPO_HASH "${SQLITE3_GITHUB_REPO}")
string(SUBSTRING "${SQLite3_REPO_HASH}" 0 12 SQLite3_REPO_HASH)
set(SQLite3_NAMESPACE "${SQLITE3_RELEASE_TAG}-${SQLite3_REPO_HASH}")

if(DEFINED ANDROID_ABI)
  set(SQLite3_PLATFORM "android")
  set(SQLite3_ARCH "${ANDROID_ABI}")
elseif(APPLE AND (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone"))
  if(CMAKE_OSX_SYSROOT MATCHES "[Ii][Pp]hone[Ss]imulator")
    set(SQLite3_PLATFORM "ios-simulator")
  else()
    set(SQLite3_PLATFORM "ios")
  endif()
  set(SQLite3_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(SQLite3_ARCH)
    list(GET SQLite3_ARCH 0 SQLite3_ARCH)
  else()
    set(SQLite3_ARCH "arm64")
  endif()
  if(SQLite3_ARCH STREQUAL "aarch64")
    set(SQLite3_ARCH "arm64")
  endif()
elseif(WIN32)
  set(SQLite3_PLATFORM "windows")
  set(SQLite3_WINDOWS_PLATFORM "${CMAKE_VS_PLATFORM_NAME}")
  if(NOT SQLite3_WINDOWS_PLATFORM)
    set(SQLite3_WINDOWS_PLATFORM "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  string(TOLOWER "${SQLite3_WINDOWS_PLATFORM}" SQLite3_WINDOWS_PLATFORM_LOWER)
  if(SQLite3_WINDOWS_PLATFORM_LOWER STREQUAL "win32")
    set(SQLite3_ARCH "x86")
  elseif(SQLite3_WINDOWS_PLATFORM_LOWER STREQUAL "x64")
    set(SQLite3_ARCH "x64")
  elseif(SQLite3_WINDOWS_PLATFORM_LOWER STREQUAL "arm64")
    set(SQLite3_ARCH "arm64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(SQLite3_ARCH "x64")
  else()
    set(SQLite3_ARCH "x86")
  endif()
elseif(APPLE)
  set(SQLite3_PLATFORM "macos")
  set(SQLite3_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  if(SQLite3_ARCH)
    list(GET SQLite3_ARCH 0 SQLite3_ARCH)
  else()
    set(SQLite3_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  if(SQLite3_ARCH STREQUAL "amd64")
    set(SQLite3_ARCH "x86_64")
  elseif(SQLite3_ARCH STREQUAL "aarch64")
    set(SQLite3_ARCH "arm64")
  endif()
elseif(UNIX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(SQLite3_PLATFORM "linux")
  set(SQLite3_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  if(SQLite3_ARCH STREQUAL "amd64")
    set(SQLite3_ARCH "x86_64")
  elseif(SQLite3_ARCH STREQUAL "arm64")
    set(SQLite3_ARCH "aarch64")
  elseif(SQLite3_ARCH STREQUAL "arm" OR SQLite3_ARCH STREQUAL "armv7")
    set(SQLite3_ARCH "armv7l")
  endif()
endif()

set(SQLITE3_DIR "${SQLite3_LOCAL_ROOT}/${SQLite3_NAMESPACE}/${SQLite3_PLATFORM}/${SQLite3_ARCH}" CACHE PATH "SQLite3 prebuilt directory" FORCE)

foreach(SQLite3_CACHED_VAR SQLite3_INCLUDE_DIR SQLite3_LIBRARY)
  if(DEFINED ${SQLite3_CACHED_VAR})
    string(FIND "${${SQLite3_CACHED_VAR}}" "${SQLITE3_DIR}" SQLite3_CACHED_VAR_DEPOT_INDEX)
    if("${${SQLite3_CACHED_VAR}}" MATCHES "-NOTFOUND$" OR NOT SQLite3_CACHED_VAR_DEPOT_INDEX EQUAL 0)
      unset(${SQLite3_CACHED_VAR} CACHE)
      unset(${SQLite3_CACHED_VAR})
    endif()
  endif()
endforeach()

find_path(SQLite3_INCLUDE_DIR
  NAMES sqlite3.h
  HINTS "${SQLITE3_DIR}/include"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
find_library(SQLite3_LIBRARY
  NAMES sqlite3
  HINTS "${SQLITE3_DIR}/lib"
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
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
