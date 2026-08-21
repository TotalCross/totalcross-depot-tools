<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 ExecPlan state

Active milestone: Milestone 1 — scaffold and lock the contract.

Active slice: generated the standard `sdl2` skeleton and registered the pinned
source and seven desktop targets. Scaffold TODOs intentionally remain for later
milestones.

Last logical commit: none yet.

Active paths:

- `sdl2/`
- `config/native-builds.yml`
- `.github/workflows/sdl2.yml`
- `.agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md`

Source contract: SDL `release-2.32.8` resolves to
`98d1f3a45aae568ccd6ed5fec179330f47d4d356` and uses the upstream Zlib license
from `LICENSE.txt`.

Next action: validate the scaffold/central metadata and create the Milestone 1
logical commit, then implement the external static build and deterministic
package script.

Deferred validation: native builds and consumer checks belong to later
milestones. Publication, tags, GitHub Releases, and the `deps.yml` pin remain
explicitly gated.

Deliberate out-of-scope paths: all pre-existing untracked proposal, local cache,
log, and `__pycache__` paths shown by the initial status inspection.

Resume command:

    git status --short -- sdl2 config/native-builds.yml .github/workflows/sdl2.yml .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md .agent/state/add-sdl2-2.32.8.md
