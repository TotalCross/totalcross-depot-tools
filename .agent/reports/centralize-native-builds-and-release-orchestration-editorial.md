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

The requested compact baseline and resumption files now exist. No build,
release, workflow, or artifact contract was changed.

## What Changed

- Added `scripts/inventory-native-build-orchestration.py` for deterministic JSON
  and compact summary output.
- Added state, evidence, archive, and editorial support files for this ExecPlan.

## Decisions and Trade-offs

The inventory uses only the Python standard library and static repository files,
so it remains usable in the current environment without a YAML dependency. It
does not assert remote GitHub state; a later release milestone must do that.

## Unexpected Problems and Discoveries

The state file named by the plan did not exist at resumption. The plan's fresh
start protocol was applied and the missing file was created.

## Validation and Measurable Results

Python compilation and the focused inventory command passed. The baseline has
15 libraries, 39 workflows, and seven named Skia jobs. See the evidence JSONL
entry for the exact command and output digest.

## Useful Evidence and Examples

Run `python3 scripts/inventory-native-build-orchestration.py --format json` to
inspect the complete baseline; use `--format summary` for its compact counts.

## Limitations, Remaining Work, and Open Questions

Central configuration, resolver tests, executor migration, and workflow changes
are intentionally deferred to later milestones.

## Possible Article Angles

Treating existing CI topology and artifact names as an executable baseline makes
large release-orchestration refactors easier to review and resume.

## Suggested Narrative

Start with the duplicated policy problem, show the inventory as a compatibility
map, then introduce central configuration without changing production behavior.

## Claims Requiring Human Review

No production release or workflow-dispatch claim is made in this milestone.
