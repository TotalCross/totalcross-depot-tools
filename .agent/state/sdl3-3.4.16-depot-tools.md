<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL3 3.4.16 ExecPlan state

Active milestone: Milestone 3 complete; Milestone 4 is next.

Active slice: finalize the current one-workflow operation and validate its seven lanes.

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

Next action: replace the scaffold workflow with the shared native-library
operation and run focused unpublished-member and seven-lane validations.

Milestone 2 host proof: Linux x86_64 configured and built with required X11,
Wayland, KMSDRM, dummy, offscreen, Vulkan, OpenGL, and OpenGL ES backends. Two
packages had identical SHA-256
`918025d233f719fb1969f5f7d02405d7e39262b58a2e06e24b8521e8809bccbe`, and
both `SDL3::SDL3` and `SDL3::SDL3-static` consumers linked and ran.

Publication remains explicitly gated. `deps.yml` is unchanged.
