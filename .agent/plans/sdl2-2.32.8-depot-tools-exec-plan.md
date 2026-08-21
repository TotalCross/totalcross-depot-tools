<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Add SDL2 2.32.8 to totalcross-depot-tools

This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`.

## Purpose / Big Picture

Add SDL 2.32.8 as a first-class native dependency in
`totalcross-depot-tools` under the repository-facing name `sdl2`.

The completed dependency must be independently buildable, packageable, fetchable,
releasable, and consumable through the repository-standard CMake flow:

    sdl2/scripts/build-<target>.sh
    sdl2/fetch.sh
    sdl2/cmake/AutoFetchSDL2.cmake
    find_package(SDL2 REQUIRED)
    target_link_libraries(<consumer> PRIVATE SDL2::SDL2)

All repository-facing names use `sdl2`, never `sdl`. Upstream/public API names
remain `SDL2` where required, including `SDL2::SDL2`, `SDL2Config.cmake`, and
`<SDL2/SDL.h>`.

Pin SDL exactly to 2.32.8 / `release-2.32.8`. Do not silently upgrade to 2.32.10,
SDL3, or `sdl2-compat`.

Initial targets:

- `linux-x86_64`
- `linux-armv7l`
- `linux-aarch64`
- `windows-x86`
- `windows-x64`
- `windows-arm64`
- `macos-arm64`

Android, iOS, WebAssembly, SDL3, `sdl2-compat`, and TotalCross consumer changes
are out of scope.

## Working Set and Resume Protocol

Intended repository plan path:

    .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md

Supporting files when useful:

    .agent/state/add-sdl2-2.32.8.md
    .agent/evidence/add-sdl2-2.32.8.md
    .agent/archive/add-sdl2-2.32.8-history.md
    .agent/reports/add-sdl2-2.32.8-editorial.md

On resume, read the state file first. Do not routinely reread the complete plan,
`AGENTS.md`, `.agent/PLANS.md`, raw logs, or evidence history.

Before implementation, read once:

- `AGENTS.md`
- `.agent/PLANS.md`
- `docs/DEPENDENCY_STANDARD.md`
- `.agents/skills/add-native-dependency/SKILL.md`
- `.agents/skills/logical-commits/SKILL.md`
- `.agents/skills/validate-headers/SKILL.md`
- `config/native-builds.yml`
- one representative CMake dependency, preferably `libjpeg-turbo`

Expected upstream contract:

    repository:      https://github.com/libsdl-org/SDL.git
    version:         2.32.8
    source tag:      release-2.32.8
    license:         zlib, upstream LICENSE.txt
    package:         SDL2
    public target:   SDL2::SDL2
    static target:   SDL2::SDL2-static

Keep full build/CI output in logs or artifacts. Evidence contains only concise
status, hashes, paths, and limitations.

## Progress

- [x] (2026-08-21T00:05:00Z) Reviewed repository plan/dependency policy, central
  targets, one representative dependency, and upstream SDL 2.32.8 CMake
  contracts.
- [x] Fixed initial decisions: `sdl2`, version 2.32.8, seven desktop targets,
  static PIC build, and public target `SDL2::SDL2`.
- [x] (2026-08-21T01:05:00Z) Milestone 1: scaffold and metadata/source
  contracts committed as `fb75cb4`.
- [x] (2026-08-21T01:35:00Z) Milestone 2: immutable static/PIC build and
  deterministic packaging committed as `90572fa`; macOS ARM64 package and
  linked upstream-config consumer passed.
- [x] (2026-08-21T01:55:00Z) Milestone 3: checksum-pinned atomic fetch,
  idempotent reuse, strict depot CMake resolution, and failure-with-host-prefix
  consumer validation committed as `dee4140`.
- [x] (2026-08-21T02:20:00Z) Milestone 4: shared workflow, seven-target plan,
  release contract, dry-run commands, and focused orchestration tests committed
  as `28cdf4a`; platform execution limitations are recorded in evidence.
- [x] (2026-08-21T02:40:00Z) Milestone 5: documentation, fresh-artifact
  consumer, structural, header, syntax, graph, contract, policy, and focused
  orchestration validation passed.
- [ ] Publication gate: release and `deps.yml` pin only when explicitly
  authorized.

## Current Architecture and Scope

A standard dependency provides:

    <dependency>/
      README.md
      manifest.yml
      CMakeLists.txt
      fetch.sh
      cmake/AutoFetch<Package>.cmake
      cmake/Find<Package>.cmake
      scripts/package-artifact.sh
      scripts/build-<target>.sh

and one `.github/workflows/<dependency>.yml`.

Operational platform policy belongs in `config/native-builds.yml`; target scripts
delegate to shared executors.

SDL2 repository-facing contract:

    directory/config key: sdl2
    workflow:             .github/workflows/sdl2.yml
    archive/release:      sdl2-...
    package:              SDL2
    public target:        SDL2::SDL2
    auto-fetch:           sdl2/cmake/AutoFetchSDL2.cmake
    find module:          sdl2/cmake/FindSDL2.cmake

Never introduce a top-level `sdl/`, `AutoFetchSDL.cmake`, `FindSDL.cmake`, an
`sdl` dependency key, or `sdl-*` assets.

Build static PIC SDL2:

    SDL_SHARED=OFF
    SDL_STATIC=ON
    SDL_STATIC_PIC=ON
    SDL_TEST=OFF
    SDL_TESTS=OFF
    SDL_INSTALL_TESTS=OFF
    SDL2_DISABLE_SDL2MAIN=ON

TotalCross owns its entrypoint, so SDL2main is outside this initial artifact
contract.

On MSVC preserve `/MT` using the repository Windows runtime policy plus
`SDL_FORCE_STATIC_VCRT=ON` and, where needed,
`CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded`.

Do not disable video backends simply to get a green build. If shared Linux images
lack required development headers, update central image policy only when actual
SDL configure/build evidence proves the need.

Static SDL2 has platform system-link requirements. Prefer preserving relocatable
upstream metadata under `lib/cmake/SDL2/`. SDL's static-only config already
provides `SDL2::SDL2` through `SDL2::SDL2-static`.

Before accepting upstream metadata, inspect representative
`SDL2staticTargets*.cmake` files for workspace paths or non-portable absolute
dependency paths. If necessary, implement the smallest controlled
platform-specific correction. Never fall back to system/Homebrew/vcpkg SDL.

Canonical archives contain:

    sdl2/<platform>/<arch>/include/
    sdl2/<platform>/<arch>/lib/
    sdl2/<platform>/<arch>/manifest.txt

Expected assets:

    sdl2-linux-x86_64.tar.gz
    sdl2-linux-armv7l.tar.gz
    sdl2-linux-aarch64.tar.gz
    sdl2-windows-x86.tar.gz
    sdl2-windows-x64.tar.gz
    sdl2-windows-arm64.tar.gz
    sdl2-macos-arm64.tar.gz

Preserve `include/SDL2/`. Validate actual static library names; Unix normally
uses `libSDL2.a`, while MSVC may use `SDL2-static.lib`.

## Plan of Work

### Milestone 1 — Scaffold and lock the contract

Goal: create the standard `sdl2` structure and verify all source/build inputs.

Review the scaffold first:

    python3 tools/new-native-dependency.py create \
      --dry-run \
      --name sdl2 \
      --package SDL2 \
      --version 2.32.8 \
      --source-url https://github.com/libsdl-org/SDL.git \
      --source-tag release-2.32.8 \
      --imported-target SDL2::SDL2 \
      --library-name SDL2 \
      --stack others \
      --targets \
        linux-x86_64 linux-armv7l linux-aarch64 \
        windows-x86 windows-x64 windows-arm64 \
        macos-arm64

Confirm repository paths/assets use `sdl2` while public CMake identifiers use
`SDL2`. Then run the create command once without `--dry-run`. If `sdl2/` already
exists, inspect it; do not delete it to rerun scaffolding.

Complete initial metadata:

- verify `release-2.32.8` and record its resolved revision;
- preserve/document upstream `LICENSE.txt`;
- complete `sdl2/manifest.yml`;
- register `libraries.sdl2` and the seven targets in
  `config/native-builds.yml`;
- add `sdl2` to stack `others`;
- use `build_system: cmake`;
- do not add mobile/wasm targets;
- do not add a `deps.yml` pin before an effective release exists.

Run:

    python3 tools/new-native-dependency.py check sdl2
    python3 scripts/native-build.py validate

Scaffold TODO failures are work items; do not weaken the checker.

Acceptance: canonical structure, source/license verified, central targets
recognized, no repository-facing `sdl` alias.

Commit:

    feat(sdl2): scaffold SDL2 2.32.8 dependency

If actual Linux configure evidence proves shared image prerequisites are missing,
make that an independent logical commit:

    build(linux): add SDL2 native build prerequisites

### Milestone 2 — Build and package SDL2

Goal: produce a usable static SDL2 install and canonical archive through shared
executors.

Implement `sdl2/CMakeLists.txt` using the established wrapper pattern:

- include `cmake/TotalCrossWindowsStaticRuntime.cmake` before `project()`;
- provide local source override such as `TC_SDL2_SOURCE_DIR`;
- default to the pinned SDL repository/tag;
- build upstream out-of-tree;
- apply the static/PIC/test/SDL2main settings above;
- propagate shared toolchain/architecture/Apple/MSVC inputs;
- install headers, static library, and usable SDL2 CMake metadata;
- do not embed runner/image/release policy.

Keep target wrappers minimal, executable, and delegated to
`scripts/build-native-target.sh`.

Implement deterministic `sdl2/scripts/package-artifact.sh`. `manifest.txt`
records version/source, platform/arch, Release configuration, static/PIC policy,
SDL2main-disabled state, and relevant compiler/backend information.

Start with one host-compatible target. Verify:

- `include/SDL2/SDL.h`;
- SDL2 static library;
- `lib/cmake/SDL2/SDL2Config.cmake` if retained;
- no workspace path in exported CMake metadata;
- canonical archive file list.

Compile/link a minimal local-install consumer that calls `SDL_GetVersion`. A
window is not required at this slice.

Focused checks:

    bash -n sdl2/fetch.sh sdl2/scripts/*.sh
    python3 tools/new-native-dependency.py check sdl2
    git diff --check -- sdl2 config/native-builds.yml

Acceptance: one host-compatible target builds, installs, packages, and links.

Commit:

    build(sdl2): add reproducible static builds and packaging

### Milestone 3 — Fetch and strict CMake consumption

Goal: consumers resolve only depot SDL2 artifacts.

Implement standard `sdl2/fetch.sh` options:

    --platform --arch --release-tag --github-repo --github-token-env --dest

It must use the `deps.yml` release pin when available, honor explicit handoff,
never query "latest", stage atomically under
`sdl2/local/<platform>/<arch>`, avoid token leakage, record provenance, and
succeed without redownloading an already complete matching artifact.

Implement `AutoFetchSDL2.cmake` using repository platform/architecture mapping.
Fetch only if staged headers/library/CMake metadata are incomplete.

Implement `FindSDL2.cmake` with strict depot-only behavior. Preferred path:

1. select the staged depot root;
2. verify header, static library, and staged SDL2 config;
3. load that staged `SDL2Config.cmake` directly;
4. require `SDL2::SDL2` and `SDL2::SDL2-static`;
5. verify imported/resolved paths belong to the staged root.

Do not perform an unrestricted package search capable of selecting host SDL2.

If upstream exports prove non-relocatable, build only the required controlled
import/system-link adaptation and record the reason in the Decision Log.

Consumer fixture:

- add `sdl2/cmake` to `CMAKE_MODULE_PATH`;
- use auto-fetch when a real release override exists, otherwise local staging;
- `find_package(SDL2 REQUIRED)`;
- link only `SDL2::SDL2`;
- include `<SDL2/SDL.h>`;
- call `SDL_GetVersion`;
- prove SDL paths are inside depot-tools.

Also test missing/incomplete staging: configuration must fail clearly instead of
selecting system SDL2.

Acceptance: fetch idempotent, depot-only resolution, correct static transitive
links, no silent host SDL fallback.

Commit:

    feat(sdl2): add artifact fetch and CMake consumption

### Milestone 4 — Workflow and desktop matrix

Goal: integrate SDL2 with shared native-operation CI.

Create `.github/workflows/sdl2.yml` with the repository-standard
`workflow_call`, `workflow_dispatch`, PR triggers, and operations
`build`, `release`, `force-release`.

Delegate to:

    .github/workflows/native-library-operation.yml

using:

    library: sdl2

Do not duplicate target matrices already in central configuration. `build`
remains the default and must not mutate Git, tags, releases, or `deps.yml`.

At this checkpoint validate available declared targets:

- Linux x86_64, armv7l, aarch64;
- Windows x86, x64, ARM64;
- macOS ARM64.

Run the Windows static-runtime verifier. Inspect Linux configure capability
differences if they are material. On macOS verify `SDL2::SDL2` carries required
system framework links without consumer-side SDL-specific framework lists.

Acceptance: workflow recognizes `sdl2`, build mode produces manifest-matching
archives, `/MT` passes, and no release state changes.

Commit:

    ci(sdl2): add desktop build and release workflow

### Milestone 5 — Documentation and publication readiness

Goal: finish the repository-facing contract.

Complete `sdl2/README.md` with upstream version/tag/license, intentional 2.32.8
pin, targets, static/PIC and SDL2main-disabled policy, local build commands,
archive layout, fetch usage, `AutoFetchSDL2.cmake`,
`find_package(SDL2 REQUIRED)`, `SDL2::SDL2`, release-pin behavior, observed
Linux prerequisites, Windows `/MT`, and focused validation.

Remove every `TC_DEPOT_SCAFFOLD_TODO`.

Final checks:

    python3 tools/new-native-dependency.py check sdl2
    bash -n sdl2/fetch.sh sdl2/scripts/*.sh
    python3 scripts/native-build.py validate
    git diff --check -- \
      sdl2 config/native-builds.yml \
      .github/workflows/sdl2.yml deps.yml

Run changed-file SPDX validation through `validate-headers`.

Run a final consumer from a freshly staged artifact rather than directly from
the build install tree.

Acceptance: structural checker passes, all target/asset metadata agrees, available
build matrix is green, strict consumer passes, no generated build output is
tracked.

Commit:

    docs(sdl2): document usage and finalize onboarding

If documentation is already logically committed, do not create an artificial
documentation-only diff.

### Publication Gate — Explicit authorization required

Publishing/tagging and the final `deps.yml` pin are state-changing.

When explicitly authorized, use the shared `release` operation. Expected initial
effective release:

    sdl2-2.32.8

Before publication recheck release/tag existence, revision, unrelated local
changes, and the seven assets. Release automation must update
`sdl2/manifest.yml` and `deps.yml`, commit them, tag that exact commit, publish
the release, and verify assets.

Required `deps.yml` shape:

    sdl2:
      version: 2.32.8
      release: <effective sdl2 release tag>
      path: sdl2

Never create an `sdl` compatibility key.

Normal `release` is idempotent if the release already exists. Never move an
existing tag. Use `force-release` only by explicit request.

After publication, run one real default-pin auto-fetch + consumer test.

## Surprises & Discoveries

- The native policy-literal validator requires nested MSVC runtime propagation
  to use the value established by `TotalCrossWindowsStaticRuntime.cmake`; the
  initial literal was replaced and validated in `af214f3`.
- SDL 2.32.8 supports static-only installs and exposes `SDL2::SDL2` through
  `SDL2::SDL2-static`.
- Static filenames differ on MSVC versus Unix-like systems.
- Static SDL2 carries platform system-link requirements; exported metadata
  relocatability is an explicit acceptance test.
- Repository policy requires the native-dependency scaffold and central config
  rather than copying an arbitrary older dependency.

Add entries only when they materially affect remaining work.

## Decision Log

- Decision: repository-facing name is `sdl2`.
  Rationale: explicit requirement and clear SDL2/SDL3 distinction.
  Date: 2026-08-21.

- Decision: pin `release-2.32.8`.
  Rationale: requested version; no automatic upgrade.
  Date: 2026-08-21.

- Decision: initial scope is seven Linux/Windows/macOS targets.
  Rationale: current TotalCross desktop use; mobile is separate work.
  Date: 2026-08-21.

- Decision: static PIC build with SDL2main disabled.
  Rationale: repository defaults and TotalCross-owned entrypoint.
  Date: 2026-08-21.

- Decision: public target is `SDL2::SDL2`.
  Rationale: upstream contract hides platform filename differences.
  Date: 2026-08-21.

- Decision: prefer upstream CMake exports if relocatable.
  Rationale: avoid duplicating platform system dependencies.
  Date: 2026-08-21.

- Decision: stack is `others`.
  Rationale: current scope is windowing/input rather than codec/raster graphics.
  Date: 2026-08-21.

- Decision: publication and `deps.yml` pin are an explicit gate.
  Rationale: manifest, tag, release, and bundle pin must refer to one effective
  release.
  Date: 2026-08-21.

## Validation and Acceptance

Use the smallest sufficient level.

Level 1: scaffold/check, one affected configure/build, shell syntax, package file
list.

Level 2: changed-file headers, `new-native-dependency.py check sdl2`, focused
build/package or consumer, `git diff --check`.

Level 3: affected target families, Windows `/MT`, package layout, strict CMake
consumer, workflow build/release dry-run without publication.

Level 4: available seven-target matrix, manifest/archive consistency, graph/config
validation, fetch idempotence, end-to-end consumer, real default-pin auto-fetch
after publication.

Final acceptance:

1. repository-facing paths/assets use `sdl2`;
2. source is exactly SDL 2.32.8;
3. declared targets produce matching archives;
4. archives provide headers, static library, and usable CMake metadata;
5. auto-fetch stages only depot artifacts;
6. `find_package(SDL2 REQUIRED)` yields usable `SDL2::SDL2`;
7. host SDL installations cannot silently satisfy the dependency;
8. Windows static runtime is `/MT`;
9. workflow uses shared native-operation infrastructure;
10. authorized publication yields a consistent `sdl2` release and `deps.yml`
    pin.

## Risks and Open Questions

- Upstream static exports may contain absolute host dependency paths.
- Shared Linux images may lack desired X11/Wayland development headers.
- Linux ARM targets may expose different backend sets.
- MSVC static filename differs from Unix output.
- Canonical packaging must preserve nested `lib/cmake/SDL2`.
- SDL2main is intentionally absent.
- Mobile targets remain out of scope.

Resolve these from actual build/configure evidence; do not broaden scope
preemptively.

## Idempotence and Recovery

The scaffold refuses existing directories. Resume an interrupted scaffold by
inspecting `sdl2/`; do not delete it merely to regenerate.

Use dedicated build/install directories and preserve unrelated caches.

Packaging may replace only its own target archive. `fetch.sh` treats a complete
matching staged artifact as success and handles incomplete staging atomically.

Preserve unrelated working-tree changes. Inspect only relevant paths:

    git status --short -- \
      sdl2 config/native-builds.yml \
      .github/workflows/sdl2.yml deps.yml
    git diff --stat
    git diff -- \
      sdl2 config/native-builds.yml \
      .github/workflows/sdl2.yml deps.yml

Stage only confirmed paths. Never use `git add .`, `git add -A`, or
`git add --all`. Do not amend, rebase, force-push, or rewrite history unless
explicitly requested.

Release recovery must recheck remote state, never move existing tags, and keep
manifest, `deps.yml`, tag, and GitHub Release on one effective revision.

## Commit Strategy

Use English Conventional Commits with explanatory bodies.

Expected sequence:

1. `feat(sdl2): scaffold SDL2 2.32.8 dependency`
2. optional if proven necessary:
   `build(linux): add SDL2 native build prerequisites`
3. `build(sdl2): add reproducible static builds and packaging`
4. `feat(sdl2): add artifact fetch and CMake consumption`
5. `ci(sdl2): add desktop build and release workflow`
6. `docs(sdl2): document usage and finalize onboarding`

Release automation may create its own metadata commit after publication is
authorized.

After each logical commit update the state file with commit, focused validation,
remaining work, and deferred expensive validation.

## Outcomes & Retrospective

All five non-publication milestones are complete. SDL 2.32.8 is pinned to an
immutable revision and archive digest, builds static PIC with SDL2main disabled,
packages relocatable upstream metadata deterministically, stages checksum-pinned
artifacts atomically, and resolves only the selected depot root through
`SDL2::SDL2`.

macOS ARM64 was built, packaged, fetched, linked, and run. The generated workflow
and central plan declare three Linux, three Windows, and one macOS target, but
Linux Docker and Windows MSVC execution were unavailable locally and are not
claimed as completed platform evidence. See
`.agent/evidence/add-sdl2-2.32.8.md` and the editorial report for exact results.

No release, tag, push, checksum publication metadata, or `deps.yml` sdl2 pin was
created. The publication gate remains deliberately open pending explicit
authorization and successful CI platform evidence.

Final editorial report:

    .agent/reports/add-sdl2-2.32.8-editorial.md

## Revision Note

2026-08-21: Initial ExecPlan created from current repository policy and upstream
SDL 2.32.8 CMake contracts. The first depot SDL2 integration is intentionally
desktop-only, static/PIC, repository-named `sdl2`, and pinned to 2.32.8.

2026-08-21: Consolidated the completed non-publication milestones and recorded
platform execution limits. Publication remains a separate authorized operation.
