#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_ROOT=$(cd "$ROOT_DIR/.." && pwd)
SKIA_DIR="${SKIA_DIR:-$ROOT_DIR/skia}"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-$ROOT_DIR/depot_tools}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out}"
STAGING_DIR="${STAGING_DIR:-$ROOT_DIR/staging}"
RPI_ROOT="${RPI_ROOT:-$ROOT_DIR/linux/rpi}"
NDK_BUNDLE="${NDK_BUNDLE:-}"
SKIA_USE_DEPOT_PREBUILTS="${SKIA_USE_DEPOT_PREBUILTS:-auto}"
SKIA_USE_CCACHE="${SKIA_USE_CCACHE:-auto}"

SKIA_DEP_USE_ZLIB=false
SKIA_DEP_USE_LIBPNG=false
SKIA_DEP_CFLAGS=()
SKIA_DEP_LDFLAGS=()

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

prepare_python_compat() {
  require_cmd python3

  if command -v python >/dev/null 2>&1; then
    return 0
  fi

  local compat_bin="$OUT_DIR/toolchain-compat/bin"
  mkdir -p "$compat_bin"
  ln -sf "$(command -v python3)" "$compat_bin/python"
  export PATH="$compat_bin:$PATH"
}

resolve_gn() {
  require_depot_tools_checkout

  local candidate
  local candidates=()

  if command -v gn >/dev/null 2>&1; then
    candidates+=("$(command -v gn)")
  fi

  candidates+=("$DEPOT_TOOLS_DIR/gn" "$SKIA_DIR/bin/gn")

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]] && "$candidate" --version >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  die "could not find an executable 'gn' for this host architecture."
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
  prepare_dirs

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$SKIA_DIR/include/" "$STAGING_DIR/modules/skia/include/"
    rsync -a --delete "$SKIA_DIR/src/gpu/gl/" "$STAGING_DIR/modules/skia/src/gpu/gl/"
  else
    rm -rf "$STAGING_DIR/modules/skia/include" "$STAGING_DIR/modules/skia/src/gpu/gl"
    mkdir -p "$STAGING_DIR/modules/skia/include" "$STAGING_DIR/modules/skia/src/gpu/gl"
    cp -R "$SKIA_DIR/include/." "$STAGING_DIR/modules/skia/include/"
    cp -R "$SKIA_DIR/src/gpu/gl/." "$STAGING_DIR/modules/skia/src/gpu/gl/"
  fi
}

gn_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

gn_array() {
  local first=1
  local value

  for value in "$@"; do
    if [[ $first -eq 0 ]]; then
      printf ','
    fi
    printf '"%s"' "$(gn_escape "$value")"
    first=0
  done
}

ccache_gn_arg() {
  if [[ "$SKIA_USE_CCACHE" == "0" || "$SKIA_USE_CCACHE" == "false" || "$SKIA_USE_CCACHE" == "off" ]]; then
    return 0
  fi

  if command -v ccache >/dev/null 2>&1; then
    printf 'cc_wrapper="%s"\n' "$(gn_escape "$(command -v ccache)")"
  fi
}

