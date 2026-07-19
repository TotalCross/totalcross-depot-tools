<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — state

## Current position

- Active milestone: Milestone 2 — not started; stop before implementation.
- Current slice: awaiting authorization to add central configuration and resolver.
- Last pre-milestone revision: `6c911bdb405d6533f63bafd8801eaa2150c45dcf`.
- Last logical commit: `689946e chore(orchestration): capture native build baseline`.

## Active paths

- `.agent/exec-plan-centralize-native-builds-and-release-orchestration.md`
- `.agent/evidence/centralize-native-builds-and-release-orchestration.jsonl`
- `.agent/archive/centralize-native-builds-and-release-orchestration-history.md`
- `.agent/reports/centralize-native-builds-and-release-orchestration-editorial.md`
- `scripts/inventory-native-build-orchestration.py`

## Completed work

- Added a deterministic JSON inventory command for current workflow contracts,
  manifest archives, policy-literal locations, release helpers, stack topology,
  and Skia job parallelism.
- Captured the baseline summary and JSON digest in the evidence log.
- Added the state, archive, and editorial records needed for safe continuation.

## Focused validation

- `python3 -m py_compile scripts/inventory-native-build-orchestration.py` — passed.
- `python3 scripts/inventory-native-build-orchestration.py --format summary` — passed:
  15 libraries, 39 workflows, and seven named Skia jobs.
- `git diff --check` — passed before the final documentation updates; rerun with
  changed-file header validation before the milestone commit.

## Deferred validation

- No native builds, workflow dispatches, release dry runs, or consumer fixtures
  were run: they are outside Milestone 1 and would not validate this inventory.

## Decisions and blockers

- The requested state file was absent at resumption, so Milestone 1 was treated
  as a fresh start as directed by `.agent/PLANS.md`.
- No blocker remains. Preserve unrelated untracked proposal directories and the
  SDL3 ExecPlan.

## Next action and resume command

Start Milestone 2 only when authorized by the user. Begin by reading this state
file, then run:

    python3 scripts/inventory-native-build-orchestration.py --format summary
