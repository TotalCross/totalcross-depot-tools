<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Skia Vulkan consumer header contract — editorial report

## Editorial Summary

Metadata-driven Skia consumers can compile Vulkan-aware public headers through
`Skia::Skia` alone. Vulkan remains three separate facts: `SK_VULKAN` is a
compile definition, bundled Vulkan headers are a public include requirement,
and the pinned static archive has no mandatory Vulkan loader link requirement.

## Original Plan versus Actual Outcome

The planned consumer-contract-only fix was sufficient. Direct inspection of the
published r8 development ZIP confirmed that packaging already contains the core
and Android Vulkan headers, so no Skia rebuild, release, or staging change was
needed.

## What Changed

`SkiaConsumerRequirements.cmake` now classifies compile definitions and public
include requirements independently. `FindSkia.cmake` resolves the bundled
Vulkan include root, validates managed artifacts, and exposes it transitively.
Focused tests cover feature ON/OFF, supported metadata platforms, incomplete
managed bundles, bounded external overrides, duplicate suppression, and the real
`GrBackendSurface.h` include chain. Consumer documentation states the boundary
between bundled build-time headers and an application Vulkan runtime.

## Decisions and Trade-offs

Strict missing-header failure applies only to repository-managed,
metadata-driven artifacts. External and legacy overrides retain their bounded
compatibility behavior. Vulkan loader discovery remains absent because the
pinned archive does not establish that link dependency.

## Unexpected Problems and Discoveries

Concurrent `skia/fetch.sh --install-dev` invocations share a temporary filename;
one Linux fetch reached a `mktemp` collision and was retried sequentially. This
did not affect repository files and is outside the consumer-header goal. Docker
was unavailable, so Linux compilation used a temporary self-contained Zig cross
compiler and produced an x86-64 ELF object.

## Validation and Measurable Results

Pure CMake classification passed. Eleven Python configuration tests passed.
The published macOS r8 artifact compiled the Vulkan header object and linked the
existing Metal smoke executable with Metal and Foundation from `Skia::Skia`.
The published Linux x86-64 r8 artifact and metadata compiled the same source to
an ELF relocatable object without an external Vulkan SDK. The published ZIP
contains both required Vulkan headers.

The delivered logical slices are `3a5272c` (production contract), `b8a7435`
(regression coverage), and `6b99a23` (consumer documentation and final report).

## Useful Evidence and Examples

The generated macOS and Linux compile flags contain
`skia/local/include/third_party/vulkan`. The Linux object identifies as ELF
x86-64; the macOS object identifies as Mach-O arm64. The macOS generated link
line contains `-framework Metal -framework Foundation` with no consumer-side
framework declaration.

## Limitations, Remaining Work, and Open Questions

The Linux regression is compile-only, as intended for the public-header
contract; it is not a Linux runtime execution or full static link. Applications
that directly load Vulkan still own their runtime/loader integration. The
fetch-script concurrent dev-bundle temporary-file collision may merit a separate
future issue.

## Possible Article Angles

- Why static-library metadata must describe compile, include, and link contracts
  separately.
- Turning an environment-dependent Vulkan header failure into a deterministic
  managed-artifact validation.

## Suggested Narrative

Start with the surprising effect of correctly propagating `SK_VULKAN`: it made
Skia's public header switch from a repository-relative include to an angle-bracket
Vulkan include. Then show how the artifact was already self-contained and only
the imported target was missing the include relationship.

## Claims Requiring Human Review

No claim requires release-owner review because no artifact or release state was
changed. The separate conclusion that applications need no Vulkan loader should
remain scoped to consuming the pinned Skia static archive, not to application
code that directly invokes Vulkan.
