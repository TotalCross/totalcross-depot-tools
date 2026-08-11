<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Make Skia prebuilts expose their build-time link contract

This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`.

## Purpose / Big Picture

A consumer that fetches a Skia prebuilt from `totalcross-depot-tools` must be
able to use:

```cmake
find_package(Skia REQUIRED)
target_link_libraries(my_target PRIVATE Skia::Skia)
```

without independently knowing which graphics backends were compiled into that
particular `libskia` artifact or manually repeating the platform libraries and
frameworks required by those backends.

Today the Skia build records GN configuration such as:

```text
skia_use_gl=true
skia_use_metal=true
skia_use_vulkan=true
```

but that information is only retained as diagnostic build metadata.
`FindSkia.cmake` does not consume it when constructing `Skia::Skia`.

The immediate observable failure is the macOS ARM64 consumer link failure in
which the repository-provided Skia library contains Metal objects such as
`GrMtlGpu.o` and `GrMtlPipelineStateBuilder.o`, but `Skia::Skia` does not
propagate the Apple framework dependencies required by that enabled backend.

The final design must solve the general problem rather than hard-code a macOS
Metal workaround.

Each Skia artifact must carry a versioned machine-readable description of the
effective build features that affect its consumer link contract. `FindSkia`
must load that description and derive the appropriate system libraries,
frameworks, and repository dependencies for the selected platform and enabled
features.

The intended boundary is:

```text
effective GN configuration
        |
        v
SkiaBuildConfig.cmake
        |
        v
SkiaLinkDependencies.cmake
        |
        v
Skia::Skia
        |
        v
consumer links without backend-specific duplication
```

A future Skia rebuild that changes:

```text
skia_use_metal=true
```

to:

```text
skia_use_metal=false
```

must automatically remove the Metal dependency from `Skia::Skia` without
requiring a corresponding change in TotalCross or another consumer.

The same mechanism must cover the current graphics/backend configurations on
macOS, iOS, iOS Simulator, Linux, Android, Windows, and WebAssembly, including
OpenGL, EGL, Metal, Vulkan, OpenCL, WebGL, and any other current direct
external link dependency discovered during implementation.

Do not disable an existing Skia backend merely to make a consumer build pass.

## Working Set and Resume Protocol

The active plan is:

```text
.agent/exec-plan-skia-prebuilt-link-contract.md
```

Use these supporting files:

```text
.agent/state/skia-prebuilt-link-contract.md
.agent/evidence/skia-prebuilt-link-contract.jsonl
.agent/archive/skia-prebuilt-link-contract-history.md
.agent/reports/skia-prebuilt-link-contract-editorial.md
```

On resume, read only:

```text
.agent/state/skia-prebuilt-link-contract.md
```

first.

The state file must identify the active milestone, last logical commit, current
paths, focused validation already completed, deferred expensive validation,
blockers, and the next concrete command or edit.

Read the active section of this plan only after the state file.

Read `.agent/evidence/skia-prebuilt-link-contract.jsonl` only when an exact
previous command, artifact hash, backend mapping, or validation result must be
recovered.

Read the archive only when the rationale for a completed or rejected design
choice is needed.

The implementation working set is initially:

```text
skia/scripts/common.sh
skia/artifacts.json
skia/fetch.sh
skia/cmake/FindSkia.cmake
skia/cmake/AutoFetchSkia.cmake
skia/README.md
.github/workflows/build-skia.yml
```

Expected new first-party paths are approximately:

```text
skia/scripts/generate-build-config.py
skia/cmake/SkiaLinkDependencies.cmake
skia/cmake/tests/...
```

The exact test layout may adapt to the repository's existing testing patterns,
but do not distribute dependency-selection logic across workflow YAML and
consumer fixtures.

Relevant generated/local paths are ignored build state and must not be committed:

```text
skia/out/
skia/dist/
skia/staging/
skia/local/
```

Keep full build and consumer logs under task-specific `/tmp` paths and record
only concise summaries in evidence.

## Progress

* [x] (2026-08-11) Identified the current macOS ARM64 failure as a Skia package
  link-contract problem rather than an incorrect architecture artifact.
* [x] (2026-08-11) Confirmed that the current build pipeline already records
  GN arguments and `gn desc` diagnostics for each Skia build.
* [x] (2026-08-11) Confirmed that current `FindSkia.cmake` propagates PNG/ZLIB
  but does not derive graphics/backend dependencies from build configuration.
* [x] (2026-08-11) Confirmed that `fetch.sh` currently installs the selected
  library independently and installs human-readable build manifests only as
  part of `--install-dev`.
* [x] (2026-08-11) Milestone 1: established the effective build-feature and
  link-dependency matrix from the r7 release archives, generated build graph,
  effective overrides, pinned Skia source, and symbol evidence.
* [x] (2026-08-11) Milestone 2 implementation: commit `06d6848` generates v1
  metadata from effective GN state, SHA-binds it to the final archive, and
  corrects GN diagnostics collection. Milestone 5 subsequently completed the
  real macOS, iOS, and iOS Simulator generation checkpoints.
* [x] (2026-08-11) Milestone 3 implementation: commit `f601c01` declares all 11
  archive/config mappings, uploads sidecars from every workflow lane, requires
  them during candidate aggregation, and installs validated pairs. The current
  r7 default remains a warned legacy contract until release activation.
* [x] (2026-08-11) Milestone 4: commit `1083f82` validates v1 metadata against
  the selected archive and makes `Skia::Skia` derive repository, framework,
  toolchain, and compile-definition requirements from effective features. The
  exact r7 macOS ARM64 archive links through the target-only Metal fixture.
* [x] (2026-08-11) Milestone 5 local closure: commit `caf58c7` preserves the
  repository dependency choices at packaging, propagates platform/backend
  definitions, and passes the synthetic matrix, exact-r7 and freshly built
  macOS consumers, macOS/iOS/iOS Simulator build family, XCFramework packaging,
  and explicit local TotalCross `tcvm` build. Cross-OS workflow execution is a
  recorded pre-release CI gate because those runners are not locally available.
* [x] (2026-08-11) Milestone 6 preparation: consumer documentation, release
  asset/mapping checks, compatibility behavior, validation evidence, and the
  downstream handoff are complete. Publication remains intentionally
  unauthorized; no release metadata, tag, push, release, or downstream pin was
  changed.
* [x] (2026-08-11) Finalized the editorial report and handoff.

## Current Architecture and Scope

Skia is different from most dependencies in this repository because it is
built through GN and Ninja rather than the shared CMake dependency executor.

`skia/scripts/common.sh` owns the per-platform GN configuration.

The current platform configurations include, among others:

```text
macOS:
    skia_use_gl=true
    skia_use_metal=true
    skia_use_vulkan=true

