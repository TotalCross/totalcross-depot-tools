<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — editorial report

## Editorial Summary

Milestone 1 established a repeatable baseline before central policy or workflow
behavior changes. The inventory records existing artifact contracts, workflow
topology, release helpers, and duplicated policy locations.

## Original Plan versus Actual Outcome

The requested compact baseline and resumption files now exist. Milestone 2 also
added central policy resolution without changing a build, release, workflow, or
artifact contract.

## What Changed

- Added `scripts/inventory-native-build-orchestration.py` for deterministic JSON
  and compact summary output.
- Added state, evidence, archive, and editorial support files for this ExecPlan.
- Added `config/native-builds.yml`, `scripts/native-build.py`, and 12 focused
  resolver tests.

## Decisions and Trade-offs

The inventory uses only the Python standard library and static repository files,
so it remains usable in the current environment without a YAML dependency. It
does not assert remote GitHub state; a later release milestone must do that.

The operational resolver also uses only the Python standard library. It accepts
the intentionally small YAML subset used by the checked-in policy file, keeping
its behavior deterministic across the repository's supported local environments.

## Unexpected Problems and Discoveries

The state file named by the plan did not exist at resumption. The plan's fresh
start protocol was applied and the missing file was created.

## Validation and Measurable Results

Python compilation, the focused inventory command, resolver validation, and 12
resolver tests passed. The baseline has 15 libraries, 39 workflows, and seven
named Skia jobs. See the evidence JSONL entry for exact commands and digests.

## Useful Evidence and Examples

Run `python3 scripts/inventory-native-build-orchestration.py --format json` to
inspect the complete baseline; use `--format summary` for its compact counts.
Run `python3 scripts/native-build.py show minizip android-arm64 --format json`
to inspect an effective target policy without building it.

## Limitations, Remaining Work, and Open Questions

Executor migration and workflow changes are intentionally deferred to later
milestones.

## Possible Article Angles

Treating existing CI topology and artifact names as an executable baseline makes
large release-orchestration refactors easier to review and resume.

## Suggested Narrative

Start with the duplicated policy problem, show the inventory as a compatibility
map, then introduce central configuration without changing production behavior.

## Claims Requiring Human Review

No production release or workflow-dispatch claim is made in this milestone.
