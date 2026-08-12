<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Complete Skia Vulkan consumer header contract — completed state

Status: complete; all acceptance criteria are proven.

Last logical commit: `b8a7435` (`test(skia): cover Vulkan consumer header
contract`) in a detached checkout.

Active paths:

- `skia/README.md`
- `docs/CONSUMING_DEPOT_TOOLS.md`
- `.agent/plans/complete-skia-vulkan-consumer-header-contract.md`
- `.agent/reports/complete-skia-vulkan-consumer-header-contract-editorial.md`
- `.agent/plans/complete-skia-vulkan-consumer-header-contract.md`

Next concrete action: none. The repository is ready for review and a separately
authorized future depot-tools release.

Focused evidence completed:

- `stage_dev_subset` copies the complete upstream `include/` tree.
- ignored `skia/local` contains `vulkan_core.h` and `vulkan_android.h`.
- current `FindSkia.cmake` adds `SK_VULKAN` but no Vulkan include root.
- current link classifier deliberately adds no Vulkan loader/library.
- Docker is not available on this macOS host.
- compile/include/link classification and 11 configuration tests pass.
- production contract committed as `3a5272c` after focused header and diff
  validation.
- test contract committed as `b8a7435` after focused header and diff validation.
- published r8 ZIP contains `vulkan_core.h` and `vulkan_android.h`.
- native macOS header compile and Metal link pass against r8.
- Linux x86-64 ELF header object compile passes against r8 using temporary Zig.
- final pure CMake classification and all 11 configuration tests pass.
- release manifests, tags, `deps.yml`, downstream pin, and TotalCross Vulkan
  workaround searches are unchanged/empty.

Deferred validation: Linux runtime execution and a full TotalCross distribution
build were not required for this public-header contract; the Linux-target ELF
compile and real macOS compile/link directly exercise the changed interface.

Active decisions: preserve link behavior; strictly validate headers only for
managed metadata-driven libraries; do not alter staging or release metadata
without contradictory artifact evidence.

Blockers: none. Remaining limitation: application-level Vulkan runtime/loader
integration stays outside the Skia prebuilt consumer contract.

Deliberately out of scope: all existing ignored/untracked dependency `local/`
directories, releases, tags, pushes, `deps.yml`, downstream pins, and TotalCross
consumer workarounds.

Review command:

    git log --oneline cc9932f..HEAD && git diff cc9932f..HEAD -- skia docs .agent