find_static_library() {
  local lib_dir="$1"
  shift

  local pattern
  local candidate
  for pattern in "$@"; do
    for candidate in "$lib_dir"/$pattern; do
      if [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  done

  return 1
}

add_prebuilt_dep_flags() {
  local dep_root="$1"
  local linker_style="$2"

  SKIA_DEP_CFLAGS+=("-I${dep_root}/include")
  if [[ "$linker_style" == "msvc" ]]; then
    SKIA_DEP_LDFLAGS+=("/LIBPATH:${dep_root}/lib")
  else
    SKIA_DEP_LDFLAGS+=("-L${dep_root}/lib")
  fi
}

prepare_android_ndk_compat() {
  [[ -n "$NDK_BUNDLE" ]] || die "NDK_BUNDLE is empty. Set NDK_BUNDLE to your Android NDK path"

  local host_tag=""
  case "$(uname -s)" in
    Linux) host_tag="linux-x86_64" ;;
    Darwin) host_tag="darwin-x86_64" ;;
    MINGW*|MSYS*|CYGWIN*) host_tag="windows-x86_64" ;;
  esac

  [[ -n "$host_tag" ]] || die "unsupported Android NDK host platform: $(uname -s)"

  local llvm_prebuilt="$NDK_BUNDLE/toolchains/llvm/prebuilt/$host_tag"
  local modern_sysroot="$llvm_prebuilt/sysroot"
  local modern_cxx_include="$modern_sysroot/usr/include/c++/v1"

  [[ -d "$modern_sysroot" ]] || die "missing Android NDK sysroot at $modern_sysroot"
  [[ -d "$modern_cxx_include" ]] || die "missing Android NDK C++ headers at $modern_cxx_include"

  if [[ ! -e "$NDK_BUNDLE/sysroot" ]]; then
    ln -s "$modern_sysroot" "$NDK_BUNDLE/sysroot" 2>/dev/null || {
      mkdir -p "$NDK_BUNDLE/sysroot"
      cp -R "$modern_sysroot/." "$NDK_BUNDLE/sysroot/"
    }
  fi

  mkdir -p "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++" "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++abi"

  if [[ ! -e "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++/include" ]]; then
    ln -s "$modern_cxx_include" "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++/include" 2>/dev/null || {
      mkdir -p "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++/include"
      cp -R "$modern_cxx_include/." "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++/include/"
    }
  fi

  if [[ ! -e "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++abi/include" ]]; then
    ln -s "$modern_cxx_include" "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++abi/include" 2>/dev/null || {
      mkdir -p "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++abi/include"
      cp -R "$modern_cxx_include/." "$NDK_BUNDLE/sources/cxx-stl/llvm-libc++abi/include/"
    }
  fi
}

resolve_xcode_sysroot() {
  local sdk="$1"

  require_cmd xcrun
  xcrun --sdk "$sdk" --show-sdk-path | tr -d '\r\n'
}

configure_prebuilt_deps() {
  local platform="$1"
  local arch="$2"
  local linker_style="${3:-unix}"
  local zlib_root="$REPO_ROOT/zlib-ng/local/$platform/$arch"
  local libpng_root="$REPO_ROOT/libpng/local/$platform/$arch"

  SKIA_DEP_USE_ZLIB=false
  SKIA_DEP_USE_LIBPNG=false
  SKIA_DEP_CFLAGS=()
  SKIA_DEP_LDFLAGS=()

  if [[ "$SKIA_USE_DEPOT_PREBUILTS" == "0" || "$SKIA_USE_DEPOT_PREBUILTS" == "false" || "$SKIA_USE_DEPOT_PREBUILTS" == "off" ]]; then
    return 0
  fi

  if [[ -f "$zlib_root/include/zlib.h" ]] && find_static_library "$zlib_root/lib" "libz.a" "zlib.lib" "zlibstatic.lib" >/dev/null; then
    SKIA_DEP_USE_ZLIB=true
    add_prebuilt_dep_flags "$zlib_root" "$linker_style"
    echo "Using repository zlib-ng prebuilt at $zlib_root" >&2
  fi

  if [[ -f "$libpng_root/include/png.h" ]] && find_static_library "$libpng_root/lib" "libpng*.a" "png*.lib" "libpng*.lib" >/dev/null; then
    SKIA_DEP_USE_LIBPNG=true
    add_prebuilt_dep_flags "$libpng_root" "$linker_style"
    echo "Using repository libpng prebuilt at $libpng_root" >&2
  fi
}

