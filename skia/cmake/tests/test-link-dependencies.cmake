# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.16)

include("${CMAKE_CURRENT_LIST_DIR}/../SkiaLinkDependencies.cmake")

macro(reset_skia_features)
  foreach(name
      SKIA_BUILD_USE_ANGLE
      SKIA_BUILD_USE_DAWN
      SKIA_BUILD_USE_DIRECT3D
      SKIA_BUILD_USE_EGL
      SKIA_BUILD_USE_GL
      SKIA_BUILD_USE_METAL
      SKIA_BUILD_USE_OPENCL
      SKIA_BUILD_USE_VULKAN
      SKIA_BUILD_USE_WEBGL
      SKIA_BUILD_USE_X11
      SKIA_BUILD_USE_FONTHOST_MAC
      SKIA_BUILD_USE_FREETYPE
      SKIA_BUILD_USE_SYSTEM_FREETYPE2
      SKIA_BUILD_ENABLE_FONTMGR_FONTCONFIG
      SKIA_BUILD_ENABLE_FONTMGR_WIN_GDI
      SKIA_BUILD_USE_LIBPNG_DECODE
      SKIA_BUILD_USE_LIBPNG_ENCODE
      SKIA_BUILD_USE_SYSTEM_LIBPNG
      SKIA_BUILD_USE_REPOSITORY_ZLIB
      SKIA_BUILD_USE_REPOSITORY_LIBPNG
      SKIA_BUILD_USE_ZLIB
      SKIA_BUILD_USE_SYSTEM_ZLIB
      SKIA_BUILD_NDK_API)
    unset(${name})
  endforeach()
endmacro()

function(assert_requirements label platform architecture expected)
  skia_classify_link_requirements(actual "${platform}" "${architecture}")
  if(NOT "${actual}" STREQUAL "${expected}")
    message(FATAL_ERROR "${label}: expected '${expected}', got '${actual}'")
  endif()
  set(unique "${actual}")
  list(REMOVE_DUPLICATES unique)
  if(NOT "${actual}" STREQUAL "${unique}")
    message(FATAL_ERROR "${label}: duplicate logical requirements in '${actual}'")
  endif()
endfunction()

function(assert_platform_definition platform expected)
  skia_platform_compile_definition(actual "${platform}")
  if(NOT actual STREQUAL expected)
    message(FATAL_ERROR "${platform}: expected platform definition '${expected}', got '${actual}'")
  endif()
endfunction()

function(assert_compile_definitions label platform expected)
  skia_classify_compile_definitions(actual "${platform}")
  if(NOT "${actual}" STREQUAL "${expected}")
    message(FATAL_ERROR "${label}: expected compile definitions '${expected}', got '${actual}'")
  endif()
  set(unique "${actual}")
  list(REMOVE_DUPLICATES unique)
  if(NOT "${actual}" STREQUAL "${unique}")
    message(FATAL_ERROR "${label}: duplicate compile definitions in '${actual}'")
  endif()
endfunction()

function(assert_include_requirements label platform expected)
  skia_classify_include_requirements(actual "${platform}")
  if(NOT "${actual}" STREQUAL "${expected}")
    message(FATAL_ERROR "${label}: expected include requirements '${expected}', got '${actual}'")
  endif()
  set(unique "${actual}")
  list(REMOVE_DUPLICATES unique)
  if(NOT "${actual}" STREQUAL "${unique}")
    message(FATAL_ERROR "${label}: duplicate include requirements in '${actual}'")
  endif()
endfunction()

assert_platform_definition(macos SK_BUILD_FOR_MAC)
assert_platform_definition(ios SK_BUILD_FOR_IOS)
assert_platform_definition(ios-simulator SK_BUILD_FOR_IOS)
assert_platform_definition(android SK_BUILD_FOR_ANDROID)
assert_platform_definition(windows SK_BUILD_FOR_WIN)
assert_platform_definition(linux SK_BUILD_FOR_UNIX)
assert_platform_definition(wasm SK_BUILD_FOR_UNIX)

reset_skia_features()
assert_compile_definitions(vulkan-off-macos macos "SK_BUILD_FOR_MAC")
assert_include_requirements(vulkan-off-macos macos "")
assert_include_requirements(vulkan-off-linux linux "")
assert_include_requirements(vulkan-off-android android "")
assert_include_requirements(vulkan-off-windows windows "")

set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_METAL ON)
set(SKIA_BUILD_USE_VULKAN ON)
assert_compile_definitions(
  vulkan-on-macos macos
  "SK_BUILD_FOR_MAC;SK_GL;SK_METAL;SK_VULKAN"
)
assert_include_requirements(vulkan-on-macos macos "bundled-vulkan-headers")
assert_include_requirements(vulkan-on-linux linux "bundled-vulkan-headers")
assert_include_requirements(vulkan-on-android android "bundled-vulkan-headers")
assert_include_requirements(vulkan-on-windows windows "bundled-vulkan-headers")

