<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native build policy and replace duplicated release orchestration

This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`. It is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, `Outcomes & Retrospective`, and the supporting state and evidence files synchronized at meaningful checkpoints rather than after every command.

## Purpose / Big Picture

After this change, maintainers can locate and run an explicit build script for any published library target without finding toolchain policy copied into that script. Android NDK and API policy, Linux image versions, Windows generators, runtime rules, runner labels, target mappings, dependency edges, and stack membership come from one validated configuration.

Each library has one GitHub Actions workflow with `build`, `release`, and `force-release` operations. A normal release is idempotent: when the requested effective release already exists, the workflow succeeds without rebuilding and exposes the existing release URL. A forced release always rebuilds and selects the next suffix under the repository's current release naming rule.

The graphics and others stack entry points build only what is needed. Normal stack release mode reuses existing dependency releases and skips libraries whose requested versions are already published. Releases remain individual. Every newly published release updates the library manifest and `deps.yml` in a commit before its tag is created, so the effective tag, GitHub Release, and compatible bundle index point to the same revision.

Skia remains parallel by target. Platform-runner reuse may continue into one matching Skia target, but must not collapse the existing target concurrency or serialize iOS, iOS Simulator, Linux, Android, Windows, WebAssembly, and macOS Skia work behind one runner.

A developer can observe the result by running explicit target and stack scripts locally, dispatching any library workflow in `build` mode, dispatching an already-published version in `release` mode and receiving its existing URL without build jobs, and inspecting a new release tag whose commit already contains the effective release in both the library manifest and `deps.yml`.

## Working Set and Resume Protocol

Use these supporting files during execution:

- `.agent/state/centralize-native-builds-and-release-orchestration.md`: first read on every continuation. Rewrite it with the active milestone, current slice, last logical commit, active paths, next concrete action, focused validation, deferred validation, blockers, and resume command.
- `.agent/evidence/centralize-native-builds-and-release-orchestration.jsonl`: append one compact record for each material validation, workflow run, release dry run, configuration snapshot, or artifact comparison. Search it by milestone or command; do not read it in full during normal resumption.
- `.agent/archive/centralize-native-builds-and-release-orchestration-history.md`: completed milestone detail, removed workflow inventory, retired alternatives, and migration notes. Do not read by default.
- `.agent/reports/centralize-native-builds-and-release-orchestration-editorial.md`: factual milestone and final report. Update at major architecture and release checkpoints, not every slice.

At a fresh start, read `AGENTS.md`, `.agent/PLANS.md`, this plan, and the current files named in the active milestone. On continuation, read the state file first and then only the active configuration, scripts, workflows, tests, or dependency directories. Do not reread every library workflow or full historical plan.

## Progress

- [x] (2026-07-18T01:10:00Z) Reviewed the implementation from `2ddd981` through `4cdaddd` and the follow-up commits through `67cd3bc`; confirmed that shared CMake execution exists but platform policy and runner reuse remain incomplete.
- [x] (2026-07-18T01:10:00Z) Confirmed required policy decisions: Android API 23 remains the default for the next release; minizip retains an Android API 24 override; explicit target script names remain; Skia target parallelism remains; sqlite3 and SLJIT join the unrelated/rarely-updated stack.
- [x] (2026-07-19T05:57:47Z) Created the state, evidence, archive, and editorial files and added a reproducible baseline inventory of workflow contracts, manifest archives, policy literals, release helpers, stack topology, and Skia jobs. Evidence: `.agent/evidence/centralize-native-builds-and-release-orchestration.jsonl`.
- [ ] Introduce and validate central native-build configuration and resolution without changing existing workflow behavior.
- [ ] Make local explicit scripts and the composite action use one shared executor and central target resolution.
- [ ] Add repository guidance, standard dependency documentation, scaffold tooling, consumer documentation, and repository/consumer skills.
- [ ] Replace each build/release workflow pair with one operation-based workflow while preserving build artifacts and release names.
- [ ] Implement idempotent individual release and forced-release behavior with metadata commit/tag/release alignment.
- [ ] Implement selective graphics and others stack planning, dependency resolution, platform runner reuse, and individual publication.
- [ ] Preserve and validate Skia target parallelism with opportunistic platform-lane reuse.
- [ ] Remove superseded workflows and duplicated literals only after equivalent build and release dry runs pass.
- [ ] Complete operation-family and release-gate validation, reconcile evidence, and finalize the editorial report.

## Current Architecture and Scope

The repository contains one directory per native dependency. Most use CMake wrappers, `fetch.sh`, CMake consumer modules, package scripts, reusable build workflows, and separate release workflows. Skia uses GN/Ninja and separate scripts. `deps.yml` records compatible release pins.

The implementation through `67cd3bc` added `.github/actions/build-native-library/action.yml`, `scripts/build-cmake-multi.sh`, and explicit zlib target wrappers. The action and script both implement configure, build, optional CTest, install, package, and optional Docker execution. Workflows still pass raw `cmake-args`, including Android toolchain literals, Linux image tags, Visual Studio generator names, architecture flags, and `/MT` policy.

`.github/native-build-targets.yml` contains some runner, image, Android, and Apple metadata, but workflows and scripts do not resolve their effective values from it. It is not yet an operational source of truth.

The graphics and small-library release-stack workflows currently call each library's reusable build workflow. Reusable workflow jobs receive new runners, so those stack files express dependency order but do not share checkout, Docker initialization, NDK setup, downloaded sources, or local artifacts across libraries.

This plan changes build and release orchestration but does not intentionally change upstream library features, library ABI, archive layout, imported CMake target names, supported release assets, or the current release suffix semantics. A deliberate Android default increase from API 23 to API 24 is out of scope for the next release; the configuration must make that later change a one-line policy update after consumer compatibility is approved.

## Target configuration design

Create `config/native-builds.yml` as the operational source of platform, target, library, dependency, and stack metadata. Do not rely on YAML interpolation. `scripts/native-build.py` reads the document and composes effective values.

The top-level shape is:

    schema: 1

    defaults:
      configuration: Release
      cmake_generator: Ninja

    platforms:
      android:
        runner: ubuntu-24.04
        ndk_version: 28.2.13676358
        default_api: 23
        use_legacy_toolchain: false
      linux:
        runner: ubuntu-22.04
        image_registry: totalcross
        image_version: v2.0.1
      windows:
        runner: windows-2022
        generator: Visual Studio 17 2022
        runtime_policy: cmake/TotalCrossWindowsStaticRuntime.cmake
        expected_runtime: MultiThreaded
      apple:
        runner: macos-15

    targets:
      linux-x86_64:
        platform: linux
        arch: x86_64
        image: linux-amd64
        docker_platform: linux/amd64
      linux-armv7l:
        platform: linux
        arch: armv7l
        image: linux-arm32v7
        docker_platform: linux/arm/v7
        qemu: true
      linux-aarch64:
        platform: linux
        arch: aarch64
        runner: ubuntu-22.04-arm
        image: linux-arm64
        docker_platform: linux/arm64
      android-arm64:
        platform: android
        arch: arm64-v8a
      windows-x86:
        platform: windows
        arch: x86
        cmake_platform: Win32
      windows-x64:
        platform: windows
        arch: x64
        cmake_platform: x64
      windows-arm64:
        platform: windows
        arch: arm64
        runner: windows-11-arm
        cmake_platform: ARM64
      macos-arm64:
        platform: apple
        artifact_platform: macos
        arch: arm64
        generator: Ninja
      ios-arm64:
        platform: apple
        artifact_platform: ios
        arch: arm64
        generator: Xcode
        sysroot: iphoneos
      ios-simulator-arm64:
        platform: apple
        artifact_platform: ios-simulator
        arch: arm64
        generator: Xcode
        sysroot: iphonesimulator
      wasm:
        platform: web
        arch: wasm32

A Linux effective image is composed as `<image_registry>/<target.image>:<image_version>`. Therefore changing `platforms.linux.image_version` updates every standard Linux target. A target or library may override an image only when it genuinely requires a different toolchain, such as Skia.

Library entries name build system, package script, test policy, published targets, true dependencies, and overrides. For example:

    libraries:
      minizip:
        build_system: cmake
        package_script: minizip/scripts/package-artifact.sh
        targets: [linux-x86_64, linux-armv7l, linux-aarch64, windows-x86, windows-x64, windows-arm64, android-arm64, macos-arm64, ios-arm64, ios-simulator-arm64]
        dependencies:
          zlib:
            cmake_variable: ZLIB_DIR
        target_overrides:
          android-arm64:
            android_api: 24

      skia:
        build_system: gn
        long_running: true
        preserve_target_parallelism: true
        dependencies:
          zlib-ng: {}
          libpng: {}

The resolver applies defaults, platform values, target values, library values, and library target overrides in that order. It rejects unknown keys where practical, missing target references, dependency cycles, unsupported target/library pairs, and complete image tags embedded in target overrides when a standard composed image should be used.

Stacks are co-scheduling groups and are separate from dependency edges:

    stacks:
      graphics:
        libraries: [zlib, zlib-ng, minizip, minizip-ng, libpng, libjpeg, libjpeg-turbo, skia]
      others:
        libraries: [qrcode, qrcodegen, axtls, mbedtls, sqlite3, sljit, vcruntime]

A library can share a stack without depending on every other member. The graph generator uses only `dependencies` for topological order.

## Plan of Work

### Milestone 1: Establish compact baseline and migration safety

Create the supporting files and capture a machine-readable inventory with a focused script or one-off command stored in evidence. Record:

- current build and release workflows per library;
- current workflow inputs and outputs;
- artifact names from manifests and workflows;
- every literal occurrence of NDK version, Android API, Linux image tag, Visual Studio generator, and `CMAKE_MSVC_RUNTIME_LIBRARY` in first-party build paths;
- current setup and release metadata helpers;
- current release suffix selection logic;
- current individual and stack workflow job topology;
- current Skia target job parallelism;
- representative successful build-only or dry-run workflow run identifiers when available.

Use `rg` and scoped file lists. Do not dump every workflow into the active plan. Store counts and paths in evidence and detailed inventory in the archive.

Acceptance is a reproducible inventory command and a state file that lets another agent identify the exact files to migrate without rereading the repository.

Validation level: Level 1. Run syntax checks only for any inventory helper and `git diff --check` for supporting files.

### Milestone 2: Add central configuration and resolver

Create `config/native-builds.yml`, `scripts/native-build.py`, and focused unit tests under `scripts/tests` or the existing script-test location.

The CLI initially supports:

    scripts/native-build.py validate
    scripts/native-build.py show <library> <target> --format text|json|github-output
    scripts/native-build.py list-targets <library> --format json
    scripts/native-build.py graph <stack> --format json|mermaid
    scripts/native-build.py plan <library-or-stack> --operation build|release|force-release --format json

`show` emits effective runner, platform, architecture, generator, configuration, Android NDK/API/ABI, Docker image/platform/QEMU, Apple sysroot, package script, tests, dependencies, and library-specific arguments without invoking a build.

Add tests that prove:

- Linux image version is defined once and composed for every standard Linux target;
- minizip Android resolves API 24 while zlib and another ordinary library resolve API 23;
- Windows generator and runtime expectation resolve centrally;
- unknown target, dependency cycle, duplicate stack member, invalid operation, and incomplete override fail compactly;
- graph order places zlib before minizip, zlib-ng before minizip-ng and libpng, and libpng before Skia;
- sqlite3 and SLJIT are members of `others`;
- stack membership does not create false dependency edges.

Do not migrate workflows in this milestone. Existing behavior remains the production path.

Acceptance is a deterministic JSON snapshot for representative targets and a passing resolver test suite.

Validation level: Level 2. Run focused unit tests, YAML parsing, changed-file header validation, and `git diff --check`.

### Milestone 3: Create one shared local and action execution path

Create or rename the shared executor to `scripts/build-native-target.sh` and make it accept:

    scripts/build-native-target.sh <library> <target> [--build-dir <path>] [--operation build] [--verbose]

It calls the resolver, prepares QEMU or Android environment when required, constructs CMake or custom build arguments, invokes one lower-level CMake executor, runs focused tests, installs, packages, and emits a compact JSON result with artifact paths and log paths.

Keep `scripts/build-cmake-multi.sh` as the low-level CMake sequence if its interface remains useful, but make `.github/actions/build-native-library/action.yml` call shared scripts rather than carry a duplicate here-document. Alternatively retire the action when workflows can call `build-native-target.sh` directly. Do not maintain two independent configure/build/install/package implementations.

Convert explicit zlib scripts to wrappers containing only `zlib` and the target. Add a validation command that rejects policy literals in explicit wrappers.

Migrate one representative CMake library in each special category before broad conversion:

- zlib for a dependency-free standard library;
- minizip for a dependency and Android API override;
- SLJIT for tests;
- libpng for a dependency with all major platforms;
- one Windows static-runtime verification path.

Acceptance is local and CI-equivalent execution using the same script path, unchanged archive names/layout, and no NDK/API/image/generator/runtime literal in migrated wrappers.

Validation level: Level 3 for the representative libraries. Run host-compatible builds, focused Docker or Android targets when available, artifact layout comparison, runtime verification, and one CMake consumer fixture.

### Milestone 4: Add dependency standard, scaffold, documentation, and skills

Adopt the proposed `AGENTS.md` and `.agent/PLANS.md` together so precedence and resume behavior are coherent. Add:

- `docs/DEPENDENCY_STANDARD.md`;
- `docs/CONSUMING_DEPOT_TOOLS.md`;
- `tools/new-native-dependency.py`;
- `.agents/skills/validate-headers/SKILL.md`;
- `.agents/skills/logical-commits/SKILL.md` and explicit-invocation metadata;
- `.agents/skills/add-native-dependency/SKILL.md`;
- a distributable `adopt-totalcross-depot-tools` consumer skill and reference notes.

Extend `tools/check-copyright.py` with focused `--paths` and `--staged` modes while preserving repository-wide default behavior. Add tests for path classification and no-op changed sets.

Complete the scaffold script with generated standard files, executable bits, dry-run, refusal to overwrite by default, `--check`, and tests. A scaffold remains intentionally incomplete until build-specific TODOs are filled; `--check` must fail when TODO markers remain.

Update the root README with short links to dependency onboarding and consumption documentation rather than copying both guides into the README.

Acceptance is a temporary scaffold fixture that creates the expected structure, rejects overwrite, preserves executable scripts, fails while TODOs remain, and passes after the fixture completes the required contract. Validate the consumer skill against a temporary CMake project using one published dependency and a pinned ref.

Validation level: Level 2 for documentation/skills and Level 3 for scaffold and consumer integration.

### Milestone 5: Replace build/release pairs with one workflow per library

For each library create `.github/workflows/<library>.yml` and remove the old pair only after equivalent dry-run validation. The workflow supports `workflow_dispatch` and `workflow_call` with an `operation` input whose allowed values are `build`, `release`, and `force-release`, defaulting to `build`.

Avoid copied target matrices. A planning job calls `scripts/native-build.py plan <library> --operation ... --format json` and exposes a compact matrix or platform-lane plan. Shared jobs use the central resolver and target executor.

`build` behavior:

- always builds selected published targets;
- uploads artifacts under unchanged names;
- runs validation appropriate to the library;
- never commits, tags, pushes, updates `deps.yml`, or creates a GitHub Release;
- emits artifact and log summaries.

The library workflow must expose at least:

- `status` (`built`, `existing-release`, `released`, or `forced-release`);
- `effective_release_tag` when applicable;
- `release_url` when applicable;
- a machine-readable artifact manifest or artifact name list.

Migrate libraries in families and commit after each reviewable family. Keep Skia separate until standard CMake libraries prove the workflow contract.

Acceptance is unchanged artifact identity and successful build-only runs for representative standard, dependency-consuming, tested, Apple-packaged, Windows, and custom-build libraries.

Validation level: Level 3 per migrated family, then Level 4 before deleting all old workflow pairs.

### Milestone 6: Implement individual release idempotence and force-release

Create shared release helpers, preferably in Python with focused tests:

    scripts/native-release.py inspect <library>
    scripts/native-release.py select-tag <library> --operation release|force-release
    scripts/native-release.py prepare-metadata <library> --effective-tag <tag>
    scripts/native-release.py verify-assets <library> --effective-tag <tag> --paths ...

Preserve the current suffix rule. Derive the exact behavior from existing release metadata logic and captured release examples rather than inventing a new naming convention. Add fixtures for a base release, existing `-rN` releases, gaps, draft releases, tags without releases, and concurrent-selection recheck.

`release` behavior:

1. Resolve the requested source version and normal effective tag.
2. Query GitHub for an existing non-draft release with that effective identity.
3. When it exists, skip every build and publication job, succeed, set `status=existing-release`, expose the existing URL, and write it to the job summary.
4. When it does not exist, build and validate artifacts.
5. Recheck release/tag existence under a per-library concurrency group immediately before metadata mutation.
6. Update `<library>/manifest.yml` and `deps.yml` with the exact effective release tag.
7. Commit the metadata with a Conventional Commit body describing the release.
8. Push the commit, create the tag on that commit, and publish the individual GitHub Release with verified assets.
9. Expose the new release URL.

`force-release` behavior:

1. Always build and validate.
2. Inspect existing tags/releases and select the next allowed suffix.
3. Recheck under concurrency before mutation.
4. Update manifest and `deps.yml`, commit, tag, and publish exactly as above.

The tag and release must point to the commit that already contains the effective values. Do not create a release and then commit the pin afterward.

Design partial-failure recovery:

- metadata commit pushed but tag absent;
- tag exists but release absent;
- draft release exists;
- release exists with missing assets;
- release exists while `deps.yml` points elsewhere;
- push succeeds but API response is lost.

Retries must detect and continue or fail with an explicit recovery instruction; they must not silently create another suffix unless `force-release` is requested.

Acceptance is a test repository or controlled dry-run harness proving existing-release short-circuit, metadata-before-tag ordering, tag/commit identity, next-suffix selection, and safe recovery diagnostics. Production publication requires explicit user authorization.

Validation level: Level 4 release gate.

### Milestone 7: Add selective graphics and others stack planning

Create explicit stack scripts:

    scripts/build-graphics-stack.sh [build|release|force-release]
    scripts/build-other-libraries-stack.sh [build|release|force-release]

The default is `build`. `force-release` is the canonical operation name; do not introduce a separate `force-rebuild` operation. If an old external caller already uses `force-rebuild`, add a temporary documented alias that normalizes to `force-release`, otherwise omit it.

Create stack workflows or reusable orchestration that call the same planner. Stack planning must:

- inspect every stack library's requested source version and effective release;
- in `build`, build all selected stack libraries without publishing;
- in `release`, mark already-published libraries as external and select only missing releases for build/publication;
- in `force-release`, select every stack library and assign new effective tags;
- compute true dependency order without treating stack membership as dependency;
- fetch an existing dependency release instead of rebuilding it;
- when a dependency and its consumer are both selected in the same run, build the dependency once and make its validated local artifact available to the consumer platform lane; publication remains topological;
- never rebuild a complete stack merely because one leaf library is missing a release;
- preserve individual artifact sets, metadata commits, tags, releases, and URLs.

Group standard builds by compatible platform lane so one runner can build multiple selected libraries. Use local install trees or workflow artifacts within the current run. Do not upload and redownload between steps in the same job.

Publication is coordinated per library in topological order. For each newly published library, create its own metadata commit and effective tag so that its release points to a commit containing its pin. After each release, later publication steps must use the updated repository revision. The coordinator must serialize metadata pushes while platform builds may remain parallel.

Acceptance scenarios include:

- all versions already released: no build jobs, all existing URLs reported;
- only libpng missing: fetch zlib-ng release, build/release libpng only, do not rebuild zlib-ng or unrelated graphics libraries;
- minizip and its zlib version both missing: build zlib once, make it available to minizip, publish zlib before minizip, create two individual metadata commits/tags/releases;
- one unrelated `others` library missing: build/release only that library;
- force-release graphics: rebuild every graphics member and publish each individually with new effective tags.

Validation level: Level 4 because stack selection and publication policy affect multiple releases.

### Milestone 8: Preserve Skia target parallelism while reusing platform lanes

Model Skia as long-running with `preserve_target_parallelism: true`. The planner must generate an explicit topology rather than treating Skia as one final serial library.

For standard platform lanes, build prerequisite non-Skia libraries first. Then:

- a matching Linux x86_64 lane may continue into Skia Linux x86_64;
- Linux ARMv7 and Linux AArch64 lanes may each continue into their matching Skia target when this preserves concurrency;
- the Android lane may continue into the matching Skia Android target;
- the Apple lane builds all non-Skia macOS, iOS, and iOS Simulator dependencies, then continues with Skia macOS while separate Skia iOS and iOS Simulator jobs run concurrently;
- a Windows lane may continue into at most one matching Skia target when other Windows Skia targets remain separate concurrent jobs;
- WebAssembly remains a separate job;
- no Skia target has a `needs` dependency on another unrelated Skia target.

Use planner tests that inspect the generated DAG and reject accidental Skia-to-Skia serialization. Compare the generated job graph with the baseline inventory.

Skia dependency resolution follows the same selective rule: use existing zlib-ng/libpng releases when available, or current-run validated artifacts when those dependencies are selected. Do not trigger libjpeg or libjpeg-turbo as dependencies unless Skia's actual build configuration begins consuming them; they remain graphics co-scheduled libraries.

Acceptance is a dry-run job graph showing the expected concurrent Skia targets and a representative build where platform-lane reuse does not change artifact names or target coverage.

Validation level: Level 4 for Skia operation family. Retain QEMU as the production ARMv7 path; cross-build replacement remains outside this plan unless separately approved.

### Milestone 9: Remove obsolete paths and finalize

After all representative and release-gate validations pass:

- remove old `build-<library>.yml` and `release-<library>.yml` files;
- remove obsolete stack workflows that only call reusable library workflows;
- remove unused metadata actions or scripts;
- remove policy literals from workflows and explicit target scripts;
- rename `.github/native-build-targets.yml` or remove it after `config/native-builds.yml` fully replaces it;
- update path filters to include central configuration, shared scripts, library files, and the single library workflow without broad unrelated triggers;
- update root README and repository documentation links;
- run a repository script that reports zero forbidden policy literals outside approved central/runtime files;
- archive the migration inventory and final workflow mapping.

Finalize the editorial report with measured runner counts, durations, release short-circuit behavior, artifact comparisons, and limitations. Do not claim time or cost improvements without comparable observed runs.

Acceptance is a repository with one workflow per library, two stack entry scripts, central operational configuration, no duplicated build/release pairs, validated individual release semantics, selective stack releases, and preserved Skia target parallelism.

## Surprises & Discoveries

- Observation: The existing target manifest already contains canonical-looking values but is not consumed by workflows or explicit scripts.
  Evidence: Android NDK/API, Linux images, Visual Studio generator, and runtime arguments remain repeated in current build workflows and zlib target wrappers.

- Observation: Reusable workflow calls do not reuse the caller's runner or local filesystem.
  Evidence: The current graphics and small-library stack workflows call library workflows whose jobs each define their own `runs-on` and checkout.

- Observation: Minizip already requires Android API 24 while most Android builds use API 23.
  Evidence: The current minizip Android CMake arguments use `android-24`; the next release must preserve this as an override.

- Observation: The Windows runtime policy already exists in a CMake module included before `project()` by standard wrappers.
  Evidence: `cmake/TotalCrossWindowsStaticRuntime.cmake` sets CMP0091 and `MultiThreaded`; repeated top-level flags should be removed only after nested upstream propagation is verified.

- Observation: The shared composite action and command-line script currently duplicate the same build sequence.
  Evidence: Both independently construct configure, build, CTest, install, package, and Docker execution commands.

Add only discoveries that materially change future work. Move resolved migration detail to the archive.

## Decision Log

- Decision: Keep Android API 23 as the global default for the next release and model minizip API 24 as a library target override.
  Rationale: A global API 24 move is possible but is not approved for the immediate release. Central override support removes duplicated literals without changing compatibility.
  Date: 2026-07-18

- Decision: Keep explicit target script names.
  Rationale: Discoverability matters for local reproduction. Wrappers remain tiny and delegate all policy and execution to shared scripts.
  Date: 2026-07-18

- Decision: Compose Linux image tags from central registry, target image name, and one platform image version.
  Rationale: A version update must require one edit while preserving target-specific image names and Skia overrides.
  Date: 2026-07-18

- Decision: Use `graphics` and `others` as stack names; include sqlite3 and SLJIT in `others`.
  Rationale: These libraries are unrelated and rarely updated, so co-scheduling reduces setup without introducing false dependency edges.
  Date: 2026-07-18

- Decision: Replace build/release workflow pairs with one operation-based workflow per library.
  Rationale: Build logic, target selection, artifact upload, release checks, and path filters should not be maintained twice.
  Date: 2026-07-18

- Decision: Use `build`, `release`, and `force-release`, with `build` as default.
  Rationale: The names clearly separate non-mutating validation, idempotent publication, and deliberate republishing. The later “force-rebuild” wording is interpreted as the already-requested `force-release` behavior.
  Date: 2026-07-18

- Decision: Update manifest and `deps.yml` before tagging every new release.
  Rationale: Consumers checking out the release tag must see the exact effective release pin represented by that tag and GitHub Release.
  Date: 2026-07-18

- Decision: Preserve one individual release and metadata commit per library during stack publication.
  Rationale: Stack execution is an optimization and dependency coordinator, not a new combined release identity.
  Date: 2026-07-18

- Decision: Preserve Skia target parallelism and allow only opportunistic runner reuse.
  Rationale: Skia build duration dominates setup savings. Reusing a lane is beneficial only when it does not serialize targets that can run concurrently.
  Date: 2026-07-18

- Decision: Existing dependency releases are fetched in normal stack release mode; current-run dependency artifacts may be reused locally when both dependency and consumer are selected.
  Rationale: This prevents unnecessary rebuilds while avoiding a forced publish/download round trip inside the same validated run. Publication still follows dependency order.
  Date: 2026-07-18

## Validation and Acceptance

Use quiet logging wrappers and record evidence paths. Do not paste full native or workflow logs into this plan.

### Configuration and graph

Run:

    python3 -m unittest discover -s scripts/tests -p 'test_native_build*.py'
    python3 scripts/native-build.py validate
    python3 scripts/native-build.py show zlib android-arm64 --format json
    python3 scripts/native-build.py show minizip android-arm64 --format json
    python3 scripts/native-build.py graph graphics --format mermaid

Accept when zlib resolves Android API 23, minizip resolves 24, Linux image tags share one version source, Windows policy resolves centrally, and the graph contains the expected edges without cycles.

### Explicit wrappers and shared executor

Run syntax checks over changed wrappers and one host-compatible build per representative family. Inspect scripts for forbidden literals through a maintained validator, not ad hoc repeated grep commands at every slice.

Accept when explicit scripts call one shared target executor, the action calls the same implementation, and artifact names/layout match the baseline.

### Individual workflows

Dispatch representative workflows in `build` mode and confirm no state-changing steps execute. Use release dry-run fixtures before production publication.

Accept when one workflow covers all three operations, build artifacts are unchanged, existing-release mode skips builds and reports a URL, and forced release selects the next legal suffix.

### Metadata and release identity

For every new release fixture or authorized production release, verify:

    git show <tag>:deps.yml
    git show <tag>:<library>/manifest.yml
    git rev-list -n 1 <tag>

Compare the tag commit with the release target commit and effective metadata. Accept only when they are identical and assets match the manifest.

### Stack selection

Test planner fixtures for all-existing, one missing leaf, missing dependency and consumer, unrelated missing library, and force-release-all cases. Inspect generated platform lanes and publication order.

Accept when normal release selects only missing releases, existing dependencies are fetched, current-run dependencies are built once, publications remain individual, and `deps.yml` advances in each release commit.

### Skia parallelism

Generate the job DAG and assert no unrelated Skia target depends on another Skia target. Run a controlled build or workflow dry run preserving target count and artifact identity.

Accept when macOS lane reuse still permits separate concurrent iOS and simulator jobs and equivalent concurrency exists for other target families.

### Final release gate

Run available platform matrices, package verification, Windows runtime checks, CMake consumer fixtures, release idempotence tests, and stack dry runs. Compare cold/warm or before/after workflow metrics only where comparable runs exist.

Record unavailable platforms and reasons. Do not block every earlier commit on the final matrix.

## Risks and Open Questions

- GitHub Actions cannot dynamically create arbitrary jobs after execution starts. The planner may need to expose bounded matrices or generated lane descriptors consumed by static reusable jobs. Resolve this without restoring copied per-library matrices.
- A single metadata branch receiving several release commits can race with unrelated main-branch changes. Use concurrency, rebase/fast-forward checks, and explicit failure rather than force-push.
- Stack builds that produce several libraries per platform need a reliable artifact manifest for later individual publication. Define one compact manifest schema before migration.
- Current release suffix behavior must be derived from existing helpers and releases. Do not assume all libraries start at the same `-rN` value.
- Some upstream CMake projects may ignore the top-level runtime module. Verify nested `/MT` propagation before removing explicit arguments.
- vcruntime is not a static CMake library. Its one-workflow operation contract may require a custom executor while remaining in the `others` stack.
- Skia publication may require diagnostics assets not shared by standard libraries. Keep custom artifact validation behind the common operation contract.
- Publishing multiple library releases in one stack run creates a sequence of commits. Define clear recovery when publication stops midway; completed releases remain valid and a retry replans only missing releases.

## Idempotence and Recovery

Configuration generation, graph inspection, build operations, scaffolding dry runs, and artifact verification must be safely repeatable.

`build` never changes Git or GitHub release state.

`release` is idempotent. When the exact effective release already exists and metadata is consistent, it returns the existing URL and succeeds. When partial state exists, it diagnoses and resumes only the missing safe step or stops with an explicit repair command.

`force-release` is deliberately non-idempotent in identity: each authorized run selects a new suffix. It is idempotent within a single concurrency-protected attempt and must not select another suffix merely because a network response was lost.

Do not use force-push, hard reset, global clean, or removal of unrelated caches. Before metadata commits, require a clean scoped index for release-owned files and preserve unrelated working-tree changes. Use a temporary worktree or controlled release branch when needed.

A failed stack run is resumed by rerunning `release`. The planner sees already-created releases, skips them, and selects only the missing remainder. Do not delete valid completed releases to recreate an all-or-nothing stack.

Keep old workflows available until replacement dry runs pass. Remove them in a separate logical commit so rollback can restore the prior entry points without reverting configuration and executor improvements.

## Outcomes & Retrospective

The analysis phase established that the repository has useful shared build primitives but not yet an operational central policy or same-runner stack architecture. The chosen design preserves explicit local commands, immediate Android compatibility, individual releases, and Skia target concurrency while removing duplicated toolchain and workflow policy.

Milestone 1 completed without changing build or release behavior. `scripts/inventory-native-build-orchestration.py` now captures the baseline from static repository files; at the recorded baseline it found 15 library manifests, 39 workflow files, and seven Skia jobs. The supporting state, evidence, archive, and editorial records are in place for Milestone 2 resumption. No native builds or remote workflow operations were needed or run.

Update this section at each completed milestone with actual behavior and evidence references. At completion, state which workflows were removed, how many policy literals remain, which release scenarios were proven, whether runner reuse reduced observed allocations or duration, and which platforms or production releases were not validated.

## Revision Note

This plan supersedes the unfinished runner-reuse and workflow-consolidation portions of the earlier release-optimization plan. It incorporates the shared native action and script work through `67cd3bc`, retains Android API 23 with a minizip override, replaces separate build/release workflows with one operation-based workflow per library, includes sqlite3 and SLJIT in the `others` stack, makes normal stack releases selective, and preserves Skia target parallelism.
