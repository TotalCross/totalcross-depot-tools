<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 ExecPlan state

Active milestone: Milestone 2 — build and package SDL2.

Active slice: implement the immutable source archive, static/PIC external build,
upstream install metadata preservation, and deterministic packaging. Scaffold
TODOs intentionally remain in fetch, CMake consumption, workflow, and README.

Last logical commit: `fb75cb4 feat(sdl2): scaffold SDL2 2.32.8 dependency`.

Active paths:

- `sdl2/`
- `config/native-builds.yml`
- `.github/workflows/sdl2.yml`
- `.agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md`

Source contract: SDL `release-2.32.8` resolves to
`98d1f3a45aae568ccd6ed5fec179330f47d4d356` and uses the upstream Zlib license
from `LICENSE.txt`.

Next action: configure, build, install, and package `macos-arm64`; inspect the
archive and exported metadata, compile a direct installed-package smoke consumer,
then create the Milestone 2 logical commit.

Deferred validation: native builds and consumer checks belong to later
milestones. Publication, tags, GitHub Releases, and the `deps.yml` pin remain
explicitly gated.

Deliberate out-of-scope paths: all pre-existing untracked proposal, local cache,
log, and `__pycache__` paths shown by the initial status inspection.

Resume command:

    git status --short -- sdl2 config/native-builds.yml .github/workflows/sdl2.yml .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md .agent/state/add-sdl2-2.32.8.md