copy_build_manifest_if_present() {
  local build_dir="$1"
  local manifest_key="$2"
  local platform="$3"
  local arch="$4"

  if [[ -f "$build_dir/build_config_manifest.md" ]]; then
    cp "$build_dir/build_config_manifest.md" "$DIST_DIR/build_config_manifest-${manifest_key}.md"
    mkdir -p "$STAGING_DIR/modules/skia/out/Release/$platform/$arch"
    cp "$build_dir/build_config_manifest.md" "$STAGING_DIR/modules/skia/out/Release/$platform/$arch/build_config_manifest.md"
  fi
}

copy_static_artifact() {
  local build_dir="$1"
  local source_name="$2"
  local artifact_name="$3"
  local manifest_key="$4"
  local platform="$5"
  local arch="$6"
  local installed_name="$7"

  [[ -f "$build_dir/$source_name" ]] || die "missing built Skia library at $build_dir/$source_name"
  cp "$build_dir/$source_name" "$DIST_DIR/$artifact_name"
  mkdir -p "$STAGING_DIR/modules/skia/out/Release/$platform/$arch"
  cp "$build_dir/$source_name" "$STAGING_DIR/modules/skia/out/Release/$platform/$arch/$installed_name"
  copy_build_manifest_if_present "$build_dir" "$manifest_key" "$platform" "$arch"

  echo "Created artifact:"
  echo "  $DIST_DIR/$artifact_name"
}

gn_gen_and_build() {
  local build_dir="$1"
  local args="$2"
  local target="${3:-skia}"
  local gn_bin

  require_cmd ninja
  require_skia_checkout
  require_depot_tools_checkout
  prepare_dirs
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  prepare_python_compat
  sync_skia_deps
  gn_bin=$(resolve_gn)

  pushd "$SKIA_DIR" >/dev/null
  "$gn_bin" gen "$build_dir" --args="$args"
  ninja -C "$build_dir" "$target"
  popd >/dev/null
}

macos_gn_args() {
  local target_cpu="$1"
  local sysroot
  sysroot=$(resolve_xcode_sysroot "macosx")
  configure_prebuilt_deps "macos" "$target_cpu" "unix"
  cat <<EOF
$(ccache_gn_arg)target_os="mac"
is_debug=false
is_official_build=true
is_component_build=false
target_cpu="${target_cpu}"
xcode_sysroot="$(gn_escape "$sysroot")"
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
skia_use_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_system_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_system_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_fontconfig=true
skia_use_harfbuzz=true
skia_use_system_harfbuzz=false
skia_use_expat=false
skia_use_system_icu=false
extra_cflags=[$(gn_array "-O3" "-Wno-error" "-mmacosx-version-min=11.0" "${SKIA_DEP_CFLAGS[@]}")]
extra_cxxflags=[$(gn_array "-O3" "-Wno-error" "-mmacosx-version-min=11.0" "${SKIA_DEP_CFLAGS[@]}")]
extra_ldflags=[$(gn_array "-mmacosx-version-min=11.0" "${SKIA_DEP_LDFLAGS[@]}")]
EOF
}

build_skia_macos() {
  local target_cpu="$1"
  local artifact_name="$2"
  local build_dir="$OUT_DIR/macos-${target_cpu}"

  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(macos_gn_args "$target_cpu")" skia
  copy_static_artifact "$build_dir" "libskia.a" "$artifact_name" "macos-${target_cpu}" "macos" "$target_cpu" "libskia.a"
}

linux_common_gn_args() {
  local target_cpu="$1"
  local platform_arch="$2"
  local gl_standard="$3"
  configure_prebuilt_deps "linux" "$platform_arch" "unix"
  cat <<EOF
$(ccache_gn_arg)target_os="linux"
target_cpu="${target_cpu}"
is_debug=false
is_official_build=true
is_component_build=false
skia_enable_gpu=true
skia_use_egl=true
skia_use_gl=true
skia_gl_standard="${gl_standard}"
skia_use_opencl=true
skia_use_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_system_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_system_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_libwebp=false
skia_use_libjpeg_turbo=false
skia_use_harfbuzz=false
skia_use_expat=false
skia_use_icu=false
skia_enable_pdf=false
skia_enable_tools=false
extra_cflags=[$(gn_array "-O3" "-Wno-error" "-DNDEBUG" "-DMESA_EGL_NO_X11_HEADERS" "${SKIA_DEP_CFLAGS[@]}")]
extra_ldflags=[$(gn_array "${SKIA_DEP_LDFLAGS[@]}")]
EOF
}

