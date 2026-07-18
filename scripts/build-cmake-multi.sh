#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-cmake-multi.sh [options]

Configure, build, optionally test, install, and package a native CMake library.

Required options:
  --source-dir PATH        CMake source directory.
  --build-dir PATH         CMake build directory.
  --install-dir PATH       Installation directory.
  --platform-arch VALUE    Package platform and architecture, for example linux/x86_64.
  --package-script PATH    Artifact packaging script.

Optional options:
  --generator VALUE        CMake generator (default: Ninja).
  --configuration VALUE    Build configuration (default: Release).
  --cmake-args VALUE       Additional CMake arguments as shell words.
  --run-tests VALUE        Run CTest when true (default: false).
  --docker-image VALUE     Docker image to execute the build in.
  --docker-platform VALUE  Docker platform to execute the build on.
  --help                   Show this help text.

docker-image and docker-platform must either both be empty or both be set.
EOF
}

source_dir=''
build_dir=''
install_dir=''
platform_arch=''
generator='Ninja'
configuration='Release'
cmake_args=''
run_tests='false'
docker_image=''
docker_platform=''
package_script=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-dir|--build-dir|--install-dir|--platform-arch|--generator|--configuration|--cmake-args|--run-tests|--docker-image|--docker-platform|--package-script)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      case "$1" in
        --source-dir) source_dir="$2" ;;
        --build-dir) build_dir="$2" ;;
        --install-dir) install_dir="$2" ;;
        --platform-arch) platform_arch="$2" ;;
        --generator) generator="$2" ;;
        --configuration) configuration="$2" ;;
        --cmake-args) cmake_args="$2" ;;
        --run-tests) run_tests="$2" ;;
        --docker-image) docker_image="$2" ;;
        --docker-platform) docker_platform="$2" ;;
        --package-script) package_script="$2" ;;
      esac
      shift 2
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

for required_option in source_dir build_dir install_dir platform_arch package_script; do
  if [ -z "${!required_option}" ]; then
    echo "Missing required option --${required_option//_/-}" >&2
    usage >&2
    exit 2
  fi
done

case "${run_tests}" in
  true|false) ;;
  *)
    echo '--run-tests must be true or false.' >&2
    exit 2
    ;;
esac

if { [ -n "${docker_image}" ] && [ -z "${docker_platform}" ]; } || { [ -z "${docker_image}" ] && [ -n "${docker_platform}" ]; }; then
  echo 'docker-image and docker-platform must either both be empty or both be set.' >&2
  exit 2
fi

printf -v source_dir_quoted '%q' "${source_dir}"
printf -v build_dir_quoted '%q' "${build_dir}"
printf -v install_dir_quoted '%q' "${install_dir}"
printf -v platform_arch_quoted '%q' "${platform_arch}"
printf -v generator_quoted '%q' "${generator}"
printf -v configuration_quoted '%q' "${configuration}"
printf -v package_script_quoted '%q' "${package_script}"

build_command=$(cat <<EOF
cmake -S ${source_dir_quoted} -B ${build_dir_quoted} -DCMAKE_BUILD_TYPE=Release ${cmake_args} -G ${generator_quoted}
cmake --build ${build_dir_quoted} --config ${configuration_quoted}
if [ ${run_tests} = true ]; then
  ctest --test-dir ${build_dir_quoted} -C ${configuration_quoted} --output-on-failure
fi
cmake --install ${build_dir_quoted} --config ${configuration_quoted} --prefix ${install_dir_quoted}
bash ${package_script_quoted} ${build_dir_quoted} ${install_dir_quoted} ${platform_arch_quoted}
EOF
)

if [ -n "${docker_image}" ]; then
  workspace="${GITHUB_WORKSPACE:-$PWD}"
  docker run --rm --platform "${docker_platform}" -v "${workspace}:/sources" -w /sources -t "${docker_image}" bash -lc "${build_command}"
else
  bash -lc "${build_command}"
fi
