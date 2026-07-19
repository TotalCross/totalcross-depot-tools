---
name: add-native-dependency
description: Add a new native library to totalcross-depot-tools using the standard manifest, CMake wrapper, fetch/package modules, explicit target scripts, central graph configuration, one build/release workflow, documentation, and focused consumer validation.
---

# Add a native dependency

Follow `docs/DEPENDENCY_STANDARD.md`. Use the scaffold to avoid rediscovering filenames and contracts, but never treat generated TODOs as a complete integration.

## Gather exact inputs

Determine and verify:

- repository directory name;
- upstream URL, immutable version/tag/commit, and license;
- CMake package and imported target names;
- installed headers and static library names;
- published targets;
- true build dependencies on existing depot-tools libraries;
- stack membership (`graphics` or `others`);
- tests and target-specific overrides.

Read only one or two representative dependencies selected by similarity. Use a dependency with the same build system and, when relevant, one with the same dependency shape. Do not inspect every library.

## Create the skeleton

Run from the repository root:

    python3 tools/new-native-dependency.py create \
      --name <directory> \
      --package <CMakePackage> \
      --version <version> \
      --source-url <url> \
      --source-tag <immutable tag or commit> \
      --imported-target <Package::Target> \
      --library-name <archive base name> \
      --stack <graphics|others> \
      --targets <explicit targets>

Review created files and executable bits immediately.

## Complete the implementation

1. Replace all scaffold TODOs.
2. Implement a static CMake wrapper with local source override and standard install tree.
3. Include the Windows runtime policy before `project()` and propagate it to nested upstream projects when needed.
4. Implement `fetch.sh` with the standard release, repository, token-environment, destination, platform, and architecture interface.
5. Implement deterministic packaging and a concise artifact manifest.
6. Implement auto-fetch and find modules that resolve only the staged depot-tools artifact.
7. Keep explicit target wrapper names, but make each delegate only dependency and target identity to the shared executor.
8. Add the library, targets, dependencies, overrides, and stack membership to central configuration.
9. Add one workflow with `build`, `release`, and `force-release` operations. Do not add separate build and release workflows.
10. Add the initial compatible pin to `deps.yml` only when the corresponding effective release is ready to exist.
11. Complete the library README with build, fetch, artifact, CMake, dependency, and validation examples.

## Validate proportionally

Start with:

    python3 tools/new-native-dependency.py check <directory>
    bash -n <directory>/fetch.sh <directory>/scripts/*.sh
    python3 scripts/native-build.py validate
    git diff --check -- <directory> config/native-builds.yml .github/workflows/<directory>.yml deps.yml

Run one host-compatible target script and inspect the archive layout. Then configure a tiny CMake consumer that invokes auto-fetch, calls `find_package`, links the imported target, and proves the resolved paths are inside the depot-tools checkout.

At the operation-family checkpoint, run the library workflow in `build` mode for every directly affected target family. Do not publish during onboarding validation.

## Commit boundaries

Use the `logical-commits` skill. Suitable slices are:

1. scaffold and central metadata contract;
2. build/package implementation and focused tests;
3. fetch/CMake consumer integration;
4. workflow and release dry-run;
5. documentation and final validation.

Combine slices when the dependency is small and each combined commit remains independently reviewable.
