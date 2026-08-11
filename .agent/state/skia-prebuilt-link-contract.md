<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Skia prebuilt link contract execution state

Active milestone: Milestone 6 complete; awaiting authorized CI/release gate.

Active slice: none. Implementation, local validation, documentation, and
handoff are complete. Remote matrix/release actions require explicit authority.

Last implementation commit: `caf58c7 fix(skia): preserve packaged link contract`.

Active paths:

- `skia/README.md`
- `docs/CONSUMING_DEPOT_TOOLS.md`
- `.agent/exec-plan-skia-prebuilt-link-contract.md`
- `.agent/evidence/skia-prebuilt-link-contract.jsonl`

Completed focused validation:

- Published `skia-158dc9d7-r7` diagnostics and all static archives were
  downloaded under the task-specific directory recorded in evidence.
- The macOS ARM64 Metal consumer link failed without backend frameworks and
  reported unresolved `MTL*` Objective-C classes.
- Published `args.gn`, compile commands, `build.ninja`, pinned Skia `BUILD.gn`,
  and archive symbols established the Milestone 1 mapping.
- `python3 skia/scripts/test-generate-build-config.py` passed 3 tests.
- Python bytecode compilation, `bash -n skia/scripts/common.sh`, and focused
  `git diff --check` passed.
- Staged SPDX validation passed for the eight-file metadata-emission commit.
- Four paired-fetch tests, the 11-key mapping check, a real current-r7 legacy
  fetch, and staged SPDX/diff validation passed for commit `f601c01`.
- The resolver script, seven `FindSkia` package tests, four generator tests,
  and four paired-fetch tests pass after commit `1083f82`.
- A sidecar generated from the corrected effective r7 macOS ARM64 GN listing
  validates against the exact published archive SHA.
- The committed Metal fixture links as an ARM64 Mach-O executable with only
  `Skia::Skia`; its transitive interface contains PNG, zlib, ApplicationServices,
  AppKit, OpenGL, Metal, and Foundation plus `SK_GL`, `SK_METAL`, and
  `SK_VULKAN`.
- Focused changed-file and staged SPDX checks plus `git diff --check` passed for
  the ten-file resolver commit.
- A fresh macOS ARM64 target build emitted a valid sidecar and linked the Metal
  fixture using only `Skia::Skia`.
- Fresh iOS device and iOS Simulator target builds emitted valid sidecars, and
  `package-ios-xcframework.sh` produced the XCFramework archive.
- The Linux x86_64 published diagnostic graph regenerated a 144-line effective
  listing with active system Freetype visible, and metadata validation against
  the published archive passed.
- TotalCross configured with `TCVM_DEPOT_TOOLS_DIR` pointing at this checkout
  and built ARM64 `libtcvm.dylib`. The package propagated
  `SK_BUILD_FOR_MAC`, `SK_GL`, `SK_METAL`, and `SK_VULKAN`; no downstream file
  or pin changed.
- Final focused suites pass: resolver matrix, seven package tests, five
  generator tests, and four paired-fetch tests.

Deferred expensive validation:

- No clean Skia rebuild or full target matrix was run for Milestone 1 because
  the published release diagnostics and archives provided sufficient evidence.
- Linux x86_64/aarch64/armv7l, Android, Windows x86/x64/ARM64, and WebAssembly
  GitHub runner builds were not locally available. Their existing parallel
  workflow lanes remain the pre-release level-4 gate.
- `actionlint` and PyYAML were unavailable. Ruby parsed the workflow YAML and
  the 11 archive/config mappings were checked directly.
- Release-mode fetch of a newly published metadata-enabled tag cannot run until
  a release exists; current r7 legacy fetch and synthetic new-format paired
  fetch both pass.

Active decisions and blockers:

- Correct `gn args --list --short` execution must run from the pinned Skia
  source root. Published r7 `gn-args-list.txt` and `gn-deps.txt` files contain a
  source-root error; the implementation corrects that boundary.
- Metal requires Apple Metal and Foundation frameworks. macOS GL requires the
  OpenGL framework. Linux EGL builds require EGL and GLESv2. Android uses NDK
  EGL, GLESv2, and log. Windows GL requires OpenGL32 on x86/x64 but the pinned
  GN graph intentionally omits it on ARM64. WebGL is toolchain-provided by
  Emscripten.
- Vulkan uses caller-supplied function tables and bundled VMA; no Vulkan loader
  link item is part of the current `Skia` target contract. The enabled Linux
  OpenCL flag adds no sources or dependency to the library target.
- Linux system Freetype and Fontconfig remain external toolchain/runtime
  requirements exposed by the current official build; they must not trigger
  package-manager installation.
- The real consumer link reports that the locally fetched zlib archive was
  built with a macOS 15 deployment target while the fixture requested macOS 11.
  This warning predates and is independent of the Skia link-contract fix, but
  remains release-readiness evidence to classify.
- The first TotalCross configure exposed an unrelated existing SQLite default
  tag mismatch (`3.32.3` versus the `deps.yml` effective `3.32.3-r2`). The
  focused downstream validation used an explicit matching release override;
  no SQLite source was changed.

Deliberate out-of-scope files:

- Existing unrelated untracked ExecPlans and `.agent/logs/` content.
- `deps.yml`, release tags, downstream TotalCross pins, and remote release state.

Next concrete action:

1. Run `.github/workflows/build-skia.yml` in build mode on the implementation
   branch/PR and require all existing platform lanes plus Windows `/MT` checks.
2. Review the macOS 15 zlib deployment-target warning before a release gate.
3. Only after explicit authorization, activate
   `defaults.machine_build_config.required`, perform the release operation, and
   update a downstream pin in a separate authorized change.

Resume command:

```sh
sed -n '1,220p' .agent/state/skia-prebuilt-link-contract.md
```
