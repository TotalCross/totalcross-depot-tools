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
version="$(awk '/^version:/{print $2; exit}' "${script_dir}/../manifest.yml")"
artifact_name_platform="${platform_arch//\//-}"
artifact_dir="${build_dir}/artifact/qrcode/${platform_arch}"

rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}/include" "${artifact_dir}/lib"
cp -R "${install_dir}/include/." "${artifact_dir}/include/"
cp -R "${install_dir}/lib/." "${artifact_dir}/lib/"
cat > "${artifact_dir}/manifest.txt" <<EOF
name=qrcode
upstream_commit=eafbde494979abc2445c363cc2602230bcbe299c
distribution_version=${version}
platform_arch=${platform_arch}
EOF
tar -C "${build_dir}/artifact" -czf "${build_dir}/qrcode-${artifact_name_platform}.tar.gz" qrcode
echo "${build_dir}/qrcode-${artifact_name_platform}.tar.gz"