iOS / iOS Simulator:
    skia_use_gl=true
    skia_use_metal=true

Linux:
    skia_use_egl=true
    skia_use_gl=true
    skia_use_vulkan=true
    skia_use_opencl=true

Android:
    skia_use_gl=true
    skia_use_vulkan=true

WebAssembly:
    skia_use_gl=true
    skia_use_webgl=true
    skia_use_vulkan=false

Windows:
    skia_use_gl=true
    skia_use_vulkan=true
```

These examples describe current explicit GN arguments, not the authoritative
dependency mapping. Effective defaults and the generated GN target graph must
also be inspected before deciding that a feature does or does not require a
consumer-side library.

`gn_gen_and_build()` already runs GN before Ninja and records:

```text
gn args <build-dir> --list
gn desc <build-dir> //:skia
gn desc <build-dir> //:skia deps --all
```

under build diagnostics.

It also writes the argument set to:

```text
build_config_manifest.md
```

and `copy_static_artifact()` publishes a target-specific copy such as:

```text
build_config_manifest-macos-arm64.md
```

The human-readable manifest remains useful evidence, but it is not a stable
machine-readable package API.

`skia/artifacts.json` separately identifies:

* published static libraries;
* their installed paths;
* human-readable build manifests;
* the development-header bundle;
* the effective release.

`skia/fetch.sh` downloads and verifies the selected static library. Build
manifests are currently installed through the `--install-dev` path.

This is insufficient for the new contract because `FindSkia.cmake` must have
the machine metadata whenever a library is present, even when no development
bundle was requested.

`skia/cmake/FindSkia.cmake` currently creates:

```text
Skia::Skia
```

with the selected static archive, include paths, and the current external
PNG/ZLIB dependencies.

The implementation must preserve this single imported-target consumer
interface.

Do not require consumers to add:

```text
Metal
OpenGL
EGL
Vulkan
OpenCL
```

or equivalent dependencies manually based on platform assumptions.

This plan does not change which Skia backends depot-tools intentionally builds.
It changes how the build's existing dependency contract is recorded,
distributed, resolved, and validated.

This plan also does not modify TotalCross itself. The existing TotalCross
macOS build is an external end-to-end validation target after the depot-tools
package contract is corrected.

## Plan of Work

### Milestone 1: Establish the actual Skia link-contract matrix

The goal of this milestone is to replace assumptions with evidence before
introducing a dependency resolver.

Use the current pinned Skia source revision and current build definitions.

For each current target family, identify:

1. effective dependency-driving GN options;
2. relevant `//:skia` GN dependency graph nodes;
3. unresolved external symbols present in or pulled from the static artifact
   where useful;