build_skia_linux_x86_64() {
  local build_dir="$OUT_DIR/linux-x86_64"

  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(linux_common_gn_args "x64" "x86_64" "gl")" skia
  copy_static_artifact "$build_dir" "libskia.a" "libskia-linux-x86_64.a" "linux-x86_64" "linux" "x86_64" "libskia.a"
}

build_skia_linux_aarch64() {
  local build_dir="$OUT_DIR/linux-aarch64"

  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(linux_common_gn_args "arm64" "aarch64" "gles")" skia
  copy_static_artifact "$build_dir" "libskia.a" "libskia-linux-aarch64.a" "linux-aarch64" "linux" "aarch64" "libskia.a"
}

linux_armv7_gn_args() {
  configure_prebuilt_deps "linux" "armv7l" "unix"
  cat <<EOF
$(ccache_gn_arg)target_os="linux"
target_cpu="arm"
cc="clang-9"
cxx="clang++-9"
skia_use_egl=true
skia_enable_gpu=true
skia_use_libjpeg_turbo=false
is_official_build=true
is_component_build=false
skia_use_freetype=true
skia_use_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_system_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_angle=false
skia_use_expat=false
skia_use_icu=false
skia_use_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_system_libpng=${SKIA_DEP_USE_LIBPNG}
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
extra_cflags=[$(gn_array "-O3" "-target" "armv7a-linux" "-mfloat-abi=hard" "-mfpu=neon" "--sysroot=${RPI_ROOT}" "-I${RPI_ROOT}/usr/include/c++/4.9" "-I${RPI_ROOT}/usr/include/arm-linux-gnueabihf" "-I${RPI_ROOT}/usr/include/arm-linux-gnueabihf/c++/4.9" "-I${RPI_ROOT}/usr/include/freetype2" "-DSKIA_C_DLL" "${SKIA_DEP_CFLAGS[@]}")]
extra_asmflags=[$(gn_array "-g" "-target" "armv7a-linux" "-mfloat-abi=hard" "-mfpu=neon")]
extra_ldflags=[$(gn_array "${SKIA_DEP_LDFLAGS[@]}")]
EOF
}

build_skia_linux_armv7l() {
  local build_dir="$OUT_DIR/linux-armv7l"

  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(linux_common_gn_args "arm" "armv7l" "gles")" skia
  copy_static_artifact "$build_dir" "libskia.a" "libskia-linux-armv7l.a" "linux-armv7l" "linux" "armv7l" "libskia.a"
}

android_gn_args() {
  local target_cpu="$1"
  [[ -n "$NDK_BUNDLE" ]] || die "NDK_BUNDLE is empty. Set NDK_BUNDLE to your Android NDK path"
  configure_prebuilt_deps "android" "arm64-v8a" "unix"
  cat <<EOF
$(ccache_gn_arg)ndk="${NDK_BUNDLE}"
ndk_api=23
target_os="android"
target_cpu="${target_cpu}"
skia_use_icu=false
skia_use_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_system_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_system_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_piex=false
skia_use_lua=false
is_debug=false
is_official_build=true
is_component_build=false
extra_cflags=[$(gn_array "-O3" "${SKIA_DEP_CFLAGS[@]}")]
extra_ldflags=[$(gn_array "${SKIA_DEP_LDFLAGS[@]}")]
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

  prepare_android_ndk_compat
  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(android_gn_args "$target_cpu")" skia
  copy_static_artifact "$build_dir" "libskia.a" "libskia-android-${abi}.a" "android-${abi}" "android" "$abi" "libskia.a"
}

