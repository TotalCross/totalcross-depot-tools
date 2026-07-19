<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Native dependency scaffold state

## Status

Final documentation and focused validation are complete pending the final
documentation commit.

## Completed commits

- abda645 feat(tools): add native dependency scaffold
- 53bf773 test(tools): cover dependency scaffold lifecycle

The first commit provides explicit commands, deterministic templates, the target
adapter, non-overwrite behavior, and read-only structural checks. The second
uses temporary directories to cover the creation and validation lifecycle.

## Scope preserved

Existing zlib, libpng, sqlite3, and Skia layouts were inspected but not changed.
The validator operates only on its requested dependency and no release, tag,
dependency pin, or platform build has run.

## Final validation

Run the documented unittest module, all three help commands, copyright and diff
checks. Platform builds, releases, and consumer CMake checks remain deliberately
deferred because no real dependency implementation replaces the scaffold.
