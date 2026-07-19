<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Implement native dependency scaffold and structural validator

This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`.

## Purpose / Big Picture

Developers can create a deterministic, intentionally incomplete CMake dependency
layout with `tools/new-native-dependency.py create`, then use `check` to identify
every structural issue before a real build, package, consumer, and workflow
validation. The command will work on one named dependency or path; it will never
scan or modify all existing libraries.

## Working Set and Resume Protocol

Read `.agent/state/native-dependency-scaffold.md` first. The implementation is
`tools/new-native-dependency.py`; temporary target policy is
`tools/native_dependency_targets.py`; tests are
`tools/tests/test_new_native_dependency.py`. `docs/DEPENDENCY_STANDARD.md` and
`AGENTS.md` describe user-facing operation. Full test output is retained in
`/tmp/native-dependency-scaffold-tests.log` when needed.

## Progress

- [x] (2026-07-19) Inspected the request and representative zlib, libpng,
  sqlite3, and Skia layouts without modifying them.
- [ ] Implement explicit create/check commands and the isolated target adapter.
- [ ] Add lifecycle tests and run focused validation.
- [ ] Document the final interface and commit the completed slices.

## Current Architecture and Scope

Existing dependencies use different historical target wrappers and split build
and release workflows. The new tool must not make them pass or migrate them.
There is no `config/native-builds.yml` yet, so the adapter owns only accepted
target names and canonical archive suffixes until central configuration arrives.

## Plan of Work

First provide the creation interface, deterministic templates, non-overwrite
guard, and target adapter. Next implement manifest parsing and structural checks
for generated layouts. Then add standard-library temporary-directory tests for
the complete lifecycle. Finally update documentation and agent orientation,
rerun focused checks, and report deferred platform builds.

## Surprises & Discoveries

- Existing zlib, libpng, sqlite3, and Skia layouts predate the intended common
  contract; a repository-wide check would produce expected migration failures.

## Decision Log

- Decision: keep target mappings in a dedicated Python module.
  Rationale: it is a replaceable bridge to future `config/native-builds.yml` and
  prevents templates and validation from duplicating target policy.
  Date: 2026-07-19.

## Validation and Acceptance

Implementation and functional-commit validation consists of standard-library
unit tests, CLI help, an isolated create/check lifecycle, copyright validation,
and diff checks. No network, releases, dependency pin changes, or full platform
builds are in scope.

## Risks and Open Questions

The validator parses the constrained manifest format emitted by the scaffold,
not arbitrary YAML extensions. Existing dependency migration and replacing the
adapter with central build configuration remain future work.

## Idempotence and Recovery

`create` refuses an existing dependency directory or workflow and has no force
mode. `check` is read-only. Tests use temporary directories. Existing untracked
plans, proposals, and unrelated files remain untouched.

## Outcomes & Retrospective

Pending implementation and focused validation.

## Revision Note

Created for this multi-commit tool implementation.
