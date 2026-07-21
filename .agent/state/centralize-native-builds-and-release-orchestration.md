<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — state

## Current position

- Active milestone: complete.
- Current slice: Milestone 9 removed obsolete workflows and release helpers,
  confirmed the final Skia build-equivalence matrix, and validated idempotent
  remote release short-circuiting without a publication.
- Last pre-milestone revision: `1e49272`.
- Last logical commit: `8344852 test(orchestration): enforce centralized native
  policy`.

## Active paths

- `.agent/exec-plan-centralize-native-builds-and-release-orchestration.md`
- `.agent/evidence/centralize-native-builds-and-release-orchestration.jsonl`
- `.agent/archive/centralize-native-builds-and-release-orchestration-history.md`
- `.agent/reports/centralize-native-builds-and-release-orchestration-editorial.md`
- `config/native-builds.yml`
- `scripts/native-build.py`
- `scripts/tests/test_native_build.py`
- `scripts/build-native-target.sh`
- `scripts/validate-native-wrappers.py`
- `scripts/tests/test_native_build_target.py`
- `.github/actions/build-native-library/action.yml`
- `zlib/scripts/build-*.sh`
- `docs/DEPENDENCY_STANDARD.md`
- `docs/CONSUMING_DEPOT_TOOLS.md`
- `tools/new-native-dependency.py`
- `consumer-skill/adopt-totalcross-depot-tools/`
- `.github/workflows/native-library-operation.yml`
- `.github/workflows/<library>.yml`
- `scripts/fetch-native-dependencies.sh`
- `scripts/package-native-ios-xcframework.sh`
- `scripts/native-release.py`
- `scripts/tests/test_native_release.py`
- `.github/actions/publish-native-release/action.yml`
- `scripts/native-stack.py`
- `scripts/build-graphics-stack.sh`
- `scripts/build-other-libraries-stack.sh`
- `scripts/tests/test_native_stack.py`
- `.github/workflows/native-stack-plan.yml`
- `.github/workflows/graphics-stack.yml`
- `.github/workflows/others-stack.yml`

## Completed work

- Added a deterministic JSON inventory command for current workflow contracts,
  manifest archives, policy-literal locations, release helpers, stack topology,
  and Skia job parallelism.
- Captured the baseline summary and JSON digest in the evidence log.
- Added the state, archive, and editorial records needed for safe continuation.
- Added the central platform, target, library, dependency, and stack policy.
- Added a standard-library resolver with inspection and planning commands plus
  12 focused tests. Existing workflows remain the production path.
- Added one shared CMake target path, action delegation to the low-level CMake
  sequence, zlib published-target wrappers, and 17 executor-focused tests.
- Completed the onboarding contract with central scaffold targets, dry-run,
  focused header validation, concise README links, and consumer skill package.
- Added operation-based entry workflows for all 15 libraries. The 13 CMake
  libraries share planner-driven target matrices, pinned dependency fetching,
  central execution, Windows validation, unchanged artifact names, and Apple
  XCFramework packaging. VCRuntime and Skia expose the same inputs and outputs
  while preserving their specialized build implementations.
- Added shared release inspection, force-tag selection, metadata preparation,
  asset verification, recovery diagnostics, and per-library publication guards.
- Added selective graphics/others planning with external/local dependency
  handoff, compatible target lanes, and true topological publication order.
- Added an explicit Skia topology to graphics planning. It retains all 11
  target nodes independently, allows only eligible lane continuations, keeps
  WebAssembly separate, and validates against the captured job-family baseline.
- Prepared Docker image version `v2.0.2` for manual publication. The Skia x86_64
  and AArch64 image now includes Fontconfig headers, and the ARMv7 image includes
  Fontconfig headers and Python 3. The workflow preserves the NDK path exported
  by the shared Android setup action.
- Normalized Python-derived CRLF shell values on Windows and mapped repository
  dependency directories to Docker's `/sources` mount for shared CMake builds.

## Focused validation

- `python3 -m py_compile scripts/inventory-native-build-orchestration.py` — passed.
- `python3 scripts/inventory-native-build-orchestration.py --format summary` — passed:
  15 libraries, 39 workflows, and seven named Skia jobs.
- `git diff --check` — passed before the final documentation updates; rerun with
  changed-file header validation before the milestone commit.
- `python3 -m unittest discover -s scripts/tests -p 'test_native_build*.py'` —
  passed (12 tests).
