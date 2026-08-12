<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# skia

This dependency packages the Skia prebuilts produced by
`TotalCross/totalcross-depot-tools`.

The source/build side is pinned in `manifest.json`, while `artifacts.json`
describes the GitHub Release assets consumed by TotalCross.

## Fetch release artifacts

```bash
./fetch.sh --install-shared
./fetch.sh --platform linux --arch x86_64
./fetch.sh --platform wasm --arch wasm32
./fetch.sh --platform macos --arch arm64
./fetch.sh --platform android --arch arm64-v8a
./fetch.sh --platform ios --arch arm64
./fetch.sh --platform ios-simulator --arch arm64
```

The default source is the `TotalCross/totalcross-depot-tools` release declared
in `artifacts.json`. Override it with `--base-url`, `--github-repo`,
`--release-tag`, or `--source`.

Every metadata-enabled static archive is paired with a target-specific release
asset named `SkiaBuildConfig-<platform>-<arch>.cmake`. `fetch.sh` validates the
metadata version, platform, architecture, and library SHA-256 before installing
the pair. Run `--install-shared` once per release preparation to install the
development bundle and every human-readable build manifest. The legacy
`--install-dev` option remains compatible and performs the selected target fetch
followed by the same idempotent shared installation.

An explicit `--source` archive must be accompanied by its matching
`--build-config`. Alternate base URLs, repositories, and release tags are also
treated as metadata-enabled sources.

## Consume from CMake

```cmake
list(PREPEND CMAKE_MODULE_PATH
  "${TOTALCROSS_DEPOT_TOOLS_DIR}/skia/cmake")

include("${TOTALCROSS_DEPOT_TOOLS_DIR}/skia/cmake/AutoFetchSkia.cmake")
tcvm_auto_fetch_skia()
find_package(Skia REQUIRED)

target_link_libraries(my_target PRIVATE Skia::Skia)
```

`Skia::Skia` is the complete package interface. For metadata-enabled repository
artifacts it validates `SkiaBuildConfig.cmake` against the selected archive,
then propagates the repository PNG/zlib targets, platform frameworks or
toolchain libraries, platform identity, and backend compile definitions required
by that exact build. Consumers must not repeat Metal, OpenGL, Vulkan, PNG, zlib,
or other backend requirements manually.

Repository-managed development bundles are self-contained for public build-time
headers. When the selected metadata enables Vulkan, `Skia::Skia` propagates both
`SK_VULKAN` and the bundle's `include/third_party/vulkan` directory, which makes
Skia's `<vulkan/vulkan_core.h>` include resolve without a separately installed
Vulkan SDK. Android metadata also validates the bundled `vulkan_android.h`.
Missing required headers make a managed package fail during CMake configuration
instead of falling back to whatever system headers happen to be installed.

This header contract does not add a Vulkan loader library and does not claim to
provide an application-level Vulkan runtime. An application that directly uses
a platform Vulkan loader remains responsible for its own runtime integration;
merely compiling against this Skia prebuilt does not require one.

An explicit `SKIA_LIBRARY` outside `skia/local` may omit metadata for legacy
compatibility. CMake warns in that case and cannot infer backend dependencies;
providing a matching `SKIA_BUILD_CONFIG` enables the metadata-driven contract.
Repository-managed artifacts fail when metadata is required but missing,
unsupported, for another platform/architecture, or bound to a different
library hash.

## Build artifacts

```bash
./scripts/build-macos-arm64.sh
./scripts/build-linux-x86_64.sh
./scripts/build-linux-aarch64.sh
./scripts/build-linux-armv7l.sh
./scripts/build-wasm32.sh
./scripts/build-android-arm64.sh
./scripts/build-ios-arm64.sh
./scripts/build-ios-simulator-arm64.sh
./scripts/package-ios-xcframework.sh
./scripts/build-windows-x86.sh
./scripts/build-windows-x64.sh
./scripts/build-windows-arm64.sh
./scripts/package-dev-bundle.sh
```

They expect Skia and depot_tools checkouts under this directory:

```text
skia/skia/
skia/depot_tools/
```

Linux builds run in the repository's Ubuntu Bionic images, whose Python 3.6
interpreter is the compatibility floor for scripts executed there. The root
`AGENTS.md` `Scripts` section defines the build-image compatibility policy.

Create or update those checkouts with:

```bash
./scripts/fetch-source.sh
```

Each target build emits the static archive, its machine build config, and the
existing human diagnostics. `skia/scripts/generate-build-config.py` reads the
post-`gn gen` effective argument listing; repository zlib/libpng selections are
recorded at the shared packaging boundary that validates and applies those
prebuilts.