4. platform libraries/frameworks required to satisfy those symbols;
5. whether each dependency is:

   * provided by the platform SDK;
   * provided by another depot-tools artifact;
   * bundled into Skia;
   * supplied by a toolchain;
   * an optional external runtime not currently guaranteed by depot-tools.

Do not infer dependencies solely from names such as:

```text
platform == macos
```

or:

```text
skia_use_metal == true
```

without checking the current Skia build graph.

The feature flag is the selector used by the final package contract, while the
current Skia GN graph is the implementation-time authority for determining what
that selector means.

Start with macOS ARM64 because it contains the known failure.

Confirm that the selected released artifact is:

```text
macos / arm64
```

and that Metal was actually enabled in its recorded build configuration.

Use focused symbol inspection and a minimal consumer/link reproduction to
establish the missing dependencies.

Then inspect the current configurations for:

```text
macos-arm64
ios-arm64
ios-simulator-arm64
linux-x86_64
linux-aarch64
linux-armv7l
android-arm64-v8a
wasm-wasm32
windows-x86
windows-x64
windows-arm64
```

Do not perform a clean full Skia rebuild merely to enumerate flags already
present in build scripts or published diagnostics.

Escalate to an affected build only where the existing metadata is insufficient.

Record the resulting logical matrix in compact evidence, not as a large table
inside the active plan.

Acceptance for this milestone:

* the macOS Metal failure has a concrete dependency explanation;
* every currently enabled graphics backend is classified;
* optional external runtimes such as Vulkan/OpenCL are explicitly identified
  rather than silently resolved from Homebrew or another package manager;
* no dependency mapping in later milestones depends only on platform name.

Normal validation level: 1, escalating to 2 for the macOS reproduction.

Create one logical commit only if repository files are changed during this
milestone. Pure investigation does not require an empty checkpoint commit.

### Milestone 2: Generate versioned machine-readable build metadata

Introduce a stable machine-readable sidecar named:

```text
SkiaBuildConfig.cmake
```

installed beside each platform library:

```text
local/out/Release/<platform>/<arch>/
    libskia.a
    SkiaBuildConfig.cmake
```

or, on Windows:

```text
local/out/Release/windows/<arch>/
    libskia.lib
    SkiaBuildConfig.cmake
```

Use CMake syntax rather than JSON so consumers compatible with the repository's
existing older CMake floor do not need modern JSON parsing support.

The first format version is:

```cmake
set(SKIA_BUILD_CONFIG_VERSION 1)
```

At minimum record:

```text
metadata version
Skia upstream commit
target platform
target architecture
library SHA-256

effective GPU/backend feature flags that influence linkage
effective external/bundled dependency choices that influence linkage
```

Representative fields may include:

```cmake
set(SKIA_BUILD_ENABLE_GPU ON)
set(SKIA_BUILD_USE_GL ON)
set(SKIA_BUILD_USE_EGL OFF)
set(SKIA_BUILD_USE_METAL ON)
set(SKIA_BUILD_USE_VULKAN ON)
set(SKIA_BUILD_USE_OPENCL OFF)
set(SKIA_BUILD_USE_WEBGL OFF)
set(SKIA_BUILD_USE_ANGLE OFF)

set(SKIA_BUILD_USE_SYSTEM_ZLIB ON)
set(SKIA_BUILD_USE_SYSTEM_LIBPNG ON)
```

Do not maintain these booleans independently from the actual GN configuration.

Generate them after `gn gen` from the effective GN build state.

Prefer querying/parsing the effective GN arguments already available from the
generated build directory. If the available GN output requires a small
normalization layer, implement it in:

```text
skia/scripts/generate-build-config.py
```

Keep the parser intentionally limited to dependency-driving arguments.

Do not create a general GN parser.

The generator must receive or derive:

```text
build directory
platform
architecture
Skia source commit
built library path
```

and must fail if a required dependency-driving value cannot be classified.

The library SHA-256 must be written after the final archive exists.

This binds the sidecar to the exact static artifact and allows `FindSkia` to
detect stale or partially replaced artifact pairs.

Update `copy_static_artifact()` or the closest shared build boundary so every
Skia target emits both:

```text
libskia-<target>.a/.lib
SkiaBuildConfig-<target>.cmake
```

into `skia/dist/` and installs the generic sidecar name into staging.

Continue generating:

```text
build_config_manifest-<target>.md
```

for human diagnostics.

Do not replace the existing human manifest with the machine contract.

