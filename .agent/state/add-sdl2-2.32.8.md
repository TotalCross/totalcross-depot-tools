<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 ExecPlan state

Active milestone: Milestone 4 — workflow and desktop matrix.

Active slice: delegate the sdl2 operation workflow to shared native-library
orchestration and validate the generated seven-target build plan, target commands,
available host builds, and platform policy checks without invoking publication.

Last logical commit: `af214f3 fix(sdl2): inherit central Windows runtime policy`.

Active paths:

- `sdl2/`
- `config/native-builds.yml`
- `.github/workflows/sdl2.yml`
- `.agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md`

Source contract: SDL `release-2.32.8` resolves to
`98d1f3a45aae568ccd6ed5fec179330f47d4d356` and uses the upstream Zlib license
from `LICENSE.txt`.

Next action: validate workflow delegation and build-mode planning, inspect all
seven resolved commands, run available Linux Docker targets if the local engine
is available, and record unavailable Windows CI validation explicitly.

Deferred validation: native builds and consumer checks belong to later
milestones. Publication, tags, GitHub Releases, and the `deps.yml` pin remain
explicitly gated.

Deliberate out-of-scope paths: all pre-existing untracked proposal, local cache,
log, and `__pycache__` paths shown by the initial status inspection.

Resume command:

    git status --short -- sdl2 config/native-builds.yml .github/workflows/sdl2.yml .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md .agent/state/add-sdl2-2.32.8.md
