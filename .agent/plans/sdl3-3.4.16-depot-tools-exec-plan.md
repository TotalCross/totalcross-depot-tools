<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Add SDL3 3.4.16 to totalcross-depot-tools

This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`.

## Purpose / Big Picture

Add SDL 3.4.16 as a first-class native dependency in
`TotalCross/totalcross-depot-tools` under the repository-facing name `sdl3`.

The result must be independently buildable, packageable, fetchable, releasable,
and consumable by both TotalCross and Magic Doodle Board (MBD,
`flsobral/didactic-doodle`) without falling back to host/system SDL:

    sdl3/scripts/build-<target>.sh
    sdl3/fetch.sh
    sdl3/cmake/AutoFetchSDL3.cmake
    find_package(SDL3 REQUIRED)
    target_link_libraries(<consumer> PRIVATE SDL3::SDL3)

The package is static-only and must also expose `SDL3::SDL3-static`. Because no
shared SDL3 is staged, upstream `SDL3::SDL3` must resolve to the static target.
MBD already uses `find_package(SDL3 CONFIG REQUIRED)` plus `SDL3::SDL3`, so both
target names are part of the acceptance contract.

All repository-facing names use `sdl3`, never `sdl`. Public upstream identifiers
remain `SDL3`, `SDL3::SDL3`, `SDL3::SDL3-static`, `SDL3Config.cmake`, and
`<SDL3/SDL.h>`.

Pin the latest stable SDL3 release verified on 2026-09-03:

    version:         3.4.16
    source tag:      release-3.4.16
    source revision: fa2c02bb6e21974a89ea9824bc53c9932abe5f9c
    release date:    2026-09-02
    license:         Zlib, upstream LICENSE.txt

The official `SDL3-3.4.16.tar.gz` release asset SHA-256 is:

    7322236cd12090c3eb40b9728be4d49c76f66ad17d04369584d4ecad5cf77c68

If the wrapper uses the GitHub codeload archive by immutable commit, calculate
and commit that archive's SHA-256 before accepting the wrapper. Never use an
unverified mutable source URL.

Publish only:

- Linux `x86_64`, `armv7l`, `aarch64`;
- Windows `x86`, `x64`, `arm64`;
- macOS `arm64`.

Android, iOS, iOS Simulator, WebAssembly, SDL2, and `sdl2-compat` are out of
scope. This plan does not migrate TotalCross source code from SDL2 to SDL3 and
does not modify MBD; those are consumer-side follow-ups. It does validate their
required CMake consumption shapes.

## Working Set and Resume Protocol

Plan path:

    .agent/plans/sdl3-3.4.16-depot-tools-exec-plan.md

Plan key and tracked execution artifacts:

    add-sdl3-3.4.16
    .agent/state/add-sdl3-3.4.16.md
    .agent/evidence/add-sdl3-3.4.16.md
    .agent/archive/add-sdl3-3.4.16-history.md
    .agent/reports/add-sdl3-3.4.16-editorial.md

The plan itself and every durable first-party execution artifact above must be
committed. Create state/evidence in the first implementation slice; create the
archive only if completed detail must leave the active plan; create/finalize the
editorial report at milestone/final completion.

Raw compiler output, build/install trees, downloaded source, temporary consumer
checkouts, generated `.tar.gz` release assets, CI downloads, and large logs are
not plan artifacts. Keep them ignored/outside Git and record only concise
results, paths, hashes, and limitations in evidence.

On resume:

1. Read `.agent/state/add-sdl3-3.4.16.md`.
2. Inspect `git status --short -- <active paths>` and only the active milestone diff.
3. Continue from the next concrete action in state.
4. Search evidence/history only for a specific prior result.
5. Do not routinely reread the complete plan, `AGENTS.md`, `.agent/PLANS.md`, or logs.

Before implementation, read once: `AGENTS.md`, `.agent/PLANS.md`,
`docs/DEPENDENCY_STANDARD.md`, `.agents/skills/add-native-dependency/SKILL.md`,
`.agents/skills/logical-commits/SKILL.md`,
`.agents/skills/validate-headers/SKILL.md`, `config/native-builds.yml`, and the
current `sdl2/` implementation as the closest proven dependency.

## Progress

- [x] (2026-09-03) Selected SDL 3.4.16 and resolved `release-3.4.16` to
  `fa2c02bb6e21974a89ea9824bc53c9932abe5f9c`.
- [x] Reviewed the SDL2 2.32.8 ExecPlan as the structural template and the
  TotalCross SDL2 migration plus two older SDL3 3.4.12 plans as additional input.
- [x] Reviewed `fb75cb4ad2eace8c849e6349831af2114c601424` and later depot-tools
  changes that corrected SDL2 build, packaging, stack planning, first release,
  Windows runtime, and allocator behavior.
- [x] Reviewed MBD's SDL3 contract: CONFIG-mode discovery and `SDL3::SDL3`, with
  desktop OpenGL, Metal, or Vulkan backends.
- [x] (2026-09-04) Milestone 1: scaffolded `sdl3` and locked the
  source/metadata/feature contracts.
- [x] (2026-09-04) Milestone 2: implemented the reproducible static build and
  deterministic package, with a host Linux build and both exported targets proven.
- [ ] Milestone 3: implement strict fetch/CMake consumption and consumer fixtures.
- [ ] Milestone 4: add the current one-workflow operation and validate seven lanes.
- [ ] Milestone 5: documentation, cross-consumer proof, tracked artifacts, readiness.
- [ ] Publication gate: first release only with explicit authorization.

## Current Architecture and Scope

### Repository contract

Create the standard dependency layout:

    sdl3/
      README.md
      manifest.yml
      CMakeLists.txt
      fetch.sh
      cmake/AutoFetchSDL3.cmake
      cmake/FindSDL3.cmake
      scripts/package-artifact.sh
      scripts/build-<target>.sh

and `.github/workflows/sdl3.yml`.

Register `libraries.sdl3` in `config/native-builds.yml` with CMake build system,
`sdl3/scripts/package-artifact.sh`, the seven desktop targets, and stack `others`
adjacent to `sdl2`. Do not replace or rename `sdl2`.

Repository/public contract:

    directory/config key: sdl3
    archives/releases:   sdl3-...
    package:              SDL3
    public target:        SDL3::SDL3
    static target:        SDL3::SDL3-static
    auto-fetch:           sdl3/cmake/AutoFetchSDL3.cmake
    find module:          sdl3/cmake/FindSDL3.cmake

Never add top-level `sdl/`, an `sdl` dependency key, `AutoFetchSDL.cmake`,
`FindSDL.cmake`, or `sdl-*` assets.

Expected assets:

    sdl3-linux-x86_64.tar.gz
    sdl3-linux-armv7l.tar.gz
    sdl3-linux-aarch64.tar.gz
    sdl3-windows-x86.tar.gz
    sdl3-windows-x64.tar.gz
    sdl3-windows-arm64.tar.gz
    sdl3-macos-arm64.tar.gz

Canonical extracted root is
`sdl3/<platform>/<arch>/{include,lib,manifest.txt}`. Preserve upstream relocatable
CMake metadata under `lib/cmake/SDL3/`.

### Consumer contract

TotalCross must be supportable through the repository-standard module path:

    include(<depot>/sdl3/cmake/AutoFetchSDL3.cmake)
    tcvm_auto_fetch_sdl3()
    find_package(SDL3 REQUIRED)
    target_link_libraries(<target> PRIVATE SDL3::SDL3)

Explicit static consumers may use `SDL3::SDL3-static`.

MBD currently does:

    find_package(SDL3 CONFIG REQUIRED)
    target_link_libraries(board_core PRIVATE SDL3::SDL3)

Therefore auto-fetch must expose the exact staged `SDL3_DIR`, and the packaged
upstream config must preserve the static alias. No consumer should manually
duplicate SDL's platform system libraries/frameworks if upstream metadata
correctly exports them.

### Static SDL3 profile

Use one desktop windowing/context-hosting profile for TotalCross and MBD. Do not
make the older plans' Release-versus-MinSizeRel experiment a release gate; use
the repository default `Release`.

Always force static/install/reproducible behavior:

    BUILD_SHARED_LIBS=OFF  SDL_SHARED=OFF        SDL_STATIC=ON
    SDL_INSTALL=ON        SDL_INSTALL_CPACK=OFF SDL_INSTALL_DOCS=OFF
    SDL_RELOCATABLE=ON    SDL_TEST_LIBRARY=OFF  SDL_TESTS=OFF
    SDL_INSTALL_TESTS=OFF SDL_EXAMPLES=OFF       SDL_LIBC=ON
    CMAKE_POSITION_INDEPENDENT_CODE=ON

Retain low-level window/context support:

    SDL_VIDEO=ON SDL_OPENGL=ON SDL_OPENGLES=ON SDL_VULKAN=ON
    SDL_DUMMYVIDEO=ON SDL_OFFSCREEN=ON

On macOS retain `SDL_COCOA=ON` and `SDL_METAL=ON`. On Windows retain the
DirectX-backed native video support required by SDL. On Linux retain:

    SDL_X11=ON SDL_WAYLAND=ON SDL_KMSDRM=ON
    SDL_DBUS=ON SDL_IBUS=ON SDL_LIBUDEV=ON SDL_DEPS_SHARED=ON

Disable features outside the shared windowing contract:

    SDL_AUDIO=OFF SDL_GPU=OFF SDL_RENDER=OFF SDL_CAMERA=OFF
    SDL_JOYSTICK=OFF SDL_HAPTIC=OFF SDL_HIDAPI=OFF SDL_POWER=OFF
    SDL_SENSOR=OFF SDL_DIALOG=OFF SDL_TRAY=OFF

For the initial Linux package also disable non-required integration/vendor
surface: `SDL_LIBURING`, `SDL_FRIBIDI`, `SDL_LIBTHAI`, `SDL_RPI`,
`SDL_ROCKCHIP`, and `SDL_VIVANTE`.

Keep SDL assembly/SIMD defaults. Do not patch SDL's private dynamic API, define
private `SDL_DISABLE_STB`, or add LTO/IPO for size. Platform-condition arguments
that are inapplicable rather than weakening required backends.

### Corrections learned after SDL2 scaffold commit `fb75cb4`

Incorporate these from the start:

1. **MSVC runtime inheritance:** include
   `cmake/TotalCrossWindowsStaticRuntime.cmake` before `project()` and propagate
   the resolved `CMAKE_MSVC_RUNTIME_LIBRARY` to nested SDL3. Never hard-code the
   repository's `MultiThreaded` value locally. Final archives still run
   `.github/scripts/verify-windows-static-runtime.ps1`.
2. **Portable deterministic packaging:** do not assume Python exists inside Linux
   build images. Prefer the proven shell/tar/gzip approach from current SDL2,
   unless a current shared helper supersedes it.
3. **Platform-aware install paths:** inspect SDL3's actual installed license and
   CMake paths on MSVC/Unix/Apple; do not assume they are identical.
4. **Build before publication:** `scripts/native-stack.py` now allows unpublished
   build members from manifest identity. `sdl3` must build in `others` before
   any `deps.yml` pin exists.
5. **First publication through shared automation:** `scripts/native-release.py`
   now creates an unpublished dependency's initial `deps.yml` entry during the
   authorized metadata step. Do not pre-add it during scaffold.
6. **Windows allocator safety:** SDL2 proved that fallback `dlmalloc` can collide
   with TotalCross's allocator. SDL3 defaults libc ON, but set `SDL_LIBC=ON`
   explicitly and reject `dlmalloc`-family definitions in the packaged Windows
   static library.
7. **Release-state consistency:** effective manifest release, `deps.yml`, native
   artifact checksums, tag, and GitHub Release must refer to the same release
   state; do not hand-update only part of it.

These are acceptance requirements, not later cleanups.

## Plan of Work

### Milestone 1 — Scaffold and lock the contract

Record current branch/commit and path-scoped worktree state. Preserve unrelated
changes; never reset, clean, amend, rebase, or force-push.

Review then create the scaffold:

    python3 tools/new-native-dependency.py create --dry-run \
      --name sdl3 --package SDL3 --version 3.4.16 \
      --source-url https://github.com/libsdl-org/SDL.git \
      --source-tag release-3.4.16 \
      --imported-target SDL3::SDL3 --library-name SDL3 --stack others \
      --targets linux-x86_64 linux-armv7l linux-aarch64 \
                windows-x86 windows-x64 windows-arm64 macos-arm64

Run once without `--dry-run`. If `sdl3/` already exists, inspect it; do not
delete it to make the scaffold run.

Complete `sdl3/manifest.yml` with the immutable source revision, Zlib license,
SDL3 header/static library contract, seven archives, and no dependencies unless
the actual SDL build proves one. Add `libraries.sdl3` and `sdl3` stack membership
to `config/native-builds.yml`. Do not add mobile/web targets or `deps.yml`.

Create the tracked state/evidence files. Validate:

    python3 tools/new-native-dependency.py check sdl3
    python3 scripts/native-build.py validate

Only expected scaffold TODO failures may remain. Also prove the unpublished
`others build` planner can produce SDL3 lanes without a bundle pin.

Acceptance: canonical `sdl3` naming, immutable source/license, central seven-target
graph, no `sdl` alias, no initial `deps.yml` pin, tracked plan artifacts committed.

Validation level: 1 -> 2 before commit.

Commit:

    feat(sdl3): scaffold SDL3 3.4.16 dependency

### Milestone 2 — Reproducible static build and package

Implement `sdl3/CMakeLists.txt` from the current SDL2 wrapper pattern:

- central Windows runtime include before `project()`;
- local source override such as `TC_SDL3_SOURCE_DIR`;
- immutable source URL plus SHA-256;
- out-of-tree upstream build;
- explicit `Release` and SDL3 profile above;
- propagate resolved MSVC runtime, generator platform/toolset, toolchain, Apple
  sysroot/arch/deployment target, system name/processor;
- preserve upstream install tree/CMake exports;
- no runner/image/release policy in CMake.

Keep target scripts minimal delegates to `scripts/build-native-target.sh`.

Implement deterministic `sdl3/scripts/package-artifact.sh`. Require
`include/SDL3/SDL.h`, one SDL3 static library, `SDL3Config.cmake`, static target
exports, and no `.dll`/`.so`/`.dylib`, `SDL3_test`, or shared-target export.
Reject workspace/build/source absolute paths in installed CMake metadata.

Do not depend on Python for archive writing. Use a shell deterministic archive
helper under `sdl3/scripts/` if no shared helper exists. Record in `manifest.txt`
version/tag/revision, target, Release/static/PIC/libc policy, resolved compiler,
MSVC runtime, observed video backends, feature summary, and actual static library
name.

Start with one host-compatible target. Build/package twice and compare archive
SHA-256. Compile two tiny consumers against the install tree, one linking
`SDL3::SDL3-static`, one `SDL3::SDL3`, both including `<SDL3/SDL.h>` and calling
a version API.

Windows validation must additionally run the central `/MT` verifier, machine
architecture check, static consumer link, and reject `dlmalloc`-family definitions
in `SDL3-static.lib`.

Linux must not disable X11/Wayland/KMSDRM to get green. If shared images lack
required dev headers, update the central Docker image policy only after configure
evidence proves it, in a separate commit:

    build(linux): add SDL3 desktop build prerequisites

macOS must prove upstream static metadata carries required framework/system links
without an SDL-specific list in consumers.

Focused checks:

    bash -n sdl3/fetch.sh sdl3/scripts/*.sh
    python3 tools/new-native-dependency.py check sdl3
    python3 scripts/native-build.py validate
    git diff --check -- sdl3 config/native-builds.yml

Acceptance: host build/install/package/link succeeds, repeatable archive hash,
static-only relocatable package, Windows safety gates encoded.

Validation level: 2.

Commit:

    build(sdl3): add reproducible static builds and packaging

### Milestone 3 — Fetch and strict CMake consumption

Implement `sdl3/fetch.sh` with standard
`--platform --arch --release-tag --github-repo --github-token-env --dest`.
Use shared download/checksum helpers, `deps.yml` by default when published,
explicit release handoff before publication, never "latest", atomic replacement,
provenance markers, token-safe output, and zero-network reuse for a complete
matching install.

Implement `AutoFetchSDL3.cmake` using current SDL2 platform/architecture mapping.
It must accept only the seven targets, validate completeness, preserve an explicit
incomplete `SDL3_DEPOT_ROOT` as an error, resolve release handoff/pin, stage only
when missing, set `SDL3_DEPOT_ROOT`, and set:

    SDL3_DIR=${SDL3_DEPOT_ROOT}/lib/cmake/SDL3

Implement strict `FindSDL3.cmake`:

1. choose only the staged depot root;
2. require header, static library, manifest, and staged SDL3 config;
3. set/load the exact staged `SDL3_DIR`/config;
4. require `SDL3::SDL3-static` and `SDL3::SDL3`;
5. reject imported locations/includes escaping the depot root;
6. prove generic `SDL3::SDL3` is backed by the static package.

Do not perform unrestricted CONFIG lookup capable of selecting system,
Homebrew, vcpkg, SDK, or unrelated SDL3.

Add `sdl3/cmake/tests/consumer/` proving module-mode, explicit static target,
CONFIG-mode with staged `SDL3_DIR`, path confinement, and clear failure for an
incomplete root even when a host/fake SDL prefix exists.

Add an MBD-shaped validation using a temporary checkout at a recorded immutable
revision. At plan authoring, MBD `main` is
`c82ae744016f447fccb78087eed89f11b3eec0ff`. Configure against the staged SDL3
with:

    BOARD_BACKEND=SDL3
    MAGIC_BACKEND=CPU
    DOODLE_RENDERER=NONE
    MDB_BUILD_TESTS=OFF
    MDB_BUILD_EXAMPLES=OFF

Do not modify MBD. This only proves its existing CONFIG + `SDL3::SDL3` contract.

Use a TotalCross-shaped module consumer derived from the supplied SDL2 migration
contract; actual SDL API migration is outside scope.

Acceptance: explicit handoff works pre-release; staged module/config consumers
cannot fall back to host SDL; both target names work; MBD-shaped consumer works.

Validation level: 2 -> 3 at checkpoint.

Commit:

    feat(sdl3): add artifact fetch and CMake consumption

### Milestone 4 — Current workflow and seven-target matrix

Replace scaffold workflow with `.github/workflows/sdl3.yml` following current
`sdl2.yml`: `workflow_call`, `workflow_dispatch`, narrow PR paths, operations
`build`, `release`, `force-release`, and delegation to
`.github/workflows/native-library-operation.yml` with `library: sdl3`.

Do not create separate build/release workflows from the old SDL3 plans and do
not duplicate target matrices from `config/native-builds.yml`.

Before publication, prove `others` build planning succeeds with `sdl3` absent
from `deps.yml`. Run focused native stack/release regressions for unpublished
members and initial release behavior.

Validate build mode across Linux x86_64/armv7l/aarch64, Windows x86/x64/ARM64,
and macOS ARM64. Each archive must have canonical layout/version/architecture,
static-only SDL3, relocatable config, consumer link, and expected backend
summary. Windows additionally requires `/MT` plus allocator checks; Linux must
retain declared X11/Wayland/KMSDRM/dummy/offscreen capabilities.

`build` must not change Git, tags, releases, `deps.yml`, or checksums.

Acceptance: workflow delegates correctly, all seven lanes are planned, available
family builds are green, build mode is non-mutating, assets agree with manifest.

Validation level: 3.

Commit:

    ci(sdl3): add desktop build and release workflow

### Milestone 5 — Documentation and publication readiness

Complete `sdl3/README.md` with source/version/license, seven targets/assets,
static profile, retained/disabled backends, `SDL_LIBC=ON` allocator rationale,
Windows `/MT`, Linux backend policy, build/fetch examples, artifact layout,
AutoFetch, module and CONFIG discovery, both target names, release handoff/pin
behavior, and explicit mobile/web/SDL2-compat exclusions.

Remove every `TC_DEPOT_SCAFFOLD_TODO`. Reconcile and commit plan, state,
evidence, optional archive, and editorial report. Do not claim untested targets.

Final non-publication validation:

    python3 tools/new-native-dependency.py check sdl3
    bash -n sdl3/fetch.sh sdl3/scripts/*.sh
    python3 scripts/native-build.py validate
    git diff --check -- sdl3 config/native-builds.yml \
      .github/workflows/sdl3.yml .agent/plans .agent/state \
      .agent/evidence .agent/reports

Run changed-file SPDX validation through `validate-headers`.

Finally consume a freshly staged packaged artifact, not the build install tree,
through module mode, CONFIG mode, and the MBD-shaped test.

Acceptance: structure/graph/consumers pass, tracked plan artifacts are factual and
committed, no generated build/release binaries are tracked, and `deps.yml`
remains untouched until publication is authorized.

Validation level: 3.

Commit:

    docs(sdl3): document usage and finalize onboarding

### Milestone 6 — Explicit publication gate

Do not enter automatically. Obtain explicit authorization for Git/release state
changes and recheck branch/HEAD, concurrent workflow state, existing SDL3 tags or
releases, all seven artifacts, Windows `/MT`/architecture/allocator/link evidence,
Linux backends, and macOS static link metadata.

Run the standard SDL3 workflow operation `release`. Do not manually pre-create
the initial bundle pin. Shared release automation must select `sdl3-3.4.16`
(or repository-supported `-rN` if occupied), update manifest and initial
`deps.yml` entry, record native artifact checksums, commit metadata, tag that same
commit, publish exactly seven assets, and preserve idempotence/recovery behavior.

After publication, freshly fetch published artifacts and run: all three Windows
final checks; one Linux consumer; macOS consumer when available; one default-pin
`tcvm_auto_fetch_sdl3()` consumer; and one MBD-shaped CONFIG consumer.

Reconcile plan/state/evidence/editorial with actual tag, metadata commit,
workflow run, assets, hashes, and limitations. Commit factual post-release plan
artifacts if not already included.

Acceptance: manifest, `deps.yml`, checksums, tag, release, and seven assets agree;
default-pin fetch works; TotalCross/MBD consumption shapes pass published assets.

Validation level: 4.

Optional post-release documentation commit:

    docs(sdl3): record initial SDL3 release

## Surprises & Discoveries

- SDL 3.4.16 is the latest stable release at authoring time; its tag resolves to
  `fa2c02bb6e21974a89ea9824bc53c9932abe5f9c`.
- Upstream 3.4.16 config creates `SDL3::SDL3` as an alias to
  `SDL3::SDL3-static` when no shared target exists.
- MBD's Board SDL3 backend uses CONFIG discovery and `SDL3::SDL3`.
- SDL3 defaults `SDL_LIBC` ON, but SDL2/TotalCross proved fallback allocator
  symbols can collide; keep it explicit and validate the final Windows library.
- SDL2 packaging had to remove an undeclared Python requirement (`269508560...`).
- Nested MSVC runtime policy had to be inherited rather than hard-coded
  (`af214f325...`).
- Unpublished stack build and first-release metadata behavior were fixed after
  SDL2 onboarding (`530fbffc...`, `9525565b...`).

Add only discoveries that change remaining work. Move resolved history to the
archive when this section grows.

## Decision Log

- **SDL 3.4.16 exact pin.** Latest stable verified 2026-09-03; supersedes 3.4.12
  in the older plans.
- **Repository name `sdl3`.** Keeps SDL2 and SDL3 independently managed and avoids
  ambiguous `sdl`.
- **Seven desktop targets only.** Matches depot desktop matrix and current
  TotalCross/MBD SDL use; no mobile/web artifacts.
- **Static-only with both upstream target names.** TotalCross can use the public
  depot contract and existing MBD can continue `SDL3::SDL3`.
- **Preserve upstream CMake exports.** They own static platform transitive links;
  do not duplicate them manually without proof of a packaging defect.
- **Windowing/context profile.** Retain Video + OpenGL/OpenGLES/Vulkan/Metal and
  native Linux/Windows/macOS backends; disable SDL renderer/GPU/audio and unrelated
  devices/utilities.
- **`SDL_LIBC=ON` plus Windows symbol gate.** Prevent recurrence of the SDL2
  fallback allocator collision.
- **Release configuration.** Use repository `Release`; size benchmarking is not
  an onboarding gate.
- **One native-operation workflow.** Old SDL3 separate build/release workflow
  design is obsolete.
- **No pre-publication `deps.yml` pin.** Current shared tooling supports
  unpublished build and atomic first publication.
- **Commit durable `.agent` artifacts.** User requirement; raw build output stays
  ephemeral.

All decisions dated 2026-09-03 unless execution records a later replacement.

## Validation and Acceptance

Use the smallest sufficient level: level 1 for scaffold/graph; level 2 for
build/package/fetch slices; level 3 for desktop family/workflow/fresh consumer
checkpoints; level 4 only for publication.

Plan completion requires: exact 3.4.16 source bytes; seven assets consistent
across metadata/workflow/docs; static-only relocatable CMake package; both SDL3
target names; Windows `/MT` and no fallback allocator; declared Linux backends;
macOS framework/system links through SDL metadata; checksum-verified atomic
idempotent fetch; no system SDL fallback in module or CONFIG mode; TotalCross-
and MBD-shaped consumers; unpublished build planning; correct first-release
metadata/checksum behavior when authorized; and all durable `.agent` artifacts
committed.

## Risks and Open Questions

Linux image packages are the largest build risk. Do not silently publish an
archive missing X11, Wayland, or KMSDRM because one image lacks headers; update
central images only from configure evidence.

Inspect SDL3 static export metadata for absolute workspace paths and dependency
lookups that could bind to a build-host installation. Prefer upstream relocatable
exports and apply only the smallest correction if required.

Windows ARM64 may differ in feature detection. Diagnose target-specific causes
before weakening the shared profile.

MBD currently pins an older depot-tools ref; advancing that ref and invoking
SDL3 auto-fetch is downstream work. TotalCross SDL2-to-SDL3 API migration is also
downstream. Do not absorb either migration into this plan unless a failure is
proven to be a depot artifact defect.

## Idempotence and Recovery

Scaffolding is one-shot; never delete existing `sdl3/` just to regenerate it.
Use task-specific build directories and preserve unrelated user trees.

Fetch replacement is checksum-verified beside the destination; keep the prior
complete tree until replacement succeeds. A complete matching provenance marker
must allow zero-network reuse.

Before each logical commit inspect path-scoped status/diff, run `git diff --check`,
stage only intended files including current tracked plan artifacts, and use the
`logical-commits` skill. Never amend/rebase/force-push.

Release must use repository concurrency guards and treat metadata-without-tag,
tag-without-release, draft release, metadata mismatch, and missing/unexpected
assets as recovery states rather than blindly creating new state.

## Outcomes & Retrospective

Keep this short while active. At milestone/final completion record factual
implementation commits, source checksum, final profile, changed paths, seven
artifact hashes/build results, Linux backend summaries, Windows
runtime/architecture/allocator/static-link results, macOS link result, module and
CONFIG consumers, MBD tested revision/configuration, workflow run IDs, release
tag/URL when authorized, metadata/checksum commit, and remaining downstream work.

The final editorial report must contain the sections required by
`.agent/PLANS.md`. Never describe planned behavior as delivered behavior.

## Revision Note

2026-09-03: Initial ExecPlan created from the SDL2 2.32.8 onboarding plan, the
TotalCross SDL2 depot migration plan, two older SDL3 3.4.12 plans, current
depot-tools policy, upstream SDL3 3.4.16, MBD's current SDL3 CMake contract, and
the post-`fb75cb4` SDL2 corrections. It adopts current one-workflow release
orchestration, unpublished-build/initial-publication support, inherited Windows
runtime policy, portable deterministic packaging, and explicit allocator safety
from the beginning.
