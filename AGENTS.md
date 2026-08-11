<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Repository Guidelines

## Purpose

This repository owns the reproducible native dependency toolchain consumed by
TotalCross and other CMake projects. Each dependency must remain independently
buildable, fetchable, packageable, releasable, and consumable.

The repository must provide three stable contracts:

1. published native artifacts with predictable platform and architecture names;
2. CMake modules that fetch and resolve only those artifacts;
3. release metadata in `deps.yml` that identifies one compatible set of
   dependency releases.

## Instruction precedence

Apply instructions in this order:

1. safety and data-preservation requirements;
2. explicit user instructions for the current task;
3. the token, tool-output, and validation budget in this file;
4. `.agent/PLANS.md` when an ExecPlan is being created or executed;
5. instructions specific to the active ExecPlan or skill.

An ExecPlan cannot require expensive validation after every small edit merely
because the validation was useful at a previous checkpoint. Use the smallest
validation that proves the current change unless the user requests more, a
milestone is closing, an ABI or release contract changed, or a recorded failure
justifies escalation.

## ExecPlans and resumption

Use an ExecPlan for significant refactors, release-process changes, new platform
support, dependency-format changes, or work expected to span several logical
commits.

When creating a plan, read this file and `.agent/PLANS.md` in full. When resuming
an existing plan, read its state file first when one exists. Otherwise locate the
active headings and read only the sections needed for the next action. Do not
routinely reread the complete plan, evidence archive, historical milestones, or
large architecture documents.

A long-running plan should use:

- `.agent/state/<plan>.md` as the first resume read;
- `.agent/evidence/<plan>.md` or `.jsonl` for compact append-only evidence;
- `.agent/archive/<plan>-history.md` for completed detail;
- `.agent/reports/<plan>-editorial.md` for milestone and final factual reporting.

Keep the active plan concise. Move completed detail and raw evidence out instead
of repeatedly appending it.

## Repository layout

- `deps.yml`: compatible bundle index and effective release pins.
- `config/native-builds.yml`: canonical platform, target, library, dependency,
  and stack configuration once introduced.
- `<dependency>/manifest.yml`: source version, effective release tag, build
  metadata, and artifact names.
- `<dependency>/fetch.sh`: downloads published artifacts into
  `local/<platform>/<arch>`.
- `<dependency>/CMakeLists.txt`: builds the dependency in isolation.
- `<dependency>/cmake/AutoFetch*.cmake`: fetches missing repository artifacts.
- `<dependency>/cmake/Find*.cmake`: resolves only repository artifacts.
- `<dependency>/scripts/package-artifact.sh`: creates release archives.
- `<dependency>/scripts/build-<target>.sh`: explicit local build wrappers.
- `scripts/`: shared build, release, graph, configuration, and logging helpers.
- `docker/`: shared build images. Do not add per-dependency Docker directories.
- `.github/workflows/`: one workflow per library plus stack orchestrators.
- `.agents/skills/`: focused repository workflows loaded only when needed.

## Source-of-truth rules

`deps.yml` is the compatible release index. A dependency that consumes another
repository dependency must use the consumed dependency's `release` pin from
`deps.yml` by default. Do not resolve the latest GitHub Release. Explicit release
handoff inputs may override a pin only for a deliberate release operation.

Platform policy must come from `config/native-builds.yml` after that file is
introduced. Do not repeat these values in workflows or per-target wrappers:

- Android NDK version;
- default Android API level;
- Linux Docker registry and image version;
- Visual Studio generator;
- Windows static-runtime policy;
- shared runner labels or target architecture mappings.

Library-specific exceptions belong in library target overrides. Until the global
Android minimum changes, Android API 23 is the default and minizip Android uses
an explicit API 24 override.

## Standard dependency structure

New native dependencies must follow `docs/DEPENDENCY_STANDARD.md`. Use the
`add-native-dependency` skill and `tools/new-native-dependency.py` instead of
copying an arbitrary existing directory.

Use the create operation only to generate an intentionally incomplete starting
point, then run check for one dependency before functional validation. See
docs/DEPENDENCY_STANDARD.md for the command, completion work, target adapter,
and the boundary between structural and build checks.

Only create explicit target scripts for targets that the dependency will publish.
The scripts remain discoverable by name, but contain only the dependency and
target identity. They must delegate policy and command construction to shared
scripts.

Every dependency must document:

- upstream source and license;
- source version or commit;
- supported published targets;
- archive contents and imported CMake target names;
- build options that affect compatibility;
- direct local build commands;
- consumer CMake usage;
- release and fetch behavior.

