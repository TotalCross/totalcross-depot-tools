<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Native dependency standard

## Purpose

Every dependency in this repository should be predictable to maintainers,
workflows, release tooling, and consumers. This document defines the required
layout and contracts for adding a new native dependency.

Use the `add-native-dependency` skill and `tools/new-native-dependency.py` to
create the initial structure. Do not copy an arbitrary existing dependency: some
folders contain historical exceptions that are not the current standard.

## Scaffold and structural check

The scaffold creates an intentionally incomplete CMake dependency. It is useful
when a library is ready to be onboarded but its build, artifact, and release
details have not yet been implemented. Run it from the repository root:

    python3 tools/new-native-dependency.py create --name example --package Example --version 1.2.3 --source-url https://github.com/example/example.git --source-tag v1.2.3 --imported-target Example::Example --library-name example --stack others --targets linux-x86_64 windows-x64 android-arm64

Only requested targets receive a scripts/build-<target>.sh wrapper. The command
refuses an existing dependency directory, generated file, or library workflow.
It has no force mode.

Every generated file has an SPDX header. The CMake, fetch, package, auto-fetch,
find, README, and workflow files deliberately contain the
TC_DEPOT_SCAFFOLD_TODO marker. Replace every marker with a real implementation
before adding the dependency to a release. The manual work includes upstream
license notices, source/build logic, deterministic packaging, artifact fetching,
CMake resolution, central build configuration, workflow operation handling, and
a consumer validation.

Check only one candidate dependency:

    python3 tools/new-native-dependency.py check example

The check is read-only and accepts either a dependency name relative to the
repository root or an absolute dependency path. It validates manifest fields,
target/archive/wrapper consistency, executable scripts, SPDX headers, required
modules and workflow, placeholder absence, forbidden wrapper policy, Windows
runtime-policy ordering, and generated directories. It is a structural check,
not a successful native build: completing it does not replace build, package,
fetch, CMake-consumer, workflow, or release validation.

Until config/native-builds.yml exists, accepted target names and canonical
archive suffixes live in tools/native_dependency_targets.py. Add a new target
there with its archive suffix, then extend focused tests and central build
configuration when it is introduced. The scaffold and check use that one
adapter, so the command interface will remain stable when it becomes an adapter
to central configuration.

The scaffold never publishes a release, creates a tag, or updates deps.yml. Do
those operations only after the dependency has a real compatible release.

## Required inputs before scaffolding

Collect these facts first:

- repository directory name, such as `libpng`;
- human package name and CMake package name;
- upstream source URL and immutable version, tag, or commit;
- upstream license and where its notices must be preserved;
- build system (`cmake`, `gn`, or an explicitly approved custom system);
- published target list;
- installed headers and static library names;
- imported CMake target name;
- build-time dependencies on other depot-tools libraries;
- stack membership (`graphics` or `others`);
- whether tests can run for each host-compatible target;
- any target-specific compatibility override.

Do not guess a package name, library filename, license, or dependency edge.
Inspect the upstream build and one similar repository dependency.

## Canonical layout

A CMake-built dependency normally contains:

    <dependency>/
      README.md
      manifest.yml
      CMakeLists.txt
      fetch.sh
      cmake/
        AutoFetch<Package>.cmake
        Find<Package>.cmake
      scripts/
        package-artifact.sh
        build-android-arm64.sh
        build-ios-arm64.sh
        build-ios-simulator-arm64.sh
        build-linux-aarch64.sh
        build-linux-armv7l.sh
        build-linux-x86_64.sh
        build-macos-arm64.sh
        build-windows-arm64.sh
        build-windows-x64.sh
        build-windows-x86.sh

Create only target scripts for artifacts that will be published. Every script
must be executable in Git.

A non-CMake dependency may replace `CMakeLists.txt` with documented custom build
files, but it keeps the manifest, fetch, package, target wrappers, CMake consumer
modules, README, workflow, and artifact layout unless a reviewed exception is
recorded.

## Explicit target wrappers

Target wrappers remain explicitly named because maintainers should be able to
find a command without reading a workflow. Their content must be minimal:

    #!/usr/bin/env bash
    # SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    # SPDX-License-Identifier: MIT
    set -euo pipefail

    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    exec "${repo_root}/scripts/build-native-target.sh" <dependency> <target> "$@"

They must not contain:

- Android NDK versions;
- Android API levels;
- complete Docker image tags;
- GitHub runner labels;
- Visual Studio generator names;
- `CMAKE_MSVC_RUNTIME_LIBRARY` values;
- duplicated configure/build/install/package sequences.

Those values come from `config/native-builds.yml` and shared executors.

## Manifest contract

`manifest.yml` should contain at least:

    name: example
    version: 1.2.3
    release: example-1.2.3
    build_system: cmake
    source:
      type: git
      url: https://example.invalid/example.git
      tag: v1.2.3
    cmake:
      package: Example
      imported_target: Example::Example
    artifact:
      include:
        - example.h
      libraries:
        - example
      archives:
        - example-linux-x86_64.tar.gz
    dependencies: []
    targets:
      - linux-x86_64

The effective release field is updated by release automation before the release
tag is created. Artifact names must exactly match package output and workflow
upload names.

