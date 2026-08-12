<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Complete the Skia Vulkan consumer header contract

This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`.

## Purpose / Big Picture

A consumer that calls `find_package(Skia REQUIRED)` and links only
`Skia::Skia` must compile Skia's Vulkan-aware public headers without an external
Vulkan SDK. For metadata-driven repository artifacts, Vulkan remains separated
into its true requirements: `SK_VULKAN` at compile time, the development
bundle's `include/third_party/vulkan` directory for public headers, and no
Vulkan loader library for the pinned static archive. Linux and macOS regression
fixtures must prove header resolution, while macOS must retain metadata-derived
Metal framework linkage.

## Working Set and Resume Protocol

Read `.agent/state/complete-skia-vulkan-consumer-header-contract.md` first on a
normal continuation. It records the active slice, last commit, validation, and
next command. This plan is reread only when the architecture, acceptance scope,
or milestone changes. The final factual handoff will be stored in
`.agent/reports/complete-skia-vulkan-consumer-header-contract-editorial.md`.

The production paths are `skia/cmake/FindSkia.cmake`,
`skia/cmake/SkiaLinkDependencies.cmake`, and a narrowly scoped consumer
requirements helper if separation warrants it. Focused tests live under
`skia/cmake/tests/`; documentation lives in `skia/README.md` and, only if needed
for the shared consumption contract, `docs/CONSUMING_DEPOT_TOOLS.md`.

## Progress

- [x] (2026-08-12T00:00:00-03:00) Inspected the metadata-driven target,
  staging logic, fetched development tree, focused tests, and release boundary.
- [x] (2026-08-12T00:00:00-03:00) Committed compile/include/link separation
  and strict managed Vulkan-header validation as `3a5272c`.
- [x] (2026-08-12T00:00:00-03:00) Committed host-independent classifications,
  missing-header failures, and the real consumer fixture as `b8a7435`.
- [x] (2026-08-12T00:00:00-03:00) Documented the self-contained header
  contract; completed Linux/macOS, Metal, release-boundary, and downstream
  audits; finalized the plan and report in `6b99a23`.

## Current Architecture and Scope

`skia/scripts/common.sh::stage_dev_subset` copies the complete upstream
`include/` tree into the development bundle. The fetched r8 tree contains
`include/third_party/vulkan/vulkan/vulkan_core.h` and
`vulkan_android.h`, so the initial evidence does not justify a packaging or
release-asset change. The published archive itself must still be inspected
before completion.

`skia/cmake/FindSkia.cmake` locates the selected archive and normal include
paths, validates `SkiaBuildConfig.cmake`, asks
`SkiaLinkDependencies.cmake` for link requirements, and directly assembles
platform/backend compile definitions. It currently adds `SK_VULKAN` without
adding the bundled Vulkan include root. The imported target then exposes include
directories, link libraries, and definitions.

The implementation will add explicit functions for compile definitions and
include requirements while preserving the existing link classifier. Vulkan ON
classifies one bundled-header requirement. Resolution maps it to
`${SKIA_DIR}/include/third_party/vulkan`, checks `vulkan_core.h`, additionally
checks `vulkan_android.h` for Android metadata, and removes duplicate interface
entries. Missing headers are fatal only for metadata-driven artifacts whose
selected archive is under repository-managed `skia/local`; external and legacy
overrides are not reclassified as managed bundles.

No application-level Vulkan runtime, loader, `find_package(Vulkan)`, SDK
environment variable, system package, or consumer workaround enters scope.
No release, tag, push, `deps.yml` update, or downstream pin update is authorized.

## Plan of Work

### Milestone 1: Production contract

Introduce the compile and include requirement helper, use it from
`FindSkia.cmake`, and leave link resolution behavior unchanged. The observable
result is an imported target whose metadata-derived interfaces independently
contain definitions, include directories, and libraries. A managed Vulkan
artifact fails during configuration when required bundled headers are absent.
Run focused CMake classification/configuration checks, changed-file header
validation, and `git diff --check`, then commit as
`fix(skia): propagate bundled Vulkan headers` with an explanatory body.

### Milestone 2: Regression tests

Extend pure CMake classification coverage for Vulkan ON/OFF and Linux, macOS,
Android, and Windows selections. Extend Python configuration tests to inspect
`INTERFACE_INCLUDE_DIRECTORIES`, detect duplicate entries, prove managed missing
core/Android headers fail, and prove external compatibility remains bounded.
Add a consumer source including `include/gpu/GrBackendSurface.h`; it must link
only `Skia::Skia` and compile as an object without a consumer include workaround.
Keep the existing Metal executable/link fixture. Demonstrate the real compile
before committing as `test(skia): cover Vulkan consumer header contract`.

### Milestone 3: Documentation and acceptance

Document that repository-managed prebuilts propagate `SK_VULKAN` and bundled
build-time Vulkan headers without claiming to provide an application Vulkan
runtime. Inspect the published r8 development ZIP rather than inferring its
contents from staging alone. Validate a macOS consumer compile and Metal link
against the real macOS artifact. Validate Linux metadata and the header chain
with the real Linux artifact and a Linux-target object compile; use a native
Linux environment if available, otherwise record the exact cross-target
limitation rather than overstating it. Run all focused tests, header checks, and
diff checks. Commit documentation and final plan/report updates as
`docs(skia): document Vulkan header contract` when the documentation is a
meaningful slice.

## Surprises & Discoveries

- Observation: The existing ignored `skia/local` development tree already has
  both required Vulkan headers, while only macOS and Android libraries are
  installed and their metadata sidecars are absent.
  Evidence: focused `find` output under `skia/local` on 2026-08-12.
- Observation: no Docker command is available on this macOS host.
  Impact: native Linux proof may require another available local runtime or a
  self-contained cross-target compile; acceptance reporting must identify which
  one was achieved.
- Observation: the published r8 development ZIP directly contains both
  `vulkan_core.h` and `vulkan_android.h` in the expected path.
  Impact: no Skia archive rebuild or packaging change is required.
- Observation: a temporary Zig 0.14.1 cross compiler produced an x86-64 ELF
  object from the Linux fixture using the published Linux r8 metadata.
  Impact: Linux header compilation is proven without Docker or a Vulkan SDK;
  this remains a compile-only result, not a Linux runtime/link execution.

## Decision Log

- Decision: Model compile and include requirements explicitly, without changing
  the existing link classifier's conclusion for Vulkan.
  Rationale: public-header behavior and archive linkage are separate contracts.
  Date: 2026-08-12.
- Decision: Enforce bundled-header completeness only for repository-managed,
  metadata-driven libraries.
  Rationale: managed artifacts must be deterministic, while external/legacy
  overrides retain their documented compatibility boundary.
  Date: 2026-08-12.
- Decision: Keep development-bundle staging unchanged unless direct archive
  inspection contradicts the current full-include-tree evidence.
  Rationale: duplicating headers or rebuilding an artifact without evidence
  would distort the established package layout.
  Date: 2026-08-12.

## Validation and Acceptance

This is a consumer-interface change, so Milestones 1 and 2 use functional-commit
validation and final acceptance escalates to the affected operation family.
Focused checks are `cmake -P skia/cmake/tests/test-link-dependencies.cmake`,
`python3 skia/cmake/tests/test-find-skia.py`, the consumer CMake configure/build
commands for macOS and Linux metadata, repository changed-file header validation,
and `git diff --check`.

Acceptance requires all thirteen completion criteria from the goal: Vulkan ON
retains `SK_VULKAN` and gains exactly one bundled include root; OFF gains neither;
managed missing headers fail; no system Vulkan discovery or loader linkage is
added; the representative Linux and native macOS header chain compiles; macOS
Metal linkage still comes through `Skia::Skia`; focused tests pass; TotalCross
needs no workaround; and release/tag/pin state remains unchanged.

## Risks and Open Questions

The macOS fixture may expose unrelated repository PNG/zlib link prerequisites;
use the existing fetched repository artifacts and preserve their target contract.
The host has no Docker, so native Linux execution is not assumed. A cross-target
compile is acceptable evidence for header preprocessing and compilation only and
must not be described as a Linux runtime or link test.

## Idempotence and Recovery

All tests create build trees under temporary or ignored paths and can be rerun.
Do not delete or stage existing ignored/untracked `*/local/` directories. Before
each commit, inspect only `.agent`, `skia/cmake`, `skia/README.md`, and any shared
documentation actually edited. Never amend or rewrite commits. Fetching current
Skia assets may populate ignored `skia/local` paths but must not modify release
metadata.

## Outcomes & Retrospective

Milestone 1 completed in `3a5272c`: metadata now drives separate compile,
include, and link interfaces; managed Vulkan bundles validate core and Android
headers before exposing the bundled include root. Milestone 2 completed in
`b8a7435`: focused tests cover ON/OFF and managed/external behavior, while the
fixture includes the real `GrBackendSurface.h` path. Published r8 macOS and
Linux artifacts compile the fixture, and the macOS Metal executable links.
Milestone 3 confirmed the published development ZIP already contains the core
and Android Vulkan headers, documented the runtime boundary, and verified that
release metadata, tags, downstream pins, and TotalCross consumer workarounds
remain unchanged. No new Skia artifact release is required.

## Revision Note

Initial plan created on 2026-08-12 after inspecting the current r8 checkout and
the referenced goal. Finalized after all three logical slices and the complete
acceptance audit passed.
