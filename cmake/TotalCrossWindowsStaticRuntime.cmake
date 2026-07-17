# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

# This file is included before project() so CMP0091 and the runtime abstraction
# are in effect before any MSVC language is enabled.
if(DEFINED CMAKE_C_COMPILER_ID OR DEFINED CMAKE_CXX_COMPILER_ID)
  if(NOT MSVC AND NOT CMAKE_C_SIMULATE_ID STREQUAL "MSVC" AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    return()
  endif()
elseif(NOT WIN32 AND NOT CMAKE_GENERATOR MATCHES "Visual Studio")
  return()
endif()

if(POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded" CACHE STRING
  "MSVC runtime library used by TotalCross static libraries" FORCE)
message(STATUS "TotalCross Windows runtime policy: /MT")