Library-specific target exceptions belong in `config/native-builds.yml`, not in
this manifest when they are operational platform policy. For the next release,
minizip is the documented Android API 24 override while the default remains 23.

## CMake wrapper contract

The dependency root `CMakeLists.txt` must:

- include `cmake/TotalCrossWindowsStaticRuntime.cmake` before `project()` when it
  can build with MSVC;
- use an immutable upstream source pin;
- allow a local source-directory override to avoid downloading during focused
  development;
- build static artifacts unless the manifest explicitly documents otherwise;
- install headers and libraries under standard install directories;
- propagate static runtime policy to nested upstream CMake projects when needed;
- avoid modifying the upstream checkout in place when a generated copy is safer;
- expose focused options rather than inheriting unrelated upstream defaults;
- produce an install tree usable by `package-artifact.sh`.

Do not encode target runners, Docker images, or release tags in CMake.

## Fetch contract

`fetch.sh` downloads release assets and stages them under:

    local/<platform>/<arch>

It should accept consistent options:

    --platform
    --arch
    --release-tag
    --github-repo
    --github-token-env
    --dest

It must:

- use the `deps.yml` release pin when no explicit release tag is supplied;
- never query “latest release” for normal dependency resolution;
- avoid printing token values or authenticated URLs;
- validate that the requested archive exists;
- extract atomically where practical;
- leave a concise manifest recording dependency, effective release, platform,
  architecture, and source asset;
- succeed without redownloading when the correct staged artifact is already
  complete.

## CMake consumer modules

`AutoFetch<Package>.cmake` must:

- locate its dependency directory from `CMAKE_CURRENT_LIST_FILE`;
- identify platform and architecture deterministically;
- derive the default release from `deps.yml` through the shared release helper;
- honor an explicit CMake variable or environment override for release handoff;
- skip fetching when the expected headers and library already exist;
- call `<dependency>/fetch.sh` when artifacts are missing;
- set the directory variable expected by `Find<Package>.cmake`.

`Find<Package>.cmake` must:

- search only the depot-tools staged directory by default;
- avoid silent system or package-manager fallback;
- define a stable imported target;
- report the resolved library and include directory concisely;
- fail clearly when the artifact layout is incomplete.

## Package contract

`package-artifact.sh` receives:

    <build-dir> <install-dir> <platform>/<arch>

It creates an archive whose contents are:

    <dependency>/<platform>/<arch>/include/
    <dependency>/<platform>/<arch>/lib/
    <dependency>/<platform>/<arch>/manifest.txt

The manifest should record at least:

- dependency version;
- effective release when available;
- platform and architecture;
- build configuration;
- relevant compatibility flags;
- source revision;
- compiler or toolchain identity when practical.

Packaging must be deterministic enough that repeated builds do not include
unrelated timestamps, absolute workspace paths, or generated caches when those
can be excluded.

## README contract

Each dependency README explains:

1. what upstream project is wrapped and why;
2. upstream version and license;
3. supported targets;
4. local build examples using explicit target scripts;
5. artifact layout and names;
6. direct `fetch.sh` usage;
7. CMake consumer usage through auto-fetch, `find_package`, and imported target;
8. dependency relationships and release-pin behavior;
9. known platform exceptions;
10. focused validation commands.

## Workflow contract

Each dependency has one workflow:

    .github/workflows/<dependency>.yml

It accepts `operation` with:

- `build` as default;
- `release`;
- `force-release`.

The workflow delegates target selection, configuration resolution, build command
construction, release metadata, and GitHub release checks to shared scripts. It
does not duplicate platform matrices already derivable from central
configuration.

A release updates `<dependency>/manifest.yml` and `deps.yml`, commits those
values, creates the effective tag on that commit, then creates or updates the
GitHub Release with the exact declared assets.

## Dependency graph contract

Record true build dependencies separately from stack co-scheduling.

Examples:

- `minizip` depends on `zlib`;
- `minizip-ng` and `libpng` depend on `zlib-ng`;
- Skia depends on the configured repository zlib-ng and libpng prebuilts;
- libjpeg and libjpeg-turbo may share the graphics stack without being Skia
  dependencies until the build actually consumes them.

The graph must be acyclic and validated. Stack ordering is generated from the
graph rather than copied into multiple workflows.

## Validation before handoff

Run the smallest applicable checks:

    python3 tools/new-native-dependency.py check <dependency>
    python3 tools/check-copyright.py
    bash -n <dependency>/fetch.sh <dependency>/scripts/*.sh
    python3 scripts/native-build.py validate
    cmake -S <dependency> -B <focused build dir> -G Ninja
    cmake --build <focused build dir>
    cmake --install <focused build dir> --prefix <focused install dir>
    bash <dependency>/scripts/package-artifact.sh ...
    git diff --check

At an operation-family checkpoint, also validate one real CMake consumer fixture
that auto-fetches, finds, and links the imported target without selecting a
system library.

## Completion checklist

A dependency is not complete until:

- the standard directory exists;
- source and license are documented;
- every published target has an explicit wrapper;
- local focused build and package work;
- fetch is idempotent;
- CMake auto-fetch and imported target work;
- manifest archive names match actual output;
- central target/library/stack configuration is updated;
- one workflow supports build, release, and force-release;
- `deps.yml` contains the effective release after publication;
- changed-file header, syntax, and diff checks pass;
- generated build output is not committed.
