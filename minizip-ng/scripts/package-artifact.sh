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
artifact_name_platform="${platform_arch//\//-}"

artifact_dir="${build_dir}/artifact/minizip-ng/${platform_arch}"
rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib"

for header_name in ioapi.h mz.h mz_zip.h mz_zip_rw.h unzip.h zip.h; do
  if [ ! -f "${install_dir}/include/${header_name}" ]; then
    echo "Missing ${install_dir}/include/${header_name}" >&2
    exit 1
  fi
done

while IFS= read -r -d '' header_path; do
  cp "${header_path}" "${artifact_dir}/include/"
done < <(find "${install_dir}/include" -maxdepth 1 -type f -name "*.h" -print0)

library_count=0
while IFS= read -r -d '' library_path; do
  cp "${library_path}" "${artifact_dir}/lib/"
  library_count=$((library_count + 1))
done < <(find "${install_dir}/lib" -maxdepth 1 -type f \( -name "*.a" -o -name "*.lib" \) -print0)

if [ "${library_count}" -eq 0 ]; then
  echo "No static minizip-ng libraries found under ${install_dir}/lib" >&2
  exit 1
fi

cat > "${artifact_dir}/manifest.txt" <<EOF
name=minizip-ng
platform_arch=${platform_arch}
minizip_ng_version=4.2.2
zlib_ng_version=2.1.6
EOF

tar -C "${build_dir}/artifact" -czf "${build_dir}/minizip-ng-${artifact_name_platform}.tar.gz" "minizip-ng"
echo "${build_dir}/minizip-ng-${artifact_name_platform}.tar.gz"
