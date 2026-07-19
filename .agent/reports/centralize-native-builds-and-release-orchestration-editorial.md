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
- Added the shared native target executor, wrapper validator, consumer fixture,
  and zlib published-target wrappers that delegate to the executor.
- Added focused/staged header-validation modes, scaffold dry-run and central
  target adaptation, onboarding links, and the distributable consumer skill.
- Added operation entry workflows for all 15 libraries, with a shared CMake
  planner/executor path, pinned dependency fetching, Apple packaging policy,
  and specialized VCRuntime/Skia adapters.

## Decisions and Trade-offs

The inventory uses only the Python standard library and static repository files,
so it remains usable in the current environment without a YAML dependency. It
does not assert remote GitHub state; a later release milestone must do that.

The operational resolver also uses only the Python standard library. It accepts
the intentionally small YAML subset used by the checked-in policy file, keeping
its behavior deterministic across the repository's supported local environments.

The CMake action and local target executor now share one lower-level execution
sequence. This preserves existing action inputs while making centrally resolved
local paths available for incremental wrapper migration.

The dependency standard, consumption guide, root guidance, and repository skills
were already tracked as a coherent earlier onboarding series. Milestone 4 kept
that newer material, connected the remaining mechanics, and avoided replacing
it with an older untracked proposal.

Milestone 5 keeps the old workflow pairs available while the operation contract
is introduced. This preserves existing release behavior until its dedicated
idempotence implementation and a later remote equivalence gate.

## Unexpected Problems and Discoveries

The state file named by the plan did not exist at resumption. The plan's fresh
start protocol was applied and the missing file was created.

## Validation and Measurable Results

Python compilation, the focused inventory command, resolver validation, and 12
resolver tests passed. The baseline has 15 libraries, 39 workflows, and seven
named Skia jobs. See the evidence JSONL entry for exact commands and digests.

Milestone 3 expanded the focused suite to 17 tests, validated ten zlib wrappers,
built and packaged four representative libraries on macOS arm64, and built a
temporary CMake consumer against generated zlib output.

Milestone 4 passed 15 scaffold lifecycle tests and focused header-validator
tests. A temporary consumer pinned to published `zlib-1.3.1-r3` fetched the
artifact, configured, built, linked, and ran through the documented CMake path.

Milestone 5 passed central configuration validation, 13 resolver tests, shell
syntax checks, dependency-fetch dry runs, operation planner checks, local YAML
parsing, focused SPDX validation, and whitespace checks. Remote workflow runs
were intentionally not dispatched.

## Useful Evidence and Examples

Run `python3 scripts/inventory-native-build-orchestration.py --format json` to
inspect the complete baseline; use `--format summary` for its compact counts.
Run `python3 scripts/native-build.py show minizip android-arm64 --format json`
to inspect an effective target policy without building it.
Run `scripts/build-native-target.sh zlib macos-arm64 --dry-run` to inspect the
shared execution command without creating a build directory.
Run `python3 tools/new-native-dependency.py create ... --dry-run` to review a
new dependency scaffold before it writes files.

## Limitations, Remaining Work, and Open Questions

Executor migration and workflow changes are intentionally deferred to later
milestones.

Release inputs on the new workflows currently use build-only behavior. The next
milestone must implement existing-release detection, force-release suffix
selection, metadata-before-tag ordering, and publication recovery before old
release workflows can be retired.

Windows runtime verification, Android execution, and Docker/QEMU execution
remain host-dependent validations for a later platform-capable checkpoint.

The temporary consumer validates zlib only; each adopted dependency still needs
its own published-target validation in the receiving repository.

## Possible Article Angles

Treating existing CI topology and artifact names as an executable baseline makes
large release-orchestration refactors easier to review and resume.

## Suggested Narrative

Start with the duplicated policy problem, show the inventory as a compatibility
map, then introduce central configuration without changing production behavior.

## Claims Requiring Human Review

No production release or workflow-dispatch claim is made in this milestone.