## Dependency and artifact conventions

Install fetched artifacts under `local/<platform>/<arch>`.

Archive contents must use:

    <dependency>/<platform>/<arch>/{include,lib,manifest.txt}

Keep artifact names consistent across `manifest.yml`, `fetch.sh`, package
scripts, workflows, and documentation.

`Find*.cmake` must not silently select system, Homebrew, SDK, or unrelated
package-manager libraries. Prefer repository-local paths and use
`NO_DEFAULT_PATH` and `NO_CMAKE_FIND_ROOT_PATH` where appropriate.

`AutoFetch*.cmake` must derive its own location from `CMAKE_CURRENT_LIST_FILE`.
When the depot-tools checkout already exists, it must fetch only missing
artifacts rather than recloning the repository.

## Artifact consumers

The supported consumption model is documented in
`docs/CONSUMING_DEPOT_TOOLS.md`.

Consumers should keep:

- a bootstrap script such as `deps/fetch-depot-tools.sh`;
- a committed `deps/totalcross-depot-tools.ref` containing a tag or immutable
  ref;
- a checkout/cache at `deps/totalcross-depot-tools` or an explicitly configured
  equivalent;
- CMake integration through the dependency's `AutoFetch*.cmake`, `Find*.cmake`,
  and imported targets.

Encourage pinned tags. Do not recommend consuming the default branch for normal
builds. Preserve environment overrides for controlled testing and release
handoffs.

Use the distributable `adopt-totalcross-depot-tools` skill when integrating a
published dependency into another repository.

## Android

Only build or consume ABIs with published artifacts.

The Android NDK path must be resolved from the central NDK version and exported
through `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT`, and `NDK_BUNDLE`. Per-library
scripts must not embed an NDK version.

The default Android API remains 23 for the next release. Minizip may override it
to 24 through central library configuration. Do not copy that override to other
libraries.

## Linux and Docker

Linux image tags must be composed from central registry, image name, and image
version fields. A version update must require one edit, not one edit per target.

QEMU setup belongs to target policy and must run once per job when required.
Do not place QEMU bootstrap commands in each dependency wrapper.

Keep full Docker build logs in files or CI artifacts and print only a concise
summary and relevant failure tail.

## Apple

Use ARM64 GitHub-hosted macOS runners unless Intel is explicitly required.
Build non-Skia macOS, iOS, and iOS Simulator libraries sequentially on a shared
Apple runner when this reduces setup without changing artifacts.

Skia targets remain parallel. Reuse the shared Apple runner for Skia macOS only
when iOS and iOS Simulator Skia jobs can still run concurrently.

## Windows static runtime

Every Windows static library must use `/MT`.

CMake wrappers must include `cmake/TotalCrossWindowsStaticRuntime.cmake` before
`project()`. Nested upstream CMake builds may still need
`CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` propagated by the wrapper.

The Visual Studio generator and target platform mapping belong in central
configuration. Per-library scripts must not repeat the generator or runtime
value.

Every final Windows static archive must be checked with
`.github/scripts/verify-windows-static-runtime.ps1`. `vcruntime` is excluded
because it packages DLLs rather than static libraries.

## Skia

Skia uses GN and Ninja rather than the shared CMake executor.

- `skia/manifest.json` owns source/build pins.
- `skia/artifacts.json` owns release assets.
- `skia/fetch.sh` fetches published artifacts directly.
- GN/Ninja execution must use the repository log wrapper.
- Full diagnostics are stored as artifacts; console output stays compact.
- Skia target jobs must remain mutually parallel.
- A platform lane may continue into one matching Skia target, but must not
  serialize unrelated Skia targets that were previously concurrent.

## Workflows and releases

Each library should have one workflow with an operation input:

- `build` is the default and never changes Git or release state;
- `release` returns the existing release URL and succeeds when the effective
  version already exists, otherwise it builds and publishes;
- `force-release` always builds and publishes using the next allowed suffix.

A new release must update the library manifest and `deps.yml` with the effective
release tag before creating the release tag. The metadata commit, tag, and GitHub
Release must refer to the same revision.

Release jobs must use concurrency guards and recheck release existence before
creating a tag.

Stack workflows may reuse platform runners across libraries, but releases remain
individual. Stack `release` mode builds only missing releases and fetches existing
dependency releases instead of rebuilding them. Stack `force-release` rebuilds
and republishes every selected library.

## Scripts

Every script must be executable in Git.

Prefer one shared implementation used by local scripts and GitHub Actions. A
composite action should call the shared script rather than duplicate its command
sequence.

