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
artifact_dir="${build_dir}/artifact/axtls/${platform_arch}"

rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib"
cp -R "${install_dir}/include/." "${artifact_dir}/include/"
cp -R "${install_dir}/lib/." "${artifact_dir}/lib/"

cat > "${artifact_dir}/manifest.txt" <<EOF
name=axtls
version=2.1.5
platform_arch=${platform_arch}
port_hooks=per-ssl-context
EOF

tar -C "${build_dir}/artifact" -czf "${build_dir}/axtls-${artifact_name_platform}.tar.gz" axtls
echo "${build_dir}/axtls-${artifact_name_platform}.tar.gz"
