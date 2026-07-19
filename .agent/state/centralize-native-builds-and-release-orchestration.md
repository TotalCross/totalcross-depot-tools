<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — state

## Current position

- Active milestone: Milestone 3 — not started; stop before implementation.
- Current slice: awaiting authorization to create the shared local/action executor.
- Last pre-milestone revision: `3758cf3ed41e7c2dc77e72c7e216e3035e28526e`.
- Last logical commit: `41ff894 feat(native-build): add central policy resolver`.

## Active paths

- `.agent/exec-plan-centralize-native-builds-and-release-orchestration.md`
- `.agent/evidence/centralize-native-builds-and-release-orchestration.jsonl`
- `.agent/archive/centralize-native-builds-and-release-orchestration-history.md`
- `.agent/reports/centralize-native-builds-and-release-orchestration-editorial.md`
- `config/native-builds.yml`
- `scripts/native-build.py`
- `scripts/tests/test_native_build.py`

## Completed work

- Added a deterministic JSON inventory command for current workflow contracts,
  manifest archives, policy-literal locations, release helpers, stack topology,
  and Skia job parallelism.
- Captured the baseline summary and JSON digest in the evidence log.
- Added the state, archive, and editorial records needed for safe continuation.
- Added the central platform, target, library, dependency, and stack policy.
- Added a standard-library resolver with inspection and planning commands plus
  12 focused tests. Existing workflows and wrappers remain unchanged.

## Focused validation

- `python3 -m py_compile scripts/inventory-native-build-orchestration.py` — passed.
- `python3 scripts/inventory-native-build-orchestration.py --format summary` — passed:
  15 libraries, 39 workflows, and seven named Skia jobs.
- `git diff --check` — passed before the final documentation updates; rerun with
  changed-file header validation before the milestone commit.
- `python3 -m unittest discover -s scripts/tests -p 'test_native_build*.py'` —
  passed (12 tests).
- `python3 scripts/native-build.py validate` — passed.

## Deferred validation

- No native builds, workflow dispatches, release dry runs, or consumer fixtures
  were run: they are outside Milestones 1–2 and would not validate policy-only
  configuration resolution.

## Decisions and blockers

- The requested state file was absent at resumption, so Milestone 1 was treated
  as a fresh start as directed by `.agent/PLANS.md`.
- No blocker remains. Preserve unrelated untracked proposal directories and the
  SDL3 ExecPlan.

## Next action and resume command

Start Milestone 3 only when authorized by the user. Begin by reading this state
file, then run:

    python3 scripts/native-build.py show zlib linux-x86_64 --format json