Add focused tests for the metadata generator using small captured/synthetic GN
argument fixtures.

Acceptance:

* metadata is derived from effective GN state rather than duplicated shell
  constants;
* changing a backend flag changes the emitted sidecar;
* platform and architecture are recorded;
* the sidecar contains the final library SHA-256;
* malformed or unsupported configuration fails generation clearly;
* all existing human diagnostics remain available.

Normal validation level: 2.

Suggested logical commit:

```text
feat(skia): emit prebuilt link metadata
```

### Milestone 3: Package and fetch metadata as part of the artifact contract

Extend `skia/artifacts.json` with one machine build-config entry for every
published static library.

Use target-specific release asset names, for example:

```text
SkiaBuildConfig-macos-arm64.cmake
SkiaBuildConfig-ios-arm64.cmake
SkiaBuildConfig-linux-x86_64.cmake
SkiaBuildConfig-windows-x64.cmake
```

and install them as:

```text
local/out/Release/<platform>/<arch>/SkiaBuildConfig.cmake
```

Keep the mapping declarative in `artifacts.json`; do not duplicate artifact
names in `fetch.sh`.

Add the sidecars to the Skia release asset set.

Update each build lane in `.github/workflows/build-skia.yml` so its artifact
verification requires both:

```text
library
SkiaBuildConfig-<target>.cmake
```

and its artifact upload includes both.

The existing release-assets aggregation should then naturally collect the
sidecars before `SHA256SUMS` is generated.

Modify `skia/fetch.sh` so the matching machine configuration is downloaded
whenever a static library is fetched.

Do not tie it to:

```text
--install-dev
```

The human build manifests and header bundle may retain their current
`--install-dev` behavior.

Download the library and build config into temporary locations first.

Verify:

```text
release checksum, when configured
metadata format/version
metadata platform
metadata architecture
metadata library SHA-256
```

before considering the pair valid.

Install through temporary destination files and rename into the final paths.

There is no portable atomic rename transaction spanning two files, so
`FindSkia` must independently verify the metadata's library SHA before exposing
the imported target. A process interrupted between the two renames can
therefore produce a detectable state but not a silently incorrect package.

Do not delete the previously installed valid artifact pair before the
replacement pair has been downloaded and verified.

Preserve `--source` and other explicit developer overrides.

For a source override, allow a matching explicit build-config override if
needed. Do not fabricate backend metadata from the host platform.

Acceptance:

* normal fetch installs the library and matching machine metadata;
* `--install-dev` is no longer necessary for `FindSkia` metadata;
* checksum mismatch is rejected;
* platform/architecture mismatch is rejected;
* library/metadata SHA mismatch is rejected;
* a failed download does not intentionally remove the previous valid pair;
* existing human manifests and dev-bundle behavior remain supported.

Normal validation level: 2.

Suggested logical commit:

```text
feat(skia): fetch prebuilt link metadata
```

### Milestone 4: Resolve `Skia::Skia` dependencies from build metadata

Create:

```text
skia/cmake/SkiaLinkDependencies.cmake
```

Keep `FindSkia.cmake` responsible for:

1. locating the repository Skia artifact;
2. locating and loading its matching build metadata;
3. validating metadata compatibility;
4. asking `SkiaLinkDependencies.cmake` for the link requirements;
5. constructing `Skia::Skia`.

Keep feature-to-platform dependency policy out of TotalCross and other
consumers.

Separate logical classification from physical CMake resolution.

For example, one internal helper should be testable with a synthetic:

```text
platform = macos
metal = ON
gl = ON
vulkan = OFF
```

and return logical requirements such as:

```text
apple-metal
apple-opengl
```

without needing to run on macOS.

A second layer running on the real target platform resolves those requirements
to actual CMake link items.

This separation allows the mapping policy to be unit-tested on a single host
while real platform builds validate the resolved libraries.

Use the Milestone 1 evidence for exact mappings.

Do not guess or silently search Homebrew/package-manager paths.

Platform SDK dependencies may be represented using appropriate CMake
framework/library mechanisms.

Repository-owned dependencies must continue to use repository targets such as:

```text
PNG::PNG
ZLIB::ZLIB
```

when the build metadata says those external/system variants are required.

If an enabled backend requires a non-platform runtime not currently guaranteed
by depot-tools, such as a Vulkan/OpenCL loader on a particular platform, stop
and classify that requirement before choosing a resolution strategy.

The acceptable choices are:

1. an explicitly supported platform/toolchain dependency already guaranteed by
   the target environment;
2. a repository dependency already managed by depot-tools;
3. a separately planned dependency addition.

