<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — state

## Current position

- Active milestone: Milestone 8 — not started; stop before implementation.
- Current slice: selective stack planning is available; Skia lane topology is
  deferred.
- Last pre-milestone revision: `cfccd78`.
- Last logical commit: `698d3c9 feat(stacks): add selective native stack planning`.

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

## Deferred validation

- Windows runtime verification, Android execution, and Docker/QEMU execution
  remain deferred because this host cannot provide those platform facilities.
  Dry-run tests cover their resolved arguments. No workflow dispatch, remote
  build, release dry run, or remote publication was run.
- Legacy `build-*.yml`/`release-*.yml` workflows remain until the planned
  equivalent remote validation and later obsolete-path removal gate. The new
  workflows now contain idempotence and publication logic, but no remote
  workflow, tag, push, or release has been executed.
- Stack workflows expose the shared plan; no remote lane execution or
  publication was dispatched.

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

## Next action and resume command

Start Milestone 8 only when authorized by the user. Begin by reading this state
file, then inspect the existing Skia topology and new lane plan before adding
any platform-lane reuse.

Do not dispatch remote workflows, remove legacy paths, or change Skia target
parallelism as part of the completed Milestone 7 checkpoint.
