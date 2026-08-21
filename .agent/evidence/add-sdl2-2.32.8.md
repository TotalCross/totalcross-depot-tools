<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 evidence

- 2026-08-21, source contract: `release-2.32.8` resolved to
  `98d1f3a45aae568ccd6ed5fec179330f47d4d356`; codeload archive SHA-256
  `be55f7015a5599faa869b20078de83df7e83c35585ee1c3ee203a0e58eefebbd`.
- 2026-08-21, Milestone 2 at `90572fa`: shared `macos-arm64` wrapper built 96
  archive entries; static library, upstream config exports, Zlib license, and
  `SDL_GetVersion` link/run passed. Repeated archive SHA-256 matched. Full build
  log: `.agent/logs/sdl2-macos-arm64-build/build-native-target.log`.
- 2026-08-21, runtime-policy correction at `af214f3`: fresh macOS build passed;
  repeated archive SHA-256
  `fef1b9b72cdc4f8062c5bc3e2c3a051b5e0ca023322ca5206644a833d0a29563`.
  Full log: `.agent/logs/sdl2-macos-arm64-build-m4/build-native-target.log`.
- 2026-08-21, Milestone 3 at `dee4140`: local checksum-pinned HTTP handoff
  downloaded once, second fetch reused the marker, strict consumer linked and
  ran, missing staging failed despite a valid SDL config on `CMAKE_PREFIX_PATH`,
  and auto-fetch without a release pin failed before network resolution.
- 2026-08-21, Milestone 4 at `28cdf4a`: native build plan returned seven exact
  targets; seven wrapper dry runs resolved central policy; release contract
  reported seven assets; 28 focused orchestration tests passed.
- 2026-08-21, Milestone 5 at `61d3f3e`: a freshly checksum-staged corrected
  macOS archive configured, linked, and ran the strict consumer. Dependency
  structure, shell syntax, central graph, seven-asset release contract, native
  policy literals, changed-file headers, scoped diff checks, and 28 orchestration
  tests passed. `deps.yml` remained unchanged.
- Limitation: this macOS host has no Docker, PowerShell, or MSVC. Linux x86_64,
  Linux ARMv7, Linux AArch64, Windows x86, Windows x64, Windows ARM64, and the
  Windows static-runtime verifier were not executed locally. No remote workflow
  was dispatched because no push or publication was authorized.
- Publication state: no GitHub Release, release tag, push, or `deps.yml` sdl2 pin
  was created.
