<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# sdl2

This directory builds and packages SDL 2.32.8 for depot-tools consumers. The
repository-facing dependency name is `sdl2`; upstream API and CMake names remain
`SDL2`, including `<SDL2/SDL.h>` and `SDL2::SDL2`.

The source is pinned to upstream tag `release-2.32.8`, resolved revision
`98d1f3a45aae568ccd6ed5fec179330f47d4d356`. The immutable source archive is
verified with SHA-256
`be55f7015a5599faa869b20078de83df7e83c35585ee1c3ee203a0e58eefebbd`.
SDL uses the Zlib license in upstream `LICENSE.txt`; the wrapper preserves that
file in the build install tree under `share/licenses/sdl2/`.

## Artifact contract

Published artifacts are static Release builds with position-independent code:

- `SDL_SHARED=OFF`
- `SDL_STATIC=ON`
- `SDL_STATIC_PIC=ON`
- SDL tests and installed tests disabled
- `SDL2_DISABLE_SDL2MAIN=ON`

TotalCross owns the application entrypoint, so SDL2main is intentionally absent.
The Windows wrapper inherits the central `/MT` runtime policy and also enables
`SDL_FORCE_STATIC_VCRT` for the nested upstream build.

The declared desktop targets and assets are:

- `linux-x86_64` → `sdl2-linux-x86_64.tar.gz`
- `linux-armv7l` → `sdl2-linux-armv7l.tar.gz`
- `linux-aarch64` → `sdl2-linux-aarch64.tar.gz`
- `windows-x86` → `sdl2-windows-x86.tar.gz`
- `windows-x64` → `sdl2-windows-x64.tar.gz`
- `windows-arm64` → `sdl2-windows-arm64.tar.gz`
- `macos-arm64` → `sdl2-macos-arm64.tar.gz`

Android, iOS, WebAssembly, SDL3, and `sdl2-compat` are not part of this contract.

Each archive contains:

```text
sdl2/<platform>/<arch>/
  include/SDL2/
  lib/
    cmake/SDL2/
    <static SDL2 library>
  manifest.txt
```

Unix-like artifacts normally contain `lib/libSDL2.a`; MSVC artifacts may contain
`lib/SDL2-static.lib`. Consumers must use `SDL2::SDL2` instead of depending on a
platform filename. The packaged upstream config supplies the platform system
libraries or Apple frameworks needed by the static target.

The archive writer uses only standard shell archive tools and normalizes entry
ordering, timestamps, and gzip metadata; GNU tar builds also normalize ownership.
`manifest.txt` records the source revision, target, Release/static/PIC policy,
SDL2main state, selected compiler, observed video backends, and the resolved MSVC
runtime when applicable.

## Local builds

Run an explicit wrapper from the repository root:

```bash
sdl2/scripts/build-macos-arm64.sh
sdl2/scripts/build-linux-x86_64.sh
sdl2/scripts/build-windows-x64.sh
```

Equivalent wrappers exist for every declared target above. They contain only the
dependency and target identity; runner, Docker image, generator, architecture,
and runtime policy come from `config/native-builds.yml` and shared executors.

For focused development with an existing SDL 2.32.8 checkout:

```bash
cmake -S sdl2 -B /tmp/sdl2-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DTC_SDL2_SOURCE_DIR=/path/to/SDL-2.32.8
cmake --build /tmp/sdl2-build
cmake --install /tmp/sdl2-build --prefix /tmp/sdl2-install
bash sdl2/scripts/package-artifact.sh \
  /tmp/sdl2-build /tmp/sdl2-install macos/arm64
```

SDL video backends are not disabled by depot-tools. Linux capabilities therefore
reflect the centrally versioned build images and their installed development
headers. The initial local validation host was macOS ARM64; Linux image and
Windows runtime verification are performed by their declared workflow lanes.

## Fetching artifacts

Artifacts install under `sdl2/local/<platform>/<arch>`. Before the first release
is published and pinned, pass an explicit handoff tag:

```bash
sdl2/fetch.sh \
  --platform macos \
  --arch arm64 \
  --release-tag <effective-sdl2-release> \
  --github-repo TotalCross/totalcross-depot-tools
```

After publication, omitting `--release-tag` uses the compatible `sdl2` release
from `deps.yml`. The fetcher never queries the latest GitHub Release. It verifies
the repository checksum metadata and static artifact contract, replaces an
incomplete destination atomically, and reuses an already complete artifact only
when its repository, release, asset, and checksum marker match.

Supported fetch options are `--platform`, `--arch`, `--release-tag`,
`--github-repo`, `--github-token-env`, and `--dest`. Authentication uses the
named token environment variable, then `SDL2_GITHUB_TOKEN`, then `GITHUB_TOKEN`;
token values and authenticated URLs are not printed.

## CMake consumption

Use depot auto-fetch and the strict find module:

```cmake
list(PREPEND CMAKE_MODULE_PATH
  "${DEPOT_TOOLS_ROOT}/sdl2/cmake")
include(AutoFetchSDL2)
tcvm_auto_fetch_sdl2()

find_package(SDL2 REQUIRED)
target_link_libraries(my_application PRIVATE SDL2::SDL2)
```

Before a default release pin exists, either stage a complete artifact and set
`SDL2_DEPOT_ROOT`, or set `SDL2_RELEASE_TAG` to an explicit release handoff.
`SDL2_GITHUB_REPO` and `SDL2_GITHUB_TOKEN_ENV` may also be supplied as CMake
variables or environment variables.

`FindSDL2.cmake` loads only
`<staged-root>/lib/cmake/SDL2/SDL2Config.cmake`. It requires both
`SDL2::SDL2-static` and the static-only upstream alias `SDL2::SDL2`, and verifies
that imported library and include paths remain inside the selected depot root.
An incomplete root fails configuration even when another SDL2 package is present
in `CMAKE_PREFIX_PATH`; there is no system, Homebrew, vcpkg, or SDK fallback.

## Release behavior

`.github/workflows/sdl2.yml` delegates `build`, `release`, and `force-release` to
the shared native-library operation. `build` is the default and does not update
Git, tags, releases, or `deps.yml`.

The initial publication remains gated. Only an explicitly authorized release
operation may publish assets and add the final compatible `sdl2` entry to
`deps.yml`. Normal release selection is idempotent; force-release is reserved for
an explicit republish request.

## Focused validation

```bash
python3 tools/new-native-dependency.py check sdl2
bash -n sdl2/fetch.sh sdl2/scripts/*.sh
python3 scripts/native-build.py validate
python3 scripts/native-release.py validate-contract sdl2
python3 scripts/validate-native-policy-literals.py
git diff --check -- \
  sdl2 config/native-builds.yml .github/workflows/sdl2.yml deps.yml
```

The consumer fixture is `sdl2/cmake/tests/consumer`. Configure it with
`DEPOT_TOOLS_ROOT`, a freshly staged `SDL2_DEPOT_ROOT`, and optionally
`SDL2_TEST_AUTO_FETCH=ON`; it includes `<SDL2/SDL.h>`, calls `SDL_GetVersion`,
and links only `SDL2::SDL2`.