Do not silently make Homebrew, Chocolatey, apt, or an arbitrary Vulkan SDK a
new consumer prerequisite.

For repository-managed Skia artifacts carrying v1 metadata, missing metadata is
an error.

An explicit externally supplied `SKIA_LIBRARY` outside the repository-managed
Skia local root may keep a compatibility path:

```text
metadata supplied:
    use metadata-driven resolution

metadata absent:
    warn clearly
    preserve legacy dependency behavior
```

Do not infer Metal/OpenGL/Vulkan solely from the host in that legacy path.

Validate:

```text
SKIA_BUILD_CONFIG_VERSION
platform
architecture
library SHA-256
```

before creating `Skia::Skia`.

Unknown metadata versions must fail with an actionable message.

Unknown enabled dependency-driving features must not be silently ignored.

Acceptance:

```cmake
find_package(Skia REQUIRED)
target_link_libraries(consumer PRIVATE Skia::Skia)
```

is sufficient for repository-managed prebuilts.

The current macOS Metal dependency is present because metadata says Metal was
enabled, not because the platform name is `macos`.

The corresponding dependency disappears from the computed interface when
Metal is disabled in a synthetic build configuration.

The same rule applies to every supported backend mapping.

Normal validation level: 3 for the affected platform family.

Suggested logical commit:

```text
feat(skia): derive link interface from build metadata
```

### Milestone 5: Validate backend combinations and real consumers

Add focused package-contract tests.

Synthetic tests must cover at least:

```text
macOS + Metal ON
macOS + Metal OFF

macOS + OpenGL ON/OFF

iOS + Metal ON/OFF

Linux + OpenGL
Linux + EGL
Linux + Vulkan
Linux + OpenCL

Android + current GL/EGL requirements
Android + Vulkan

Windows + OpenGL
Windows + Vulkan

WebAssembly + WebGL
```

Use the exact Milestone 1 mappings rather than assuming all named features
require a standalone linker library on every platform.

Test feature combinations because current prebuilts intentionally contain
multiple enabled backends.

For example, the current macOS configuration must exercise approximately:

```text
GL = ON
Metal = ON
Vulkan = ON
```

and ensure the resolver returns the union of applicable requirements without
duplicates.

Also test:

* unsupported metadata version;
* missing managed metadata;
* wrong platform;
* wrong architecture;
* wrong library hash;
* external library compatibility fallback;
* disabled feature does not add its dependency.

Add a minimal CMake consumer fixture that only depends on:

```cmake
Skia::Skia
```

and does not manually repeat backend libraries.

Where a trivial unused static-library link would not pull the backend objects,
make the fixture reference the smallest available public backend API needed to
exercise the dependency.

Do not use whole-archive by default if doing so would require unrelated,
normally unreachable Skia objects and artificially expand the consumer
contract.

At the macOS checkpoint, reproduce the original failure path and prove it links
after the change.

Then run the complete relevant Skia target family required by validation level
3.

At milestone closure, use the available platform matrix in
`.github/workflows/build-skia.yml` as the level-4 package/release gate.

Existing Skia build jobs must remain mutually parallel.

Do not serialize unrelated Skia platform jobs to simplify validation.

On Windows, preserve the `/MT` static-runtime validation.

On WebAssembly, record backend metadata but do not invent native system
libraries for WebGL when Emscripten owns those semantics.

Acceptance:

* synthetic resolver tests pass;
* machine metadata exists for every published target;
* CMake consumer fixtures use only `Skia::Skia`;
* macOS ARM64 no longer fails with unresolved `MTL*` classes;
* no platform has an unexplained newly unresolved backend symbol;
* no consumer fixture manually duplicates backend requirements;
* existing Skia artifact names and architecture coverage remain intact.

Normal validation level: 3 during implementation, level 4 at milestone closure.

Suggested logical commit:

```text
test(skia): validate prebuilt link contracts
```

### Milestone 6: Documentation, release contract, and TotalCross handoff

Update `skia/README.md` to explain that fetched prebuilts are self-describing and
that normal CMake consumers should use only:

```cmake
find_package(Skia REQUIRED)
target_link_libraries(target PRIVATE Skia::Skia)
```

Document:

* `SkiaBuildConfig.cmake`;
* metadata versioning;
* library SHA binding;
* external-library fallback behavior;
* how build flags control link dependencies;
* that the human build manifest remains diagnostic rather than API.

Do not document consumers adding Metal/OpenGL/Vulkan manually.

Update any release-asset validation necessary to require the new sidecars.

A new Skia release is required before TotalCross can consume the strict new
artifact contract through its normal pinned release.

Do not publish that release automatically merely because implementation
validation passes.

