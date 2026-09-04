<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# sdl3

This directory builds and packages SDL 3.4.16 for depot-tools consumers. The
repository-facing dependency name is `sdl3`; upstream API and CMake names remain
`SDL3`, including `<SDL3/SDL.h>` and `SDL3::SDL3`.

The source is pinned to upstream tag `release-3.4.16`, resolved revision
`fa2c02bb6e21974a89ea9824bc53c9932abe5f9c`. The immutable source archive is
verified with SHA-256
`d246967187a4f37cc850608dbaf5cff9d1df4d731259903d25539755cdfcc657`.
SDL uses the Zlib license in upstream `LICENSE.txt`; the wrapper preserves that
file in the build install tree under `share/licenses/sdl3/`.

## Artifact contract

Published artifacts are static Release builds with position-independent code:

- `SDL_SHARED=OFF`
- `SDL_STATIC=ON`
- `SDL_INSTALL=ON`, `SDL_RELOCATABLE=ON`, and installation extras disabled
- SDL test library, tests, installed tests, and examples disabled
- `SDL_LIBC=ON` and `CMAKE_POSITION_INDEPENDENT_CODE=ON`

The Windows wrapper inherits and propagates the central `/MT` runtime policy.
`SDL_LIBC=ON` prevents SDL's allocator fallback from defining `dlmalloc`-family
symbols that could collide with the allocator in a static TotalCross consumer.

The shared window/context profile retains video, OpenGL, OpenGL ES, Vulkan,
dummy video, and offscreen support. macOS additionally retains Cocoa and Metal.
Linux retains X11, Wayland, KMSDRM, DBus, IBus, and libudev with dynamic
integration dependencies. Audio, GPU, render, camera, joystick, haptic, HIDAPI,
power, sensor, dialog, and tray subsystems are disabled; Linux also disables
liburing, FriBidi, libthai, Raspberry Pi, Rockchip, and Vivante integrations.

The declared desktop targets and assets are:

- `linux-x86_64` → `sdl3-linux-x86_64.tar.gz`
- `linux-armv7l` → `sdl3-linux-armv7l.tar.gz`
- `linux-aarch64` → `sdl3-linux-aarch64.tar.gz`
- `windows-x86` → `sdl3-windows-x86.tar.gz`
- `windows-x64` → `sdl3-windows-x64.tar.gz`
- `windows-arm64` → `sdl3-windows-arm64.tar.gz`
- `macos-arm64` → `sdl3-macos-arm64.tar.gz`

Android, iOS, WebAssembly, SDL2 compatibility, and mobile/web targets are not
part of this contract. SDL2 remains an independent `sdl2` dependency.

Each archive contains:

```text
sdl3/<platform>/<arch>/
  include/SDL3/
  lib/
    cmake/SDL3/
    <static SDL3 library>
  manifest.txt
```

Unix-like artifacts normally contain `lib/libSDL3.a`; MSVC artifacts may contain
`lib/SDL3-static.lib`. Consumers must use `SDL3::SDL3` instead of depending on a
platform filename. The packaged upstream config supplies the platform system
libraries or Apple frameworks needed by the static target.

The archive writer uses only standard shell archive tools and normalizes entry
ordering, timestamps, and gzip metadata; GNU tar builds also normalize ownership.
`manifest.txt` records the source revision, target, Release/static/PIC policy,
libc/feature state, selected compiler, observed video backends, and the resolved MSVC
runtime when applicable.

## Local builds

Run an explicit wrapper from the repository root:

```bash
sdl3/scripts/build-macos-arm64.sh
sdl3/scripts/build-linux-x86_64.sh
sdl3/scripts/build-windows-x64.sh
```

Equivalent wrappers exist for every declared target above. They contain only the
dependency and target identity; runner, Docker image, generator, architecture,
and runtime policy come from `config/native-builds.yml` and shared executors.

For focused development with an existing SDL 3.4.16 checkout:

```bash
cmake -S sdl3 -B /tmp/sdl3-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DTC_SDL3_SOURCE_DIR=/path/to/SDL-3.4.16
cmake --build /tmp/sdl3-build
cmake --install /tmp/sdl3-build --prefix /tmp/sdl3-install
bash sdl3/scripts/package-artifact.sh \
  /tmp/sdl3-build /tmp/sdl3-install macos/arm64
```

