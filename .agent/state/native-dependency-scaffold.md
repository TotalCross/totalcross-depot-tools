<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Native dependency scaffold state

## Status

Implementation and focused validation are complete.

## Completed commits

- abda645 feat(tools): add native dependency scaffold
- 53bf773 test(tools): cover dependency scaffold lifecycle
- 08896f5 docs(dependencies): document scaffold workflow
- d4b897a fix(tools): validate complete scaffold markers

The first commit provides explicit commands, deterministic templates, the target
adapter, non-overwrite behavior, and read-only structural checks. The second
uses temporary directories to cover the creation and validation lifecycle.

## Scope preserved

Existing zlib, libpng, sqlite3, and Skia layouts were inspected but not changed.
The validator operates only on its requested dependency and no release, tag,
dependency pin, or platform build has run.

## Final validation

The focused lifecycle tests now also cover wrapper SPDX headers, workflow
placeholders, and nested generated directories. Platform builds, releases, and
consumer CMake checks remain deliberately deferred because no real dependency
implementation replaces the scaffold.
