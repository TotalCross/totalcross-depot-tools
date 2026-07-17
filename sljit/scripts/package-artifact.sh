#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: package-artifact.sh BUILD_DIR INSTALL_DIR PLATFORM_ARCH" >&2
  exit 2
fi

build_dir="$1"
install_dir="$2"
platform_arch="$3"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest_file="${script_dir}/../manifest.yml"
version="$(awk '/^version:/{print $2; exit}' "${manifest_file}")"
commit="3907e69005ba6e30b225000f24aaef3632f88347"
source_sha256="f3e299647a610c537296a41d8866f1e7b664401c229e6cdb67a621250086efd9"

case "${platform_arch}" in
  linux/x86_64|linux/armv7l|linux/aarch64|android/arm64-v8a|macos/arm64)
    library_name="libsljit.a" ;;
  windows/x86|windows/x64|windows/arm64)
    library_name="sljit.lib" ;;
  *)
    echo "Unsupported SLJIT platform/architecture: ${platform_arch}" >&2
    exit 2 ;;
esac

for header in sljitLir.h sljitConfig.h sljitConfigCPU.h sljitConfigInternal.h; do
  [ -f "${install_dir}/include/${header}" ] || {
    echo "Missing installed SLJIT header: ${header}" >&2
    exit 1
  }
done
[ -f "${install_dir}/lib/${library_name}" ] || {
  echo "Missing installed SLJIT library: ${library_name}" >&2
  exit 1
}
[ -f "${install_dir}/share/licenses/sljit/LICENSE" ] || {
  echo "Missing installed SLJIT license" >&2
  exit 1
}

artifact_name_platform="${platform_arch//\//-}"
artifact_root="${build_dir}/artifact/sljit/${platform_arch}"
rm -rf "${artifact_root}"
mkdir -p "${artifact_root}/include" "${artifact_root}/lib" "${artifact_root}/share/licenses/sljit"
for header in sljitLir.h sljitConfig.h sljitConfigCPU.h sljitConfigInternal.h; do
  cp "${install_dir}/include/${header}" "${artifact_root}/include/${header}"
done
cp "${install_dir}/lib/${library_name}" "${artifact_root}/lib/${library_name}"
cp "${install_dir}/share/licenses/sljit/LICENSE" "${artifact_root}/share/licenses/sljit/LICENSE"

{
  echo "name=sljit"
  echo "upstream_commit=${commit}"
  echo "source_sha256=${source_sha256}"
  echo "distribution_version=${version}"
  echo "platform_arch=${platform_arch}"
  echo "build_type=Release"
  echo "executable_allocator=wx"
  echo "argument_checks=enabled"
  case "${platform_arch}" in
    windows/*) echo "msvc_runtime=MT" ;;
    android/arm64-v8a)
      echo "android_abi=arm64-v8a"
      echo "android_ndk=28.2.13676358"
      echo "android_min_sdk=23" ;;
  esac
} > "${artifact_root}/manifest.txt"

tar -C "${build_dir}/artifact" -czf "${build_dir}/sljit-${artifact_name_platform}.tar.gz" sljit
echo "${build_dir}/sljit-${artifact_name_platform}.tar.gz"
