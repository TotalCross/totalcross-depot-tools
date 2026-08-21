<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 ExecPlan state

Active milestone: Publication workflow retry pending.

Active slice: the Linux packaging and Windows license-path corrections are
complete. The remote release workflow must be retried from a revision containing
the fixes; local publication state remains unchanged.

Last implementation commit:
`2695085 fix(sdl2): remove platform packaging assumptions`.

Active paths:

- `sdl2/`
- `config/native-builds.yml`
- `.github/workflows/sdl2.yml`
- `.agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md`

Source contract: SDL `release-2.32.8` resolves to
`98d1f3a45aae568ccd6ed5fec179330f47d4d356` and uses the upstream Zlib license
from `LICENSE.txt`.

Next action: push or otherwise make `2695085` available to the workflow branch,
then retry `operation=release`. Review all seven platform builds and the Windows
`/MT` verification before accepting publication metadata, tags, or releases.

Deferred validation: Linux Docker and Windows MSVC execution are unavailable on
this host and require CI before publication. Publication, tags, GitHub Releases,
the final `deps.yml` pin, and default-pin auto-fetch remain explicitly gated.

Deliberate out-of-scope paths: all pre-existing untracked proposal, local cache,
log, and `__pycache__` paths shown by the initial status inspection.

Resume command:

    git status --short -- sdl2 config/native-builds.yml .github/workflows/sdl2.yml .agent/plans/sdl2-2.32.8-depot-tools-exec-plan.md .agent/state/add-sdl2-2.32.8.md