Shell scripts must use `set -euo pipefail` when Bash is required, quote paths,
avoid leaking tokens or authenticated URLs, and emit compact summaries.

Python scripts executed inside repository build images must remain compatible
with the oldest Python interpreter supplied by those images. The current Skia
Linux image is based on Ubuntu Bionic, so scripts executed there must support
Python 3.6; runner-only tooling may use a newer explicitly controlled version.
Do not assume host Python syntax or `pathlib` APIs exist in a build container.
Validate changed container-path Python with the interpreter in the actual image.

## Repository skills

Use skills for repeated workflows rather than expanding this file with procedural
detail:

- `validate-headers` before committing new or modified first-party files;
- `logical-commits` when the user requests commits or a plan requires logical
  checkpoints;
- `add-native-dependency` when adding a dependency directory and workflow;
- `adopt-totalcross-depot-tools` when integrating this repository into a consumer.

Skills may reference scripts and documentation. Keep each `SKILL.md` focused so
its name and description are enough for correct selection.

## Copyright headers

New first-party repository files must contain:

    SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    SPDX-License-Identifier: MIT

Use the correct comment syntax. `.agent/PLANS.md` is excluded from automated
header validation only when its adopted format requires that exclusion.

Before committing, use the `validate-headers` skill. Prefer changed-file or staged
validation; run the repository-wide check only for validator changes or release
gates.

## Commit policy

Commits must be logical, reviewable, and reasonably frequent during an ExecPlan.
Do not create a commit for every tiny edit, and do not combine unrelated layers.

Use English Conventional Commits with a scope and an explanatory body for every
non-trivial commit:

    <type>(<scope>): imperative description

The body explains motivation, behavior, compatibility or release impact, and
important validation. Use the `logical-commits` skill when committing.

Do not amend, rebase, force-push, or rewrite history unless the user explicitly
requests it.

## Token and tool-output budget

Operate in token-efficient mode by default.

### File reading

Use `rg`, `rg --files`, headings, exact searches, and narrow line ranges. Inspect
a diff summary before opening full diffs. Do not repeatedly dump `AGENTS.md`,
`PLANS.md`, manifests, generated matrices, logs, or evidence files.

Read one or two representative dependency implementations selected by similarity.
Do not inspect every library when the shared contract is already established.

### Git inspection

Prefer:

    git status --short -- <paths>
    git diff --stat
    git diff -- <paths>

Avoid broad status output in a noisy worktree. Preserve unrelated user changes.

### Build and validation output

Redirect full CMake, Ninja, CTest, Docker, sanitizer, static-analysis, benchmark,
and workflow-emulation output to task-specific log files.

On success, report one concise summary with status, counts or artifacts, duration
when useful, and log path. On failure, report the command, exit code, first
relevant error, short context, at most the final 100 lines, and log path.

Do not use verbose flags by default. Do not use `cat` on large logs, generated
files, matrices, or evidence archives.

### Validation levels

Stop at the first sufficient level:

1. **Implementation:** syntax, configuration resolution, focused unit test, or a
   single affected build script.
2. **Functional commit:** changed-file header checks, focused tests, artifact
   layout validation, and `git diff --check`.
3. **Operation family or ABI:** complete relevant target family, release dry run,
   CMake consumer fixture, or directly affected cross-builds.
4. **Milestone or release gate:** available platform matrix, packaging, release
   idempotence, dependency graph, and end-to-end consumer validation.

Do not run clean builds by default. Escalate for stale-output suspicion, ABI or
platform changes, milestone closure, release gates, explicit user request, or a
recorded prior failure.

### Plan updates

Update state after a logical commit or when interruption would otherwise make
resumption unsafe. Update the active plan at a functional-family, architecture,
ABI, release-policy, or milestone checkpoint, not after each command.

Record raw evidence once and point to it. Do not duplicate the same hashes,
counts, logs, and conclusions in state, plan, report, commit body, and chat.

## Safety

Never run destructive Git commands or remove local caches and generated output
merely to obtain a clean status.

Do not print secrets, token values, private authenticated URLs, or sensitive
repository locations.

Treat release, tag, push, commit, and `deps.yml` updates as state-changing actions.
Perform them only when explicitly requested by the user or required by an active
ExecPlan whose execution the user requested.

## Final handoff

Report:

- files changed;
- focused validations actually run and their status;
- generated artifacts or release URLs;
- expensive validations skipped and the reason;
- remaining risks or follow-up work.

Do not include full logs unless explicitly requested.
