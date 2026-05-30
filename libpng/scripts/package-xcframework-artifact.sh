#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: package-xcframework-artifact.sh BUILD_DIR DEVICE_INSTALL_DIR SIMULATOR_INSTALL_DIR PLATFORM_ARCH" >&2
  exit 2
fi

build_dir="$1"
device_install_dir="$2"
simulator_install_dir="$3"
platform_arch="$4"
artifact_name_platform="${platform_arch//\//-}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required to create the libpng XCFramework" >&2
  exit 1
fi

artifact_dir="${build_dir}/artifact/libpng/${platform_arch}"
rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib"

for header_name in png.h pngconf.h pnglibconf.h; do
  if [ ! -f "${device_install_dir}/include/${header_name}" ]; then
    echo "Missing ${device_install_dir}/include/${header_name}" >&2
    exit 1
  fi
  if [ ! -f "${simulator_install_dir}/include/${header_name}" ]; then
    echo "Missing ${simulator_install_dir}/include/${header_name}" >&2
    exit 1
  fi
  cmp -s "${device_install_dir}/include/${header_name}" "${simulator_install_dir}/include/${header_name}" || {
    echo "Device and simulator headers differ for ${header_name}" >&2
    exit 1
  }
  cp "${device_install_dir}/include/${header_name}" "${artifact_dir}/include/"
done

find_static_library() {
  local install_dir="$1"
  local library_path=""

  while IFS= read -r -d '' candidate; do
    library_path="${candidate}"
    break
  done < <(find "${install_dir}/lib" -maxdepth 1 -type f \( -name "libpng*.a" -o -name "png*.lib" -o -name "libpng*.lib" \) -print0)

  if [ -z "${library_path}" ]; then
    echo "No static libpng library found under ${install_dir}/lib" >&2
    exit 1
  fi

  printf '%s\n' "${library_path}"
}

device_library="$(find_static_library "${device_install_dir}")"
simulator_library="$(find_static_library "${simulator_install_dir}")"

xcodebuild -create-xcframework \
  -library "${device_library}" \
  -headers "${device_install_dir}/include" \
  -library "${simulator_library}" \
  -headers "${simulator_install_dir}/include" \
  -output "${artifact_dir}/lib/libpng.xcframework"

cat > "${artifact_dir}/manifest.txt" <<EOF
name=libpng
platform_arch=${platform_arch}
libpng_version=1.6.48
zlib_provider=zlib-ng
format=xcframework
ios_slices=iphoneos/arm64,iphonesimulator/arm64
EOF

tar -C "${build_dir}/artifact" -czf "${build_dir}/libpng-${artifact_name_platform}.tar.gz" "libpng"
echo "${build_dir}/libpng-${artifact_name_platform}.tar.gz"
