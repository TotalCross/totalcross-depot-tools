#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-native-target.sh LIBRARY TARGET [options]

Resolve, configure, build, test, install, and package one CMake native target.

Options:
  --build-dir PATH   Override the resolved build directory.
  --dependency-dir DEPENDENCY=PATH
                     Override one resolved dependency's local artifact directory.
  --operation VALUE  Only build is currently supported (default: build).
  --dry-run          Emit the resolved lower-level command without executing it.
  --verbose          Stream the lower-level build log.
  --help             Show this help text.
EOF
}

if [ "$#" -lt 2 ]; then
  usage >&2
  exit 2
fi

library="$1"
target="$2"
shift 2
build_dir=''
operation='build'
verbose='false'
dry_run='false'
dependency_dirs=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --build-dir|--operation|--dependency-dir)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      case "$1" in
        --build-dir) build_dir="$2" ;;
        --operation) operation="$2" ;;
        --dependency-dir) dependency_dirs+=("$2") ;;
      esac
      shift 2
      ;;
    --verbose)
      verbose='true'
      shift
      ;;
    --dry-run)
      dry_run='true'
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "${operation}" != 'build' ]; then
  echo "build-native-target: unsupported operation ${operation}" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

runner=''
platform=''
platform_family=''
arch=''
build_dir_name=''
build_system=''
configuration=''
generator=''
package_script=''
tests=''
cmake_arguments=''
dependencies=''
docker_image=''
docker_platform=''
qemu='false'
android_ndk_version=''
android_api=''
android_abi=''
android_use_legacy_toolchain='false'
cmake_platform=''
windows_expected_runtime=''
apple_sysroot=''

while IFS='=' read -r key value; do
  key="${key%$'\r'}"
  value="${value%$'\r'}"
  case "${key}" in
    runner|platform|platform_family|arch|build_dir_name|build_system|configuration|generator|package_script|tests|cmake_arguments|dependencies|docker_image|docker_platform|qemu|android_ndk_version|android_api|android_abi|android_use_legacy_toolchain|cmake_platform|windows_expected_runtime|apple_sysroot)
      printf -v "${key}" '%s' "${value}"
      ;;
  esac
done < <(python3 scripts/native-build.py show "${library}" "${target}" --format github-output)

if [ "${build_system}" != 'cmake' ]; then
  echo "build-native-target: ${library} uses ${build_system}; no CMake executor is configured" >&2
  exit 2
fi
if [ -z "${package_script}" ] || [ ! -f "${package_script}" ]; then
  echo "build-native-target: missing package script for ${library}" >&2
  exit 2
fi

if [ -z "${build_dir}" ]; then
  build_dir="${library}/build/${build_dir_name}"
fi
install_dir="${build_dir}/install"
log_path="${build_dir}/build-native-target.log"

cmake_args=''
append_cmake_arg() {
  local quoted=''
  printf -v quoted '%q' "$1"
  cmake_args+=" ${quoted}"
}

while IFS= read -r argument; do
  argument="${argument%$'\r'}"
  [ -n "${argument}" ] || continue
  append_cmake_arg "${argument}"
done < <(python3 -c 'import json, sys; print("\n".join(json.loads(sys.argv[1])))' "${cmake_arguments}")

