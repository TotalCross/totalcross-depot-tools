#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKIA_DIR="${SKIA_DIR:-$ROOT_DIR/skia}"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-$ROOT_DIR/depot_tools}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out}"
STAGING_DIR="${STAGING_DIR:-$ROOT_DIR/staging}"
RPI_ROOT="${RPI_ROOT:-$ROOT_DIR/linux/rpi}"
NDK_BUNDLE="${NDK_BUNDLE:-}"

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_skia_checkout() {
  [[ -d "$SKIA_DIR" ]] || die "missing Skia checkout at $SKIA_DIR"
  [[ -f "$SKIA_DIR/tools/git-sync-deps" ]] || die "invalid Skia checkout at $SKIA_DIR"
}

require_depot_tools_checkout() {
  [[ -d "$DEPOT_TOOLS_DIR" ]] || die "missing depot_tools checkout at $DEPOT_TOOLS_DIR"
}

resolve_gn() {
  require_depot_tools_checkout

  if [[ -x "$SKIA_DIR/bin/gn" ]]; then
    echo "$SKIA_DIR/bin/gn"
    return 0
  fi

  if [[ -x "$DEPOT_TOOLS_DIR/gn" ]]; then
    echo "$DEPOT_TOOLS_DIR/gn"
    return 0
  fi

  if command -v gn >/dev/null 2>&1; then
    command -v gn
    return 0
  fi

  die "could not find 'gn'. Install depot_tools or use a Skia checkout that contains bin/gn."
}

sync_skia_deps() {
  require_cmd python3
  require_skia_checkout
  require_depot_tools_checkout

  pushd "$SKIA_DIR" >/dev/null
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  python3 tools/git-sync-deps
  popd >/dev/null
}

prepare_dirs() {
  mkdir -p "$DIST_DIR"
  mkdir -p "$OUT_DIR"
  mkdir -p "$STAGING_DIR/modules/skia/src/gpu"
}

stage_dev_subset() {
  require_cmd rsync
  prepare_dirs

  rsync -a --delete "$SKIA_DIR/include/" "$STAGING_DIR/modules/skia/include/"
  rsync -a --delete "$SKIA_DIR/src/gpu/gl/" "$STAGING_DIR/modules/skia/src/gpu/gl/"
}

copy_build_manifest_if_present() {
  local build_dir="$1"

  if [[ -f "$build_dir/build_config_manifest.md" ]]; then
    mkdir -p "$STAGING_DIR/modules/skia/out"
    cp "$build_dir/build_config_manifest.md" "$STAGING_DIR/modules/skia/out/$(basename "$build_dir")-build_config_manifest.md"
  fi
}

macos_gn_args() {
  local target_cpu="$1"
  cat <<EOF
target_os="mac"
is_debug=false
is_official_build=true
target_cpu="${target_cpu}"
skia_enable_gpu=true
skia_enable_pdf=false
skia_enable_tools=false
skia_use_opencl=false
skia_use_sdl=false
skia_use_libwebp=false
skia_use_libwebp_encode=false
skia_use_libwebp_decode=false
skia_use_libjpeg_turbo=true
skia_use_system_libjpeg_turbo=false
skia_use_libpng=true
skia_use_system_libpng=false
skia_use_zlib=true
skia_use_system_zlib=false
skia_use_fontconfig=true
skia_use_harfbuzz=true
skia_use_system_harfbuzz=false
skia_use_expat=false
skia_use_system_icu=false
extra_cflags=["-O3","-Wno-error","-mmacosx-version-min=11.0"]
extra_cxxflags=["-O3","-Wno-error","-mmacosx-version-min=11.0"]
EOF
}

build_skia_macos() {
  local target_cpu="$1"
  local artifact_name="$2"
  local build_dir="$OUT_DIR/macos-${target_cpu}"
  local gn_bin

  require_cmd ninja
  require_skia_checkout
  require_depot_tools_checkout
  prepare_dirs
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  sync_skia_deps
  gn_bin=$(resolve_gn)

  "$gn_bin" gen "$build_dir" --args="$(macos_gn_args "$target_cpu")"
  ninja -C "$build_dir" skia

  cp "$build_dir/libskia.a" "$DIST_DIR/$artifact_name"
  stage_dev_subset
  copy_build_manifest_if_present "$build_dir"

  echo "Created artifact:"
  echo "  $DIST_DIR/$artifact_name"
}

linux_x86_64_gn_args() {
  cat <<EOF
target_os="linux"
target_cpu="x64"
is_debug=false
is_official_build=true
skia_use_libwebp=false
skia_enable_gpu=true
extra_cflags=["-O3","-Wno-error","-DNDEBUG"]
skia_use_opencl=false
skia_enable_pdf=false
EOF
}