ios_gn_args() {
  local sdk="$1"
  local simulator="$2"
  local platform="$3"
  local sysroot
  sysroot=$(resolve_xcode_sysroot "$sdk")
  configure_prebuilt_deps "$platform" "arm64" "unix"
  cat <<EOF
$(ccache_gn_arg)target_os="ios"
target_cpu="arm64"
ios_use_simulator=${simulator}
xcode_sysroot="$(gn_escape "$sysroot")"
is_debug=false
is_official_build=true
is_component_build=false
skia_enable_gpu=true
skia_enable_pdf=false
skia_enable_tools=false
skia_use_opencl=false
skia_use_libwebp=false
skia_use_libwebp_encode=false
skia_use_libwebp_decode=false
skia_use_libjpeg_turbo=false
skia_use_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_system_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_system_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_fontconfig=false
skia_use_harfbuzz=false
skia_use_expat=false
skia_use_system_icu=false
extra_cflags=[$(gn_array "-O3" "-Wno-error" "${SKIA_DEP_CFLAGS[@]}")]
extra_cxxflags=[$(gn_array "-O3" "-Wno-error" "${SKIA_DEP_CFLAGS[@]}")]
extra_ldflags=[$(gn_array "${SKIA_DEP_LDFLAGS[@]}")]
EOF
}

build_skia_ios() {
  local build_dir="$OUT_DIR/ios-arm64"

  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(ios_gn_args "iphoneos" "false" "ios")" skia
  copy_static_artifact "$build_dir" "libskia.a" "libskia-ios-arm64.a" "ios-arm64" "ios" "arm64" "libskia.a"
}

build_skia_ios_simulator() {
  local build_dir="$OUT_DIR/ios-simulator-arm64"

  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(ios_gn_args "iphonesimulator" "true" "ios-simulator")" skia
  copy_static_artifact "$build_dir" "libskia.a" "libskia-ios-simulator-arm64.a" "ios-simulator-arm64" "ios-simulator" "arm64" "libskia.a"
}

windows_gn_args() {
  local target_cpu="$1"
  local arch="$2"
  configure_prebuilt_deps "windows" "$arch" "msvc"
  cat <<EOF
$(ccache_gn_arg)target_os="win"
target_cpu="${target_cpu}"
is_debug=false
is_official_build=true
is_component_build=false
skia_enable_gpu=true
skia_enable_pdf=false
skia_enable_tools=false
skia_use_opencl=false
skia_use_libwebp=false
skia_use_libjpeg_turbo=false
skia_use_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_system_libpng=${SKIA_DEP_USE_LIBPNG}
skia_use_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_system_zlib=${SKIA_DEP_USE_ZLIB}
skia_use_fontconfig=false
skia_use_harfbuzz=false
skia_use_expat=false
skia_use_system_icu=false
extra_cflags=[$(gn_array "/O2" "/W0" "${SKIA_DEP_CFLAGS[@]}")]
extra_cxxflags=[$(gn_array "/O2" "/W0" "${SKIA_DEP_CFLAGS[@]}")]
extra_ldflags=[$(gn_array "${SKIA_DEP_LDFLAGS[@]}")]
EOF
}

build_skia_windows() {
  local target_cpu="$1"
  local arch="$2"
  local build_dir="$OUT_DIR/windows-${arch}"

  export DEPOT_TOOLS_WIN_TOOLCHAIN="${DEPOT_TOOLS_WIN_TOOLCHAIN:-0}"
  stage_dev_subset
  gn_gen_and_build "$build_dir" "$(windows_gn_args "$target_cpu" "$arch")" skia
  copy_static_artifact "$build_dir" "skia.lib" "libskia-windows-${arch}.lib" "windows-${arch}" "windows" "$arch" "libskia.lib"
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