while IFS=$'\t' read -r variable dependency; do
  variable="${variable%$'\r'}"
  dependency="${dependency%$'\r'}"
  [ -n "${variable}" ] || continue
  dependency_dir="${repo_root}/${dependency}/local/${platform}/${arch}"
  for override in "${dependency_dirs[@]:-}"; do
    [ -n "${override}" ] || continue
    case "${override}" in
      "${dependency}"=*) dependency_dir="${override#*=}" ;;
    esac
  done
  if [ -n "${docker_image}" ]; then
    case "${dependency_dir}" in
      "${repo_root}"/*)
        dependency_dir="/sources/${dependency_dir#"${repo_root}/"}"
        ;;
      *)
        echo "build-native-target: Docker builds require ${dependency} under ${repo_root}; got ${dependency_dir}" >&2
        exit 2
        ;;
    esac
  fi
  append_cmake_arg "-D${variable}=${dependency_dir}"
done < <(python3 -c '
import json
import sys
for name, details in json.loads(sys.argv[1]).items():
    variable = details.get("cmake_variable")
    if variable:
        print(f"{variable}\t{name}")
' "${dependencies}")

case "${platform_family}" in
  android)
    ndk_path="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_BUNDLE:-}}}"
    if [ -z "${ndk_path}" ] && [ -n "${ANDROID_HOME:-}" ]; then
      ndk_path="${ANDROID_HOME}/ndk/${android_ndk_version}"
    fi
    toolchain="${ndk_path}/build/cmake/android.toolchain.cmake"
    if [ -z "${ndk_path}" ]; then
      ndk_path="${ANDROID_HOME:-${HOME}/Android/Sdk}/ndk/${android_ndk_version}"
      toolchain="${ndk_path}/build/cmake/android.toolchain.cmake"
    fi
    if [ "${dry_run}" != true ] && [ ! -f "${toolchain}" ]; then
      echo "build-native-target: Android NDK ${android_ndk_version} is unavailable" >&2
      exit 2
    fi
    export ANDROID_NDK_HOME="${ndk_path}"
    export ANDROID_NDK_ROOT="${ndk_path}"
    export NDK_BUNDLE="${ndk_path}"
    append_cmake_arg "-DCMAKE_TOOLCHAIN_FILE=${toolchain}"
    append_cmake_arg "-DANDROID_ABI=${android_abi}"
    append_cmake_arg "-DANDROID_PLATFORM=android-${android_api}"
    append_cmake_arg "-DANDROID_USE_LEGACY_TOOLCHAIN_FILE=${android_use_legacy_toolchain}"
    ;;
  windows)
    append_cmake_arg '-A'
    append_cmake_arg "${cmake_platform}"
    append_cmake_arg "-DCMAKE_MSVC_RUNTIME_LIBRARY=${windows_expected_runtime}"
    ;;
  apple)
    append_cmake_arg "-DCMAKE_OSX_ARCHITECTURES=${arch}"
    if [ -n "${apple_sysroot}" ]; then
      append_cmake_arg '-DCMAKE_SYSTEM_NAME=iOS'
      append_cmake_arg "-DCMAKE_OSX_SYSROOT=${apple_sysroot}"
      append_cmake_arg '-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO'
    fi
    ;;
esac

run_tests='false'
if [ "${tests}" = true ]; then
  run_tests='true'
fi
command=(
  scripts/build-cmake-multi.sh
  --source-dir "${library}"
  --build-dir "${build_dir}"
  --install-dir "${install_dir}"
  --platform-arch "${platform}/${arch}"
  --generator "${generator}"
  --configuration "${configuration}"
  --cmake-args "${cmake_args# }"
  --run-tests "${run_tests}"
  --package-script "${package_script}"
)
if [ -n "${docker_image}" ]; then
  command+=(--docker-image "${docker_image}" --docker-platform "${docker_platform}")
fi

if [ "${dry_run}" = true ]; then
  python3 - "${library}" "${target}" "${build_dir}" "${log_path}" "${command[@]}" <<'PY'
import json
import sys

library, target, build_dir, log_path, *command = sys.argv[1:]
print(json.dumps({
    "library": library,
    "target": target,
    "build_dir": build_dir,
    "log": log_path,
    "command": command,
}, separators=(",", ":")))
PY
  exit 0
fi

if [ "${qemu}" = true ]; then
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi

mkdir -p "${build_dir}"

if [ "${verbose}" = true ]; then
  "${command[@]}" 2>&1 | tee "${log_path}"
else
  if ! "${command[@]}" >"${log_path}" 2>&1; then
    tail -80 "${log_path}" >&2
    exit 1
  fi
fi

python3 - "${library}" "${target}" "${build_dir}" "${log_path}" <<'PY'
import glob
import json
import os
import sys

library, target, build_dir, log_path = sys.argv[1:]
print(json.dumps({
    "library": library,
    "target": target,
    "artifacts": sorted(glob.glob(os.path.join(build_dir, "*.tar.gz"))),
    "log": log_path,
}, separators=(",", ":")))
PY
