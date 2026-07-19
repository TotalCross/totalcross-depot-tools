#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: scripts/package-native-ios-xcframework.sh LIBRARY" >&2
  exit 2
fi

library="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

policy="$(python3 scripts/native-build.py show "${library}" ios-arm64 --format github-output | awk -F= '$1 == "apple_xcframework" {print substr($0, index($0, "=") + 1)}')"
if [ -z "${policy}" ] || [ "${policy}" = '{}' ]; then
  echo "package-native-ios-xcframework: ${library} has no Apple XCFramework policy" >&2
  exit 2
fi

library_patterns=()
while IFS= read -r library_pattern; do
  [ -n "${library_pattern}" ] || continue
  library_patterns+=("${library_pattern}")
done < <(python3 - "${policy}" <<'PY'
import json
import sys

for name in json.loads(sys.argv[1])["libraries"]:
    print(name)
PY
)
merge="$(python3 - "${policy}" <<'PY'
import json
import sys

print(str(json.loads(sys.argv[1]).get("merge", False)).lower())
PY
)"

device_root="${repo_root}/${library}/build/ios-arm64/install"
simulator_root="${repo_root}/${library}/build/ios-simulator-arm64/install"
device_libraries=()
simulator_libraries=()
for pattern in "${library_patterns[@]}"; do
  shopt -s nullglob
  device_matches=("${device_root}"/lib/${pattern})
  simulator_matches=("${simulator_root}"/lib/${pattern})
  shopt -u nullglob
  if [ "${#device_matches[@]}" -ne 1 ] || [ "${#simulator_matches[@]}" -ne 1 ]; then
    echo "package-native-ios-xcframework: ${library} cannot resolve ${pattern} for both iOS targets" >&2
    exit 1
  fi
  device_libraries+=("${device_matches[0]}")
  simulator_libraries+=("${simulator_matches[0]}")
done

if [ "${merge}" = true ]; then
  package_dir="${repo_root}/${library}/build/package-output"
  mkdir -p "${package_dir}/ios" "${package_dir}/ios-simulator"
  device_library="${package_dir}/ios/${library}.a"
  simulator_library="${package_dir}/ios-simulator/${library}.a"
  libtool -static -o "${device_library}" "${device_libraries[@]}"
  libtool -static -o "${simulator_library}" "${simulator_libraries[@]}"
else
  device_library="${device_libraries[0]}"
  simulator_library="${simulator_libraries[0]}"
fi

output_dir="${repo_root}/${library}/build/${library}-ios.xcframework"
xcodebuild -create-xcframework \
  -library "${device_library}" -headers "${device_root}/include" \
  -library "${simulator_library}" -headers "${simulator_root}/include" \
  -output "${output_dir}"
ditto -c -k --sequesterRsrc --keepParent "${output_dir}" "${output_dir}.zip"
echo "${output_dir}.zip"