Before publication:

1. run the complete Skia release/build matrix;
2. verify every library has a matching sidecar;
3. verify all sidecars match their library SHA;
4. verify release-assets aggregation includes every sidecar;
5. verify `SHA256SUMS`;
6. perform release dry-run/build-only validation where supported;
7. confirm no release with the selected effective tag already exists;
8. recheck repository HEAD and release metadata immediately before any
   state-changing release operation.

Release/tag/push execution requires explicit user authorization.

When authorized, use the repository's existing Skia release operation rather
than manually constructing a tag and GitHub Release.

The effective Skia release tag, release metadata commit, tag, GitHub Release,
`skia/manifest*` metadata, `skia/artifacts.json`, and `deps.yml` must follow the
repository's existing same-revision release policy.

If the desired release already exists, follow the repository's idempotent
release behavior rather than overwriting it.

If publication fails partially, detect which of:

```text
metadata commit
tag
GitHub Release
assets
deps.yml pin
```

exists before retrying.

Do not delete or overwrite a valid release as recovery.

After the new release is available, validate the original TotalCross macOS ARM64
consumer using an explicit dependency-release override first.

Do not modify TotalCross's committed depot-tools pin as part of this ExecPlan
unless explicitly requested.

The expected external handoff is:

```text
new depot-tools Skia release
        |
        v
TotalCross dependency override
        |
        v
macOS ARM64 VM/Launcher link succeeds
        |
        v
separate TotalCross pin update
```

Acceptance:

* documentation reflects the metadata-driven contract;
* the release artifact set is complete and internally consistent;
* the released package can be fetched cleanly;
* a TotalCross macOS ARM64 build using the new release no longer requires a
  local Metal workaround;
* publication state and release URL are recorded in evidence if publication was
  authorized.

Suggested final implementation/documentation commit before release:

```text
docs(skia): document prebuilt link contract
```

Do not create release commits, tags, pushes, or releases until authorized.

## Surprises & Discoveries

* Observation: the existing Skia build already captures both effective build
  diagnostics and GN dependency information, so the new contract should extend
  that build boundary rather than add consumer-side platform guessing.
  Evidence: `skia/scripts/common.sh` generates `gn-args-list.txt`,
  `gn-target.txt`, `gn-deps.txt`, and `build_config_manifest.md`.

* Observation: machine metadata cannot live only in the development bundle
  because normal artifact fetch and `FindSkia` must remain correct even without
  `--install-dev`.
  Evidence: current `fetch.sh` installs build manifests only from the dev-bundle
  path.

* Observation: the current macOS artifact intentionally enables GL, Metal, and
  Vulkan simultaneously. The Metal objects responsible for the failing symbols
  therefore belong to the expected artifact rather than indicating an
  accidental iOS or wrong-architecture library.

* Observation: static archives do not preserve the complete GN link interface
  in a way downstream CMake automatically understands. The depot-tools package
  must explicitly reconstruct that interface.

* Observation: the r7 diagnostics collector invoked `gn args` and `gn desc`
  outside the Skia source root, so the published `gn-args-list.txt`,
  `gn-target.txt`, and `gn-deps.txt` contain a source-root error. Generated
  `args.gn`, `build.ninja`, compile commands, source `BUILD.gn`, and archive
  symbols provided the missing evidence. The metadata slice corrects the
  collector working directory.

* Observation: current Vulkan backends use caller-supplied entry points and
  bundle VMA, so they do not add a Vulkan loader link item. The enabled Linux
  OpenCL flag does not add sources or dependencies to the `Skia` library target.

* Observation: target-local GN arguments such as the pinned Skia
  `skia_use_system_freetype2` declaration do not appear in the global effective
  argument listing when their target is inactive. Repository zlib/libpng
  selection is therefore recorded from the shared build boundary that actually
  selects those prebuilts. An absent nested declaration is the authoritative
  inactive classification; the Linux configuration confirmed that active
  system Freetype does appear in the effective listing.

* Observation: the first local dependency synchronization attempt opened all
  upstream clones concurrently and received HTTP 429 responses. The checkout
  and completed caches remain recoverable; no cache was removed.

* Observation: GN argument producers run in shell command substitutions, so
  their `SKIA_DEP_USE_*` assignments do not survive until artifact packaging.
  The first fresh sidecar exposed this by recording repository PNG/zlib as off;
  the generated consumer then failed on PNG symbols. Re-resolving the validated
  prebuilt selection at `copy_static_artifact()` fixed the package boundary and
  the generator now rejects inconsistent libpng selection.