- `python3 scripts/native-build.py validate` — passed.
- `python3 scripts/validate-native-wrappers.py` — passed (10 wrappers).
- Temporary macOS-arm64 builds for zlib, minizip, SLJIT, and libpng — passed,
  with expected archive layouts; a zlib CMake consumer fixture configured,
  built, linked, and ran.
- `python3 tools/test-check-copyright.py` — passed.
- `python3 -m unittest tools.tests.test_new_native_dependency` — passed (15
  tests), including dry-run, overwrite refusal, executable bits, and TODO checks.
- A temporary consumer pinned to published `zlib-1.3.1-r3` fetched its macOS
  arm64 artifact and configured, built, linked, and ran through `FindZlib.cmake`.
- `python3 scripts/native-build.py validate` and the 13 focused resolver tests
  passed after adding the Apple packaging policy.
- Shell syntax checks, dependency-fetch dry runs, operation planner checks for
  build/release/force-release, YAML parsing for all 16 new workflows, changed
  file SPDX validation, and staged whitespace checks passed.
- `python3 -m unittest discover -s scripts/tests -p 'test_native_*.py'` —
  passed (27 tests), including release fixtures for suffix gaps, existing and
  draft releases, tag-only states, metadata recovery, and asset verification.
- The same focused suite passed with 34 tests after stack planning, including
  all-existing, one-missing leaf, local dependency handoff, unrelated others,
  force-release, lane grouping, and recovery plans.
- The focused stack suite passed with nine tests after Skia topology checks.
  A controlled graphics plan emitted 11 independent Skia targets and the seven
  baseline workflow job families.
- Remote Skia run `29868514126` at `e660585` has passed Android, all three
  Linux targets, Apple, WebAssembly, and all three Windows targets. Windows
  static-library steps completed in about 7m01 (x86), 7m21 (x64), and 15m50
  (arm64), with the junction-based SDK compatibility layout accepted remotely.
- `vcruntime.yml` release run `29871061155` passed with `existing-release` for
  `vcruntime-14`; its build and publish jobs were skipped. The prior run
  `29870981832` exposed and validated the corrective `GH_TOKEN` environment
  requirement in the specialized planners.
- The final inventory reports 15 libraries and 27 workflows. It retains only
  the specialized reusable Skia/VCRuntime implementation workflows alongside
  their single operation entry points.

## Deferred validation

- No new native release, tag, or release metadata was published. The remote
  release gate covers the safe existing-release short circuit for VCRuntime;
  force-release and new-release publication remain deliberately unexercised.
- Stack workflows were validated with deterministic local planner scenarios but
  were not remotely dispatched. Their normal release behavior remains subject
  to the same per-library publication safeguards.
- CMake-library remote builds were representative (VCRuntime, zlib, minizip,
  and SLJIT) rather than a fresh 15-library platform matrix. The full available
  Skia matrix exercised Windows, Android, Docker/QEMU Linux, Apple, and web.

## Decisions and blockers

- The requested state file was absent at resumption, so Milestone 1 was treated
  as a fresh start as directed by `.agent/PLANS.md`.
- No blocker remains. The non-published zlib Android armv7 and macOS x86_64
  wrappers were removed under the published-target policy. Preserve unrelated
  untracked proposal directories and the SDL3 ExecPlan.
- macOS runners use Bash 3, which lacks `mapfile`; the shared Apple helpers use
  portable read loops instead.
- Eight inherited manifests have a release field older than their `deps.yml`
  pin: libjpeg, libjpeg-turbo, mbedtls, minizip, minizip-ng, sqlite3, zlib, and
  zlib-ng. The new helper reports this as `metadata_mismatch` and requires a
  deliberate recovery rather than silently selecting a new suffix.
- On 2026-07-21, build-only workflow dispatches on `main` validated VCRuntime
  successfully but failed zlib, minizip, and SLJIT. Windows invocations of
  `scripts/fetch-native-dependencies.sh` preserve a carriage return from Python
  `github-output`, causing an empty/CR-prefixed dependency name and an attempted
  `/fetch.sh`. Linux minizip passes a host dependency directory to CMake inside
  Docker, where the checkout is mounted at `/sources`; zlib is fetched correctly
  but is then invisible to the container. Commit `5d4b232` corrects both local
  executor defects; remote build-only reruns must verify them before Milestone 9
  may remove legacy workflows.
