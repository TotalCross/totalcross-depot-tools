<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Centralize native builds and release orchestration — history

## Milestone 1 baseline (2026-07-19)

The baseline is reproducible from the checkout with:

    python3 scripts/inventory-native-build-orchestration.py --format json

At revision `6c911bdb405d6533f63bafd8801eaa2150c45dcf`, it reported 15 library
manifests and 39 workflow files. Its complete machine-readable output covers
each manifest's current release and archive names, each workflow's triggers,
inputs, jobs, matrix jobs, reusable-workflow use, and uploaded artifact names.
The digest and compact counts are recorded in the matching evidence JSONL entry.

Every one of the 15 libraries has a matching `build-<library>.yml` and
`release-<library>.yml` pair. `build-qrcode-common.yml` is an additional
reusable implementation for qrcode variants; `build-dependency-consumers.yml`
is a consumer routing workflow. Individual release workflows take `dry_run` and
have `build` then `release` jobs. The graphics stack currently has `validate`,
zlib, zlib-ng, minizip, minizip-ng, libpng, libjpeg, libjpeg-turbo, skia, and
`publish` jobs. The small-libraries stack has `validate`, qrcode, qrcodegen,
axtls, mbedtls, and vcruntime jobs.

Skia currently has seven top-level jobs: `prepare-skia-sources`, Linux,
Android, WebAssembly, Apple, Windows, and release-asset packaging. Linux and
Windows are matrix jobs; the inventory preserves this topology for the later
parallelism check.

The inventory found policy literals in 13 files for Android API, 19 for the NDK
version, 2 for fully composed Linux image tags, 12 for the Visual Studio
generator, and 14 for `CMAKE_MSVC_RUNTIME_LIBRARY`. It excludes generated
`__pycache__` files and the inventory's own search patterns.

Release behavior is currently rooted in
`.github/scripts/latest-release-tag.sh` and
`.github/scripts/next-release-tag.sh`: a base
`<dependency>-<version>` is followed by `-r<N>` after matching tags exist.
Metadata pinning and release preparation remain in the `.github/actions` and
`.github/scripts` helper paths listed by the inventory.

## Milestone 2 central configuration and resolver (2026-07-19)

`config/native-builds.yml` is now the operational policy source. It defines one
Linux image version, Android NDK/API defaults, Windows generator/runtime policy,
Apple and Web runners, the published targets, all 15 libraries, true dependency
edges, and the `graphics` and `others` co-scheduling groups.

`scripts/native-build.py` is deliberately standard-library only. Its restricted
YAML reader accepts the checked-in policy syntax and its validator rejects
missing references, unknown keys, cycles, duplicate stack members, invalid or
unsupported overrides, and complete image tags in target overrides. The CLI
provides `validate`, `show`, `list-targets`, `graph`, and `plan`; it resolves
policy but does not invoke a build.

The 12 focused tests in `scripts/tests/test_native_build.py` cover Linux image
composition, Android defaults and the minizip API 24 exception, central Windows
policy, error cases, dependency ordering, and the absence of false dependency
edges caused by stack membership. The exact command and input digests are in the
Milestone 2 evidence record.

## Milestone 3 shared execution path (2026-07-19)

`scripts/build-native-target.sh` resolves one CMake library/target, derives
platform CMake arguments and dependency directories, prepares Android NDK
variables or QEMU when needed, and delegates the actual sequence to
`scripts/build-cmake-multi.sh`. It writes complete build output to a target log
and emits only a compact JSON result with artifact and log paths. `--dry-run`
supports inspection without creating a build directory, while
`--dependency-dir` supplies a controlled local dependency override for an
offline or handoff build.

The composite `build-native-library` action now invokes the same low-level
script instead of maintaining its own configure/build/test/install/package
here-document. The lower-level script now fails its generated command sequence
immediately and honors its requested configuration.

The ten zlib wrappers for published targets contain only delegation identity and
forwarded options. `scripts/validate-native-wrappers.py` confirms both that
shape and the absence of NDK/API/image/generator/runtime literals. The obsolete
non-published Android armv7 and macOS x86_64 zlib wrappers were removed in line
with the published-target policy.

Focused dry-run tests cover minizip and libpng dependency paths, the minizip
Android API 24 override, SLJIT tests, and Windows `/MT` arguments. Real
temporary macOS-arm64 builds succeeded for zlib, minizip, SLJIT, and libpng,
with each archive inspected for the expected include/lib/manifest layout. A
temporary CMake consumer configured, linked, and ran against the generated zlib
installation. Windows, Android, and Docker/QEMU execution were not available on
the host; their resolved arguments remain tested without execution.
