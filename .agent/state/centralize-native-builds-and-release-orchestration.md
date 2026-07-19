<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — state

## Current position

- Active milestone: Milestone 5 — not started; stop before implementation.
- Current slice: awaiting authorization to replace build/release workflow pairs.
- Last pre-milestone revision: `056f44db05c69475f71011cb29b22ffc93b5bbdc`.
- Last logical commit: `f5c77cc feat(onboarding): complete dependency adoption contract`.

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

## Deferred validation

- Windows runtime verification, Android execution, and Docker/QEMU execution
  remain deferred because this host cannot provide those platform facilities.
  Dry-run tests cover their resolved arguments. No workflow dispatch, release
  dry run, or remote publication was run.

## Decisions and blockers

- The requested state file was absent at resumption, so Milestone 1 was treated
  as a fresh start as directed by `.agent/PLANS.md`.
- No blocker remains. The non-published zlib Android armv7 and macOS x86_64
  wrappers were removed under the published-target policy. Preserve unrelated
  untracked proposal directories and the SDL3 ExecPlan.

## Next action and resume command

Start Milestone 5 only when authorized by the user. Begin by reading this state
file, then inspect the library workflow family selected for the first migration.

Do not change workflow or release behavior as part of this completed onboarding
milestone.