* Observation: TotalCross defines the legacy `linux` macro in its macOS native
  build. Once backend definitions were correctly propagated, that macro made
  pinned Skia headers choose their Unix platform branch. Propagating the
  metadata-derived `SK_BUILD_FOR_*` definition fixed the consumer without a
  downstream workaround.

Move resolved discoveries to the archive at milestone checkpoints rather than
allowing this section to grow indefinitely.

## Decision Log

* Decision: use a versioned CMake sidecar rather than the existing Markdown
  build manifest as the machine package API.
  Rationale: the consumer already uses CMake, the repository supports older
  CMake versions, and the human manifest should remain free to evolve as
  diagnostics.
  Date: 2026-08-11.

* Decision: derive the sidecar from effective GN build state after `gn gen`.
  Rationale: duplicating the platform feature flags manually would allow the GN
  build and published metadata to drift.
  Date: 2026-08-11.

* Decision: keep the exact GN graph as build-time authority and the generated
  sidecar as the published consumer contract.
  Rationale: downstream consumers must not need GN, Ninja, Skia source, or build
  diagnostics merely to link a prebuilt.
  Date: 2026-08-11.

* Decision: fetch machine metadata with every static library, independent of
  `--install-dev`.
  Rationale: `FindSkia` needs the contract whenever the library is consumed.
  Date: 2026-08-11.

* Decision: bind metadata to the final library SHA-256.
  Rationale: two separately installed files cannot be replaced transactionally
  on every supported host, so the package must detect partial or stale pairs.
  Date: 2026-08-11.

* Decision: keep `Skia::Skia` as the consumer-facing imported target.
  Rationale: backend details belong to the dependency package, not to TotalCross
  or another application.
  Date: 2026-08-11.

* Decision: resolve dependencies from both platform and enabled feature.
  Rationale: `macOS => Metal` or `Linux => OpenGL` would reproduce the same
  hidden coupling in a different file and fail when future Skia flags change.
  Date: 2026-08-11.

* Decision: record repository zlib/libpng selection explicitly in the v1
  sidecar from `configure_prebuilt_deps()` state.
  Rationale: these inputs are validated and applied at the shared build
  boundary, while the pinned GN graph does not expose every nested dependency
  choice in the global `gn args --list --short` output.
  Date: 2026-08-11.

* Decision: expose the artifact platform identity through `Skia::Skia` together
  with backend compile definitions.
  Rationale: consumers compile Skia public headers and must see the same
  platform branch as the prebuilt, even if their own legacy macros conflict.
  Date: 2026-08-11.

* Decision: do not disable Metal, Vulkan, OpenGL, or another existing backend to
  make the current failure disappear.
  Rationale: this work corrects artifact metadata and consumption, not Skia
  capability policy.
  Date: 2026-08-11.

* Decision: do not silently introduce Homebrew, apt, Chocolatey, or arbitrary SDK
  dependencies.
  Rationale: repository policy requires predictable dependency resolution; any
  newly discovered external runtime must be classified explicitly.
  Date: 2026-08-11.

## Validation and Acceptance

Follow the validation levels in `AGENTS.md` and stop at the first sufficient
level for each slice.

### Level 1 — implementation

Use for:

* metadata parser/generator development;
* pure CMake requirement classification;
* synthetic feature combinations;
* format-version validation.

Expected proof:

```text
focused unit/script tests pass
generated sidecar contains expected effective values
disabled features remain absent
```

### Level 2 — functional commit

Before each logical implementation commit:

* run changed-file copyright/header validation;
* run focused metadata or resolver tests;
* validate changed artifact layout where applicable;
* run `git diff --check`;
* inspect the staged diff.

Do not run the full Skia matrix after every commit.

### Level 3 — operation family / ABI

Use when:

* fetch/package layout changes;
* `Skia::Skia` link behavior changes;
* one platform backend mapping is completed.

Expected proof includes:

```text
matching build/fetch target
matching CMake consumer fixture
artifact/metadata hash validation
```

For the immediate regression, macOS ARM64 is mandatory at this level.

### Level 4 — milestone/release gate

Before a new Skia release:

* run the available Skia platform matrix;
* validate release asset aggregation;
* validate metadata for every published static library;
* validate release checksums;
* run CMake consumer tests on available native platforms;
* perform the external TotalCross macOS ARM64 validation with a release
  override when the release candidate is available.

Keep full logs outside the active plan.

Evidence should record:

```text
timestamp
revision
milestone/slice
command or workflow
status
target
artifact paths
relevant SHA-256 values
log path
limitations
```

The final acceptance criteria are:

1. every repository-published Skia static library has versioned machine build
   metadata;
