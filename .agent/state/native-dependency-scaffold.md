<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Native dependency scaffold state

## Active slice

Implement explicit `create` and `check` operations in
`tools/new-native-dependency.py`, using a separately documented target adapter.

## Context

The request requires commits, standard-library tests, no changes to existing
dependencies, and no releases or `deps.yml` updates. No active task-specific
state existed before this file.

## Inspected evidence

`zlib`, `libpng`, `sqlite3`, and `skia` show historical target and workflow
variation. The repository has no `config/native-builds.yml`. Their files must not
be changed to satisfy the new validator.

## Active paths

- `tools/new-native-dependency.py`
- `tools/native_dependency_targets.py`
- `tools/tests/test_new_native_dependency.py`
- `docs/DEPENDENCY_STANDARD.md`
- `AGENTS.md`
- `.agent/exec-plan-native-dependency-scaffold.md`

## Next action

Implement templates, CLI subcommands, and basic isolated smoke validation; then
commit the scaffold slice and record its result here.

## Deferred validation

No platform build, release operation, or consumer CMake build applies until a
real dependency replaces scaffold placeholders.
