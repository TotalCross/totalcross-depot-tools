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
