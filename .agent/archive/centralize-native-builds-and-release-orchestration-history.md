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

## Milestone 4 onboarding and consumption contract (2026-07-19)

The repository already contained the dependency standard, consumer guide,
scaffold lifecycle tests, repository skills, and the adopted AGENTS/ExecPlan
guidance from earlier logical commits. This milestone completed their remaining
integration surface instead of duplicating those documents or replacing newer
guidance with the stale proposal copy.

`tools/check-copyright.py` now accepts `--paths` and `--staged`, preserving its
repository-wide default. The focused test covers both a no-op staged set and a
single selected file. `tools/new-native-dependency.py create --dry-run` reports
the exact scaffold without writing it, and its target adapter now derives target
names and archive suffixes from `config/native-builds.yml`.

The distributable `consumer-skill/adopt-totalcross-depot-tools` package includes
the skill metadata and a TotalCross behavior reference. A temporary consumer
used its pinned-bootstrap pattern with `zlib-1.3.1-r3`, fetched the published
macOS arm64 zlib artifact, configured a CMake target through `FindZlib.cmake`,
linked it, and executed it successfully.

## Milestone 5 operation workflow contract (2026-07-19)

`.github/workflows/native-library-operation.yml` contains the common CMake
operation contract. Its planning job invokes `scripts/native-build.py plan`,
resolves the target matrix through the central resolver, fetches only declared
dependencies at their `deps.yml` pins, delegates builds to
`scripts/build-native-target.sh`, verifies Windows static runtime archives, and
uploads the existing artifact identities. Apple targets remain on one runner;
their configured XCFramework composition is handled by
`scripts/package-native-ios-xcframework.sh`.

Each library now has `.github/workflows/<library>.yml` with reusable and manual
operation inputs plus machine-readable result outputs. The CMake libraries call
the common workflow. VCRuntime and Skia preserve their existing specialized
implementations behind equivalent planning and summary adapters, avoiding a
change to the custom Windows packaging or Skia parallel topology.

The new release-related inputs are deliberately build-only placeholders. The
legacy build/release pairs are retained pending the later remote equivalence and
obsolete-path gates; no remote workflow was dispatched and no release behavior
was changed in this milestone.

## Milestone 6 individual release idempotence (2026-07-19)

`scripts/native-release.py` is the release-state contract. It reads the
bundle's effective pin, preserves the base/`-rN` suffix rule, inspects release
and tag snapshots, selects force-release suffixes, prepares manifest and bundle
metadata, and verifies declared assets. Fixture tests cover existing non-draft
releases, drafts, tags without releases, suffix gaps, metadata commits without
a tag, mismatched metadata, and concurrent rechecks.

The operation workflows now short-circuit an existing release before build work.
When publication is required, they validate downloaded assets, recheck under a
per-library concurrency group, write and commit metadata before creating a tag,
then publish the release. The shared publication action also serves VCRuntime
and Skia. No remote workflow, tag, push, or publication was executed.

## Milestone 7 selective stack planning (2026-07-19)

`scripts/native-stack.py` turns a graphics or others request into a deterministic
plan. It follows only real dependency edges, distinguishes a selected in-run
dependency from an external pinned release, groups selected CMake libraries by
compatible target/runner lane, and exposes a topological publication order.
Release mode excludes existing releases; force-release selects every requested
member with the next allowed per-library suffix.

The graphics and others shell scripts and workflows all call that planner.
Seven focused scenarios prove all-existing, one-missing leaf, local dependency
handoff, unrelated stack member, force-release, lane grouping, and recovery
cases. No remote lane or publication was dispatched.

## Milestone 8 Skia parallel topology (2026-07-20)

The graphics plan now includes an explicit 11-target Skia DAG. Linux and Android
may continue matching standard lanes; Apple prerequisites feed macOS, iOS, and
iOS Simulator independently; only Windows x64 continues a Windows lane; and
WebAssembly has only source preparation as a prerequisite. The planner records
only zlib-ng and libpng as Skia dependencies.

Validation compares the generated families with the seven-job baseline inventory
and fails if a Skia target depends on any other Skia target. This is a local DAG
contract, not a dispatched platform build.

## Milestone 9 cleanup and remote release gate (2026-07-21)

The final migration inventory contains 15 libraries and 27 workflows. Thirteen
superseded CMake build/release pairs, the old graphics/small-library stacks, the
duplicate `.github/native-build-targets.yml`, and obsolete release helpers were
removed. `build-dependency-consumers.yml` now calls operation workflows. Every
operation entry workflow owns narrow pull-request filters and defaults that
event to `build`.

Skia and VCRuntime retain `build-skia.yml` and `build-vcruntime.yml` as
specialized reusable implementations, while `skia.yml` and `vcruntime.yml`
remain their only operation entry points. The final Skia run `29868514126`
passed all 11 targets. The VCRuntime release run `29871061155` returned
`existing-release` for `vcruntime-14` and skipped build and publication.

The current GitHub CLI no longer exposes release URLs and assets from `gh
release list`, so release inspection now uses the paginated Releases API.
Specialized planners export `GH_TOKEN` before querying that API. The maintained
policy validator reports zero duplicated policy literals outside its central
and runtime allowlist.
