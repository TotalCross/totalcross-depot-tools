#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: package-artifact.sh BUILD_DIR INSTALL_DIR PLATFORM_ARCH" >&2
  exit 2
fi

build_dir="$1"
install_dir="$2"
platform_arch="$3"
artifact_name_platform="${platform_arch//\//-}"

artifact_dir="${build_dir}/artifact/libpng/${platform_arch}"
rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib"

for header_name in png.h pngconf.h pnglibconf.h; do
  if [ ! -f "${install_dir}/include/${header_name}" ]; then
    echo "Missing ${install_dir}/include/${header_name}" >&2
    exit 1
  fi
  cp "${install_dir}/include/${header_name}" "${artifact_dir}/include/"
done

library_count=0
while IFS= read -r -d '' library_path; do
  cp "${library_path}" "${artifact_dir}/lib/"
  library_count=$((library_count + 1))
done < <(find "${install_dir}/lib" -maxdepth 1 -type f \( -name "*.a" -o -name "*.lib" \) -print0)

if [ "${library_count}" -eq 0 ]; then
  echo "No static libpng libraries found under ${install_dir}/lib" >&2
  exit 1
fi

cat > "${artifact_dir}/manifest.txt" <<EOF
name=libpng
platform_arch=${platform_arch}
libpng_version=1.6.48
zlib_provider=zlib-ng
EOF

tar -C "${build_dir}/artifact" -czf "${build_dir}/libpng-${artifact_name_platform}.tar.gz" "libpng"
echo "${build_dir}/libpng-${artifact_name_platform}.tar.gz"