- The Skia run `29852139910` completed with Android and Linux failures, while
  Apple, WebAssembly, and all Windows targets passed. The new `skia.yml`
  adapter invokes `build-skia.yml` directly, so the failing build environment
  is the legacy workflow's environment rather than a change introduced by the
  operation wrapper. Compared with the last successful legacy run
  `29612356263` at `3f23d8d`, the current legacy workflow changed its Linux
  images from `totalcross/linux-amd64:v1.0.7` to v2.0.1 minimal images. Those
  images omit Fontconfig development headers (breaking x86_64 and AArch64) and
  Python 3 in the ARMv7 image (breaking GN generation). The Android migration
  from `sdkmanager` to `setup-android-native` exposes a valid NDK through
  `ANDROID_NDK_HOME`, but the Skia build step overwrites `NDK_BUNDLE` from an
  unsuitable `ANDROID_HOME` value, yielding `/ndk/28.2.13676358` and a missing
  sysroot. Commit `3de6fa6` removes that override and prepares the required
  `v2.0.2` images. These are separate from the generic CMake executor defects.
- A subsequent build-only Skia run (`29855312320`) confirmed the shared-executor
  fixes: zlib, minizip, and SLJIT passed. Its ARMv7 Skia lane failed because the
  refactored workflow attempted to run the AMD64 `depot_tools` GN binary inside
  the ARMv7 container. Commit `8c679bc` now generates the ARMv7 Ninja files in
  `skia-linux-amd64:v2.0.2` and retains QEMU plus the ARMv7 image for compilation.
- The same run exposed missing `EGL/egl.h` on the other Linux Skia targets.
  Commit `ad9b2eb` advances the images and central references to `v2.0.3` and
  adds `libegl1-mesa-dev` to both Skia Linux build images. The v2.0.3 images
  must be manually published before the next Skia build-only rerun.
- Windows x64 logs showed that the 802-task Ninja build itself took about 18
  seconds of an 11-minute-59-second static-library step; nearly all preceding
  time was recursive Windows SDK copying in `create_windows_sdk_compat`.
  Commit `5571475` replaces those copies with NTFS directory junctions for the
  SDK layout while retaining a real `bin` directory for `SetEnv.cmd`. The local
  fallback test passes; a Windows runner must measure the actual improvement.
- The next Linux Skia rerun progressed past EGL but failed on `GLES2/gl2.h`.
  Commit `c1649dc` advances the shared image version to `v2.0.4` and adds
  `libgles2-mesa-dev` to both the Skia AMD64 and ARMv7 Linux images. All four
  required `v2.0.4` Docker images were subsequently confirmed published.
- Commit `ca7702d` replaces mutable-looking `actions/cache` ccache entries with
  restore/save snapshots. A completed snapshot for the current revision is
  preferred, prior completed snapshots are reusable across revisions, and
  failure or cancellation saves a unique partial snapshot as a fallback. Ccache
  retains per-object input validation. Cancellation persistence is best-effort
  because GitHub may terminate the runner before the save step starts.
- Commit `73e1f68` splits source preparation into Linux, Windows, and macOS
  jobs. Windows and Apple target builds now restore their platform archive
  before fetching native `depot_tools`; Apple targets run as a parallel matrix,
  followed by a dedicated XCFramework and development-header packaging job.
- Windows preparation then failed because Git for Windows does not provide
  `shasum`. Commit `922c140` derives all source archive cache keys with the
  portable `git hash-object --stdin` command instead.
- Windows target jobs then failed to extract source-tree symbolic links from
  the cached archive. Commit `956d7f4` dereferences links while producing the
  Windows archive and bumps the source archive format to invalidate the
  immutable incompatible cache.
- Apple builds emitted non-fatal `IS NOT TOP-LEVEL GIT DIRECTORY` messages
  because they reran `git-sync-deps` after restoring a synchronized archive
  without `.git` directories. Commit `18841cd` sets `SKIA_SKIP_DEPS_SYNC=1`
  for the Apple target matrix, matching the other archive-consuming lanes.
- The same restored-archive warnings appeared in Windows target builds. Commit
  `3f9ac69` also sets `SKIA_SKIP_DEPS_SYNC=1` for the Windows matrix.
- Current GitHub CLI versions do not expose `url` or `assets` from `gh release
  list`. Commit `cfbef66` changes `scripts/native-release.py` to the paginated
  Releases API and validates its response contract. The specialized Skia and
  VCRuntime planners additionally need `GH_TOKEN`; commit `30b2d9d` provides
  it and run `29871061155` verifies the existing-release path.

## Next action and resume command

Milestone complete. Before a production release, deliberately dispatch a
library with a new approved effective tag and verify metadata-before-tag
publication, then exercise the selected stack release path.
