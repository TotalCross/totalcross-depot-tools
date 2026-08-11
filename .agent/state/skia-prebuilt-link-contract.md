<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Skia prebuilt link contract execution state

Active milestone: Milestone 3, artifact publication and paired fetch.

Active slice: declare one target-specific sidecar for every static archive,
upload it from every workflow lane, and fetch/validate/install the library and
metadata as a pair independently of `--install-dev`.

Last logical commit: `06d6848 feat(skia): emit prebuilt link metadata`.

Active paths:

- `skia/artifacts.json`
- `skia/fetch.sh`
- `.github/workflows/build-skia.yml`
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

Deferred expensive validation:

- No clean Skia rebuild or full target matrix was run for Milestone 1 because
  the published release diagnostics and archives provided sufficient evidence.
- A real generated sidecar awaits one representative Skia target build after
  the generator commit; this is the Milestone 2 operation-family checkpoint.
- The macOS fixed consumer link is deferred until `FindSkia.cmake` consumes the
  new metadata in Milestone 4.

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

Deliberate out-of-scope files:

- Existing unrelated untracked ExecPlans and `.agent/logs/` content.
- `deps.yml`, release tags, downstream TotalCross pins, and remote release state.

Next concrete action:

1. Extend `skia/artifacts.json` with machine build-config entries and release
   assets for all 11 published static-library targets.
2. Make `skia/fetch.sh` download both files into temporary paths, validate v1
   platform/architecture/SHA fields, and only then replace the installed pair.
3. Add focused fetch tests and workflow sidecar verification/upload paths.

Resume command:

```sh
sed -n '1,220p' .agent/state/skia-prebuilt-link-contract.md
```
