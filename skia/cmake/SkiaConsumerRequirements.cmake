# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

include_guard(GLOBAL)

function(_skia_append_requirement list_var requirement)
  set(items "${${list_var}}")
  list(APPEND items "${requirement}")
  list(REMOVE_DUPLICATES items)
  set(${list_var} "${items}" PARENT_SCOPE)
endfunction()

function(skia_platform_compile_definition output_var platform)
  if(platform STREQUAL "macos")
    set(definition SK_BUILD_FOR_MAC)
  elseif(platform STREQUAL "ios" OR platform STREQUAL "ios-simulator")
    set(definition SK_BUILD_FOR_IOS)
  elseif(platform STREQUAL "android")
    set(definition SK_BUILD_FOR_ANDROID)
  elseif(platform STREQUAL "windows")
    set(definition SK_BUILD_FOR_WIN)
  elseif(platform STREQUAL "linux" OR platform STREQUAL "wasm")
    set(definition SK_BUILD_FOR_UNIX)
  else()
    message(FATAL_ERROR "Unsupported Skia metadata platform '${platform}'")
  endif()
  set(${output_var} "${definition}" PARENT_SCOPE)
endfunction()

function(skia_classify_compile_definitions output_var platform)
  set(definitions "")
  skia_platform_compile_definition(platform_definition "${platform}")
  _skia_append_requirement(definitions "${platform_definition}")

  if(SKIA_BUILD_USE_GL)
    _skia_append_requirement(definitions SK_GL)
  endif()
  if(SKIA_BUILD_USE_METAL)
    _skia_append_requirement(definitions SK_METAL)
  endif()
  if(SKIA_BUILD_USE_VULKAN)
    _skia_append_requirement(definitions SK_VULKAN)
  endif()

  set(${output_var} "${definitions}" PARENT_SCOPE)
endfunction()

function(skia_classify_include_requirements output_var platform)
  set(requirements "")

  if(SKIA_BUILD_USE_VULKAN)
    _skia_append_requirement(requirements bundled-vulkan-headers)
  endif()

  set(${output_var} "${requirements}" PARENT_SCOPE)
endfunction()

function(skia_resolve_include_requirements output_var skia_root platform require_bundled_headers)
  skia_classify_include_requirements(logical_requirements "${platform}")
  set(include_directories "")

  foreach(requirement IN LISTS logical_requirements)
    if(requirement STREQUAL "bundled-vulkan-headers")
      set(vulkan_include_dir "${skia_root}/include/third_party/vulkan")
      set(required_headers "vulkan/vulkan_core.h")
      if(platform STREQUAL "android")
        list(APPEND required_headers "vulkan/vulkan_android.h")
      endif()

      set(bundled_headers_complete ON)
      foreach(required_header IN LISTS required_headers)
        if(NOT EXISTS "${vulkan_include_dir}/${required_header}")
          set(bundled_headers_complete OFF)
          if(require_bundled_headers)
            message(FATAL_ERROR
              "Repository-managed Vulkan-enabled Skia prebuilt is missing required bundled header '${vulkan_include_dir}/${required_header}'"
            )
          endif()
        endif()
      endforeach()

      if(bundled_headers_complete)
        _skia_append_requirement(include_directories "${vulkan_include_dir}")
      endif()
    else()
      message(FATAL_ERROR "Unknown logical Skia include requirement '${requirement}'")
    endif()
  endforeach()

  set(${output_var} "${include_directories}" PARENT_SCOPE)
endfunction()