reset_skia_features()
set(SKIA_BUILD_USE_LIBPNG_DECODE ON)
set(SKIA_BUILD_USE_SYSTEM_LIBPNG ON)
set(SKIA_BUILD_USE_REPOSITORY_LIBPNG ON)
set(SKIA_BUILD_USE_ZLIB ON)
set(SKIA_BUILD_USE_SYSTEM_ZLIB ON)
set(SKIA_BUILD_USE_REPOSITORY_ZLIB ON)
set(SKIA_BUILD_USE_FONTHOST_MAC ON)
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_METAL ON)
set(SKIA_BUILD_USE_VULKAN ON)
assert_requirements(
  macos-current macos arm64
  "repository-png;repository-zlib;apple-application-services;apple-appkit;apple-opengl;apple-metal;apple-foundation"
)

set(SKIA_BUILD_USE_METAL OFF)
assert_requirements(
  macos-metal-off macos arm64
  "repository-png;repository-zlib;apple-application-services;apple-appkit;apple-opengl"
)

set(SKIA_BUILD_USE_GL OFF)
assert_requirements(
  macos-gl-off macos arm64
  "repository-png;repository-zlib;apple-application-services;apple-appkit"
)

reset_skia_features()
set(SKIA_BUILD_USE_FONTHOST_MAC ON)
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_METAL ON)
assert_requirements(
  ios-current ios arm64
  "apple-core-foundation;apple-image-io;apple-mobile-core-services;apple-core-graphics;apple-core-text;apple-uikit;apple-metal;apple-foundation"
)
assert_requirements(
  ios-simulator-current ios-simulator arm64
  "apple-core-foundation;apple-image-io;apple-mobile-core-services;apple-core-graphics;apple-core-text;apple-uikit;apple-metal;apple-foundation"
)
set(SKIA_BUILD_USE_METAL OFF)
assert_requirements(
  ios-metal-off ios arm64
  "apple-core-foundation;apple-image-io;apple-mobile-core-services;apple-core-graphics;apple-core-text;apple-uikit"
)

reset_skia_features()
set(SKIA_BUILD_USE_LIBPNG_ENCODE ON)
set(SKIA_BUILD_USE_SYSTEM_LIBPNG ON)
set(SKIA_BUILD_USE_REPOSITORY_LIBPNG ON)
set(SKIA_BUILD_USE_ZLIB ON)
set(SKIA_BUILD_USE_SYSTEM_ZLIB ON)
set(SKIA_BUILD_USE_REPOSITORY_ZLIB ON)
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_EGL ON)
set(SKIA_BUILD_USE_VULKAN ON)
set(SKIA_BUILD_USE_OPENCL ON)
set(SKIA_BUILD_ENABLE_FONTMGR_FONTCONFIG ON)
set(SKIA_BUILD_USE_FREETYPE ON)
set(SKIA_BUILD_USE_SYSTEM_FREETYPE2 ON)
assert_requirements(
  linux-current linux x86_64
  "repository-png;repository-zlib;toolchain-dl;toolchain-egl;toolchain-glesv2;toolchain-fontconfig;toolchain-freetype"
)
set(SKIA_BUILD_USE_GL OFF)
assert_requirements(
  linux-gl-off linux x86_64
  "repository-png;repository-zlib;toolchain-dl;toolchain-fontconfig;toolchain-freetype"
)
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_EGL OFF)
set(SKIA_BUILD_USE_X11 ON)
assert_requirements(
  linux-x11-opengl linux x86_64
  "repository-png;repository-zlib;toolchain-dl;toolchain-opengl;toolchain-fontconfig;toolchain-freetype"
)

reset_skia_features()
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_VULKAN ON)
set(SKIA_BUILD_NDK_API 23)
assert_requirements(android-current android arm64-v8a "toolchain-android-log;toolchain-egl;toolchain-glesv2")
set(SKIA_BUILD_USE_GL OFF)
assert_requirements(android-gl-off android arm64-v8a "toolchain-android-log")
set(SKIA_BUILD_NDK_API 26)
assert_requirements(android-api-26 android arm64-v8a "toolchain-android-log;toolchain-android")

reset_skia_features()
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_VULKAN ON)
set(SKIA_BUILD_ENABLE_FONTMGR_WIN_GDI ON)
assert_requirements(
  windows-x64-current windows x64
  "windows-fontsub;windows-ole32;windows-oleaut32;windows-user32;windows-usp10;windows-gdi32;windows-opengl32"
)
assert_requirements(
  windows-arm64-current windows arm64
  "windows-fontsub;windows-ole32;windows-oleaut32;windows-user32;windows-usp10;windows-gdi32"
)
set(SKIA_BUILD_USE_GL OFF)
assert_requirements(
  windows-gl-off windows x64
  "windows-fontsub;windows-ole32;windows-oleaut32;windows-user32;windows-usp10;windows-gdi32"
)

reset_skia_features()
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_WEBGL ON)
assert_requirements(wasm-current wasm wasm32 "")

message(STATUS "Skia compile, include, and link requirement cases passed")
