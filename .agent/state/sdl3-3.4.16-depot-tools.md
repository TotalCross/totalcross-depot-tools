<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL3 3.4.16 ExecPlan state

Active milestone: Milestone 1 complete; Milestone 2 is next.

Active slice: implement the reproducible static build and deterministic package.

Source contract: SDL `release-3.4.16` resolves to
`fa2c02bb6e21974a89ea9824bc53c9932abe5f9c` and uses the upstream Zlib license
from `LICENSE.txt`.

Active paths:

- `sdl3/`
- `config/native-builds.yml`
- `.github/workflows/sdl3.yml`
- `.agent/plans/sdl3-3.4.16-depot-tools-exec-plan.md`
- `.agent/state/sdl3-3.4.16-depot-tools.md`
- `.agent/evidence/sdl3-3.4.16-depot-tools.md`

Next action: complete the SDL3 wrapper and package implementation, then build a
host-compatible target twice and prove deterministic, relocatable static
consumption.

Publication remains explicitly gated. `deps.yml` is unchanged.