2. metadata represents effective dependency-driving build features;
3. metadata is fetched whenever its library is fetched;
4. metadata and library are cryptographically paired;
5. `FindSkia` validates the pair;
6. `Skia::Skia` derives its external link interface from platform plus enabled
   features;
7. Metal is included only when the selected artifact says Metal was enabled;
8. OpenGL/EGL/Vulkan/OpenCL/WebGL and other current backend dependencies follow
   the same model;
9. no TotalCross-specific workaround exists in depot-tools;
10. the original macOS ARM64 unresolved `MTL*` link failure is eliminated;
11. existing backend capability remains unchanged;
12. release behavior remains reproducible and idempotent.

## Risks and Open Questions

The exact feature-to-library matrix is deliberately not guessed in this plan.
Milestone 1 must establish it from the pinned Skia GN graph and actual platform
link behavior.

Vulkan and OpenCL are potentially different from Apple Metal or system OpenGL:
some platforms may not guarantee their loader/runtime through the base SDK. If
the current Skia artifact exposes such a requirement, determine whether it is
already guaranteed by the build target or needs a separate depot-tools
dependency. Do not silently add a package-manager lookup.

Android may obtain some EGL/GLES behavior through target defaults even when a
specific GN boolean is not written explicitly in the current argument helper.
This is one reason metadata must reflect effective GN state rather than only
grep the shell source.

A static archive can contain backend objects that are never pulled by a
particular consumer. A validation fixture should exercise the intended backend
surface rather than use whole-archive by default and accidentally make normally
unreachable optional objects part of the required link contract.

The iOS XCFramework has a different consumer surface from raw CMake static
libraries. Keep the machine sidecars associated with the raw platform artifacts
and do not redesign XCFramework packaging unless validation proves that the
same missing-contract problem affects it.

Existing older Skia releases do not contain `SkiaBuildConfig.cmake`.
Implementation and release activation must preserve a deliberate legacy
transition rather than making the currently pinned release unusable in the
middle of development.

Use metadata presence/version and the release transition to distinguish a
legacy external/prebuilt artifact from a repository-managed new-format artifact.
Do not permanently allow a new-format repository artifact to silently omit its
sidecar.

## Idempotence and Recovery

Do not delete `skia/local`, source caches, ccache, or build outputs merely to
force a clean environment.

Generated sidecar creation must overwrite only the sidecar in the current build
directory or staging target.

Repeated metadata generation from the same effective GN configuration and same
library must produce byte-identical output.

Repeated fetch of the same release must produce the same installed library and
metadata.

Fetch must download into temporary files and validate both before replacing
the currently valid installed pair.

If one final rename is interrupted, `FindSkia` must reject the mismatched
library SHA on the next configure.

A failed new release publication must be inspected before retrying. Never assume
that absence of the final GitHub Release means no tag or metadata commit exists.

Do not rewrite repository history.

Do not force-push.

Do not modify unrelated local files.

Before every logical commit, scope status and diff inspection to the current
milestone paths.

Before a release or push, recheck:

```text
current branch
HEAD
working-tree scope
effective release tag
existing remote tag/release state
```

## Outcomes & Retrospective

The implementation is complete through the locally available package and
consumer gates. Three implementation commits establish the sidecar emission,
paired publication/fetch, and metadata-driven imported-target contract; a
fourth fixes package-boundary state and downstream platform-definition issues
found by real builds.

The plan starts from a reproduced packaging defect: the selected macOS Skia
prebuilt contains code from backends enabled by its GN configuration, while the
CMake imported target does not expose the corresponding link contract.

The outcome is a general artifact-level contract rather than a one-platform
patch. The exact published r7 archive and a freshly built archive both link the
same target-only Metal fixture, and the principal TotalCross consumer builds
against the local checkout without a Metal workaround.

The factual final report is:

```text
.agent/reports/skia-prebuilt-link-contract-editorial.md
```

with factual results only.

The final report must distinguish:

* dependencies predicted from flags;
* dependencies confirmed from GN/build evidence;
* dependencies actually validated by consumer links;
* supported platform lanes;
* unvalidated or intentionally deferred combinations.

Cross-platform classifier cases and the published GN/archive matrix support all
11 mappings, but only the locally available Apple build family was rebuilt.
Linux, Android, Windows, and WebAssembly workflow execution remains the required
pre-release CI gate and is not implied by the successful Apple evidence.

## Revision Note

Initial plan created to generalize the Skia macOS Metal link failure into a
versioned, metadata-driven prebuilt link contract.

The key architectural choice is that build-time GN configuration is persisted
with each Skia artifact and interpreted by `FindSkia`, so consumers no longer
duplicate backend dependency knowledge.
