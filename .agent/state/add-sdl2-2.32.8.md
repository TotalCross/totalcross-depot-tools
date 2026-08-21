<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 ExecPlan state

Active milestone: Milestone 3 — fetch and strict CMake consumption.

Active slice: implement pin-aware atomic fetch, platform mapping, staged artifact
completeness checks, direct loading of upstream config metadata, and strict
imported-path verification.

Last logical commit: `90572fa build(sdl2): add reproducible static builds and packaging`.

Active paths:

- `sdl2/`
- `config/native-builds.yml`
- `.github/workflows/sdl2.yml`
- `.agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md`

Source contract: SDL `release-2.32.8` resolves to
`98d1f3a45aae568ccd6ed5fec179330f47d4d356` and uses the upstream Zlib license
from `LICENSE.txt`.

Next action: stage the preserved macOS archive through a local release transport,
prove repeat fetch reuse, configure/link the strict consumer, and prove incomplete
staging cannot fall back to a host SDL2 package.

Deferred validation: native builds and consumer checks belong to later
milestones. Publication, tags, GitHub Releases, and the `deps.yml` pin remain
explicitly gated.

Deliberate out-of-scope paths: all pre-existing untracked proposal, local cache,
log, and `__pycache__` paths shown by the initial status inspection.

Resume command:

    git status --short -- sdl2 config/native-builds.yml .github/workflows/sdl2.yml .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md .agent/state/add-sdl2-2.32.8.md