build_skia_linux_x86_64() {
  local build_dir="$OUT_DIR/linux-x86_64"
  local gn_bin

  require_cmd ninja
  require_skia_checkout
  require_depot_tools_checkout
  prepare_dirs
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  sync_skia_deps
  gn_bin=$(resolve_gn)

  "$gn_bin" gen "$build_dir" --args="$(linux_x86_64_gn_args)"
  ninja -C "$build_dir" skia

  cp "$build_dir/libskia.a" "$DIST_DIR/libskia-linux-x86_64.a"
  stage_dev_subset
  copy_build_manifest_if_present "$build_dir"

  echo "Created artifact:"
  echo "  $DIST_DIR/libskia-linux-x86_64.a"
}

linux_armv7_gn_args() {
  cat <<EOF
target_os="linux"
target_cpu="arm"
cc="clang-9"
cxx="clang++-9"
skia_use_egl=true
skia_enable_gpu=true
skia_use_libjpeg_turbo=false
is_official_build=true
skia_use_freetype=true
skia_use_zlib=false
skia_use_angle=false
skia_use_expat=false
skia_use_icu=false
skia_use_libpng=false
skia_use_libwebp=false
skia_use_lua=false
skia_use_opencl=false
skia_use_piex=false
skia_use_metal=false
skia_enable_flutter_defines=false
skia_enable_fontmgr_empty=false
skia_enable_pdf=false
skia_enable_vulkan_debug_layers=false
skia_enable_tools=false
skia_use_sfntly=false
is_debug=false
extra_cflags=["-O3","-target","armv7a-linux","-mfloat-abi=hard","-mfpu=neon","--sysroot=${RPI_ROOT}","-I${RPI_ROOT}/usr/include/c++/4.9","-I${RPI_ROOT}/usr/include/arm-linux-gnueabihf","-I${RPI_ROOT}/usr/include/arm-linux-gnueabihf/c++/4.9","-I${RPI_ROOT}/usr/include/freetype2","-DSKIA_C_DLL"]
extra_asmflags=["-g","-target","armv7a-linux","-mfloat-abi=hard","-mfpu=neon"]
EOF
}

build_skia_linux_armv7l() {
  local build_dir="$OUT_DIR/linux-armv7l"
  local gn_bin

  require_cmd ninja
  require_skia_checkout
  require_depot_tools_checkout
  [[ -d "$RPI_ROOT" ]] || die "missing RPI_ROOT at $RPI_ROOT"
  prepare_dirs
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  sync_skia_deps
  gn_bin=$(resolve_gn)

  "$gn_bin" gen "$build_dir" --args="$(linux_armv7_gn_args)"
  ninja -C "$build_dir" skia

  cp "$build_dir/libskia.a" "$DIST_DIR/libskia-linux-armv7l.a"
  stage_dev_subset
  copy_build_manifest_if_present "$build_dir"

  echo "Created artifact:"
  echo "  $DIST_DIR/libskia-linux-armv7l.a"
}

android_gn_args() {
  local target_cpu="$1"
  [[ -n "$NDK_BUNDLE" ]] || die "NDK_BUNDLE is empty. Set NDK_BUNDLE to your Android NDK path"
  cat <<EOF
ndk="${NDK_BUNDLE}"
target_os="android"
target_cpu="${target_cpu}"
skia_use_icu=false
skia_use_zlib=false
skia_use_piex=false
skia_use_lua=false
is_debug=false
is_component_build=true
extra_cflags=["-O3"]
skia_use_angle=false
skia_use_libwebp=false
skia_use_opencl=false
skia_enable_tools=false
skia_enable_pdf=false
EOF
}

build_skia_android() {
  local target_cpu="$1"
  local abi="$2"
  local build_dir="$OUT_DIR/android-${abi}"
  local gn_bin

  require_cmd ninja
  require_skia_checkout
  require_depot_tools_checkout
  prepare_dirs
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  sync_skia_deps
  gn_bin=$(resolve_gn)

  "$gn_bin" gen "$build_dir" --args="$(android_gn_args "$target_cpu")"
  ninja -C "$build_dir"

  cp "$build_dir/libskia.so" "$DIST_DIR/libskia-android-${abi}.so"
  copy_build_manifest_if_present "$build_dir"

  echo "Created artifact:"
  echo "  $DIST_DIR/libskia-android-${abi}.so"
}

release_tag_from_manifest() {
  python3 - "$ROOT_DIR/manifest.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(manifest.get("release", {}).get("tag", ""))
PY
}
