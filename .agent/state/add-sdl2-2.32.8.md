<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 ExecPlan state

Active milestone: Post-onboarding build-planner correction.

Active slice: allow build-only stack planning to use manifest identity for an
unpublished dependency while preserving `deps.yml` as mandatory release
metadata.

Last implementation commit:
`61d3f3e docs(sdl2): document usage and finalize onboarding`.

Active paths:

- `sdl2/`
- `config/native-builds.yml`
- `.github/workflows/sdl2.yml`
- `.agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md`

Source contract: SDL `release-2.32.8` resolves to
`98d1f3a45aae568ccd6ed5fec179330f47d4d356` and uses the upstream Zlib license
from `LICENSE.txt`.

Next action: reproduce the failing `others build` plan, validate the focused
planner tests, commit the correction, then return to the publication gate.

Deferred validation: Linux Docker and Windows MSVC execution are unavailable on
this host and require CI before publication. Publication, tags, GitHub Releases,
the final `deps.yml` pin, and default-pin auto-fetch remain explicitly gated.

Deliberate out-of-scope paths: all pre-existing untracked proposal, local cache,
log, and `__pycache__` paths shown by the initial status inspection.

Resume command:

    git status --short -- sdl2 config/native-builds.yml .github/workflows/sdl2.yml .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md .agent/state/add-sdl2-2.32.8.md
