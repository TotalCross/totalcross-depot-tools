#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <build-dir> <install-dir> <platform>/<arch>" >&2
  exit 2
fi

build_dir="$1"
install_dir="$2"
platform_arch="$3"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
artifact_name_platform="${platform_arch//\//-}"
artifact_root="${build_dir}/artifact"
artifact_dir="${artifact_root}/sdl3/${platform_arch}"

if [ ! -f "${install_dir}/include/SDL3/SDL.h" ]; then
  echo "Missing ${install_dir}/include/SDL3/SDL.h" >&2
  exit 1
fi
if [ ! -f "${install_dir}/lib/cmake/SDL3/SDL3Config.cmake" ] ||
   [ ! -f "${install_dir}/lib/cmake/SDL3/SDL3staticTargets.cmake" ]; then
  echo "Missing installed SDL3 CMake package metadata under ${install_dir}/lib/cmake/SDL3" >&2
  exit 1
fi

static_library=""
for candidate in \
  "${install_dir}/lib/libSDL3.a" \
  "${install_dir}/lib/SDL3-static.lib" \
  "${install_dir}/lib/SDL3.lib"; do
  if [ -f "${candidate}" ]; then
    static_library="${candidate}"
    break
  fi
done
if [ -z "${static_library}" ]; then
  echo "No SDL3 static library found under ${install_dir}/lib" >&2
  exit 1
fi

if find "${install_dir}" -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.dylib' -o -name '*.dll' \) | grep -q .; then
  echo "SDL3 install contains a shared library" >&2
  exit 1
fi
if find "${install_dir}" -type f -iname '*SDL3_test*' | grep -q .; then
  echo "SDL3 install unexpectedly contains SDL3_test" >&2
  exit 1
fi
if find "${install_dir}/lib/cmake/SDL3" -type f -iname '*shared*targets*.cmake' | grep -q .; then
  echo "SDL3 install unexpectedly contains shared-target exports" >&2
  exit 1
fi
while IFS= read -r metadata; do
  if grep -F -q -e "${repo_root}" -e "${build_dir}" -e "${install_dir}" "${metadata}"; then
    echo "SDL3 CMake metadata contains an absolute workspace, build, or install path: ${metadata}" >&2
    exit 1
  fi
done < <(find "${install_dir}/lib/cmake/SDL3" -type f -name '*.cmake' -print)

rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}"
cp -R "${install_dir}/include" "${artifact_dir}/include"
cp -R "${install_dir}/lib" "${artifact_dir}/lib"

compiler="unknown"
video_backends=""
msvc_runtime="not-applicable"
upstream_cache="${build_dir}/sdl3-build/CMakeCache.txt"
if [ -f "${upstream_cache}" ]; then
  compiler_metadata="$(find "${build_dir}/sdl3-build/CMakeFiles" -name CMakeCCompiler.cmake -type f | head -n 1)"
  if [ -n "${compiler_metadata}" ]; then
    compiler_id="$(sed -n 's/^set(CMAKE_C_COMPILER_ID "\([^"]*\)")/\1/p' "${compiler_metadata}")"
    compiler_version="$(sed -n 's/^set(CMAKE_C_COMPILER_VERSION "\([^"]*\)")/\1/p' "${compiler_metadata}")"
    if [ -n "${compiler_id}" ]; then
      compiler="${compiler_id}-${compiler_version}"
    fi
  fi
  for backend in COCOA METAL X11 WAYLAND KMSDRM DUMMYVIDEO OFFSCREEN VULKAN OPENGL OPENGLES; do
    if grep -q "^SDL_${backend}:BOOL=ON$" "${upstream_cache}"; then
      backend_name="$(printf '%s' "${backend}" | tr '[:upper:]' '[:lower:]')"
      video_backends="${video_backends:+${video_backends},}${backend_name}"
    fi
  done
fi
outer_cache="${build_dir}/CMakeCache.txt"
if [ -f "${outer_cache}" ]; then
  resolved_msvc_runtime="$(sed -n 's/^CMAKE_MSVC_RUNTIME_LIBRARY:[^=]*=//p' "${outer_cache}" | head -n 1)"
  if [ -n "${resolved_msvc_runtime}" ]; then
    msvc_runtime="${resolved_msvc_runtime}"
  fi
fi

cat > "${artifact_dir}/manifest.txt" <<EOF
name=sdl3
version=3.4.16
source_tag=release-3.4.16
source_revision=fa2c02bb6e21974a89ea9824bc53c9932abe5f9c
license=Zlib
platform_arch=${platform_arch}
configuration=Release
static=ON
pic=ON
libc=ON
feature_profile=window-context-only
msvc_runtime=${msvc_runtime}
compiler=${compiler}
video_backends=${video_backends:-platform-default}
static_library=$(basename "${static_library}")
EOF

archive_path="${build_dir}/sdl3-${artifact_name_platform}.tar.gz"
bash "$(dirname "$0")/create-deterministic-archive.sh" \
  "${artifact_root}" "sdl3" "${archive_path}"
echo "${archive_path}"
