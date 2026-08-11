<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Skia prebuilt link contract editorial report

## Editorial Summary

Implementation and locally available validation are complete. The
metadata-driven imported target closes the macOS ARM64 regression against both
the exact r7 archive and a freshly built archive. Cross-OS GitHub workflow lanes
remain an explicit pre-release gate; no publication was authorized or performed.

## Original Plan versus Actual Outcome

The plan expected published `gn args` and `gn desc` diagnostics to be primary
evidence. Those files exist but contain a source-root error. The effective
overrides, generated build graph, compile commands, pinned Skia source, and
release archive symbols were sufficient to complete the investigation, and the
metadata-emission slice corrects the diagnostics invocation.

## What Changed

Four logical commits now emit deterministic SHA-bound metadata, publish and
fetch validated archive/sidecar pairs, and derive `Skia::Skia` link requirements
from the package metadata. The final implementation correction preserves the
repository dependency choice at artifact packaging and propagates the artifact
platform definition to consumers. A strict managed package cannot expose a
mismatched pair; current r7 remains a warned legacy package until a new release
activates the metadata requirement.

## Decisions and Trade-offs

The metadata records graphical features from effective GN state and the actual
repository zlib/libpng selections from the shared build boundary. Vulkan and
OpenCL are not mapped to loader libraries because the current `Skia` library
graph does not require them. Unsupported enabled ANGLE, Dawn, Direct3D, or
unmanaged system dependency choices fail rather than guess.

## Unexpected Problems and Discoveries

The r7 diagnostics root bug, GN target-local argument scope, and the absence of
a Vulkan/OpenCL loader link item are the material findings. Linux system
Freetype and Fontconfig are existing external runtime requirements, not
dependencies added by this work. The local target-family sync also encountered
recoverable upstream HTTP 429 responses.

## Validation and Measurable Results

The original macOS ARM64 Metal link failure was reproduced against the exact r7
archive, then the target-only fixture linked successfully as ARM64 Mach-O.
Fresh macOS, iOS, and iOS Simulator builds emitted validated sidecars; the iOS
XCFramework packaged; and the principal TotalCross consumer produced ARM64
`libtcvm.dylib` through an explicit local checkout override. Five generator,
four paired-fetch, seven package-integrity, and the expanded synthetic resolver
suite pass. Full cross-platform release workflow execution is not claimed.

## Useful Evidence and Examples

See `.agent/evidence/skia-prebuilt-link-contract.jsonl` for the release hash,
task-specific paths, and concise feature mapping.

## Limitations, Remaining Work, and Open Questions

Linux, Android, Windows, and WebAssembly runner execution, release publication,
and downstream pin adoption remain. These are deliberate CI/authorization
gates, not unimplemented package behavior.

## Possible Article Angles

Static archives need an explicit package-level link contract because build
systems do not preserve transitive SDK dependencies inside archive files.

## Suggested Narrative

Begin with the concrete Metal failure, show how effective GN state becomes a
versioned sidecar, and finish with a single imported-target consumer interface.

## Claims Requiring Human Review

The cross-platform mapping and release-readiness claim require review of the
full GitHub Actions matrix before external publication.