Required SDL video backends are explicitly enabled. Linux builds fail rather
than silently dropping X11, Wayland, or KMSDRM when their development headers
are missing. The initial local validation host was Linux x86_64; other Linux
architectures, Windows runtime/allocator checks, and macOS framework-link checks
are performed by their declared workflow lanes before publication.

## Fetching artifacts

Artifacts install under `sdl3/local/<platform>/<arch>`. Before the first release
is published and pinned, pass an explicit handoff tag:

```bash
sdl3/fetch.sh \
  --platform macos \
  --arch arm64 \
  --release-tag <effective-sdl3-release> \
  --github-repo TotalCross/totalcross-depot-tools
```

After publication, omitting `--release-tag` uses the compatible `sdl3` release
from `deps.yml`. The fetcher never queries the latest GitHub Release. It verifies
the repository checksum metadata and static artifact contract, replaces an
incomplete destination atomically, and reuses an already complete artifact only
when its repository, release, asset, and checksum marker match.

Supported fetch options are `--platform`, `--arch`, `--release-tag`,
`--github-repo`, `--github-token-env`, and `--dest`. Authentication uses the
named token environment variable, then `SDL3_GITHUB_TOKEN`, then `GITHUB_TOKEN`;
token values and authenticated URLs are not printed.

## CMake consumption

Use depot auto-fetch and the strict find module:

```cmake
list(PREPEND CMAKE_MODULE_PATH
  "${DEPOT_TOOLS_ROOT}/sdl3/cmake")
include(AutoFetchSDL3)
tcvm_auto_fetch_sdl3()

find_package(SDL3 REQUIRED)
target_link_libraries(my_application PRIVATE SDL3::SDL3)
```

Before a default release pin exists, either stage a complete artifact and set
`SDL3_DEPOT_ROOT`, or set `SDL3_RELEASE_TAG` to an explicit release handoff.
`SDL3_GITHUB_REPO` and `SDL3_GITHUB_TOKEN_ENV` may also be supplied as CMake
variables or environment variables.

`FindSDL3.cmake` loads only
`<staged-root>/lib/cmake/SDL3/SDL3Config.cmake`. It requires both
`SDL3::SDL3-static` and the static-only upstream alias `SDL3::SDL3`, and verifies
that imported library and include paths remain inside the selected depot root.
An incomplete root fails configuration even when another SDL3 package is present
in `CMAKE_PREFIX_PATH`; there is no system, Homebrew, vcpkg, or SDK fallback.

Consumers that deliberately use upstream CONFIG mode can use the exact staged
directory without the module:

```cmake
set(SDL3_DIR "${SDL3_DEPOT_ROOT}/lib/cmake/SDL3")
find_package(SDL3 CONFIG REQUIRED)
target_link_libraries(my_application PRIVATE SDL3::SDL3)
```

Explicit static consumers may link `SDL3::SDL3-static`; the generic
`SDL3::SDL3` target is verified to be backed by that same static package.

## Release behavior

`.github/workflows/sdl3.yml` delegates `build`, `release`, and `force-release` to
the shared native-library operation. `build` is the default and does not update
Git, tags, releases, or `deps.yml`.

The initial publication remains gated. Only an explicitly authorized release
operation may publish assets and add the final compatible `sdl3` entry to
`deps.yml`. Normal release selection is idempotent; force-release is reserved for
an explicit republish request.

## Focused validation

```bash
python3 tools/new-native-dependency.py check sdl3
bash -n sdl3/fetch.sh sdl3/scripts/*.sh
python3 scripts/native-build.py validate
python3 scripts/native-release.py validate-contract sdl3
python3 scripts/validate-native-policy-literals.py
git diff --check -- \
  sdl3 config/native-builds.yml .github/workflows/sdl3.yml deps.yml
```

The consumer fixture is `sdl3/cmake/tests/consumer`. Configure it with
`DEPOT_TOOLS_ROOT`, a freshly staged `SDL3_DEPOT_ROOT`, and optionally
`SDL3_TEST_AUTO_FETCH=ON`, `SDL3_TEST_CONFIG_ONLY=ON`, or
`SDL3_TEST_EXPLICIT_STATIC=ON`; it includes `<SDL3/SDL.h>`, calls
`SDL_GetVersion`, and links one of the two supported targets.
