<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Skia prebuilt link contract editorial report

## Editorial Summary

Execution is in progress. Milestone 1 confirmed that the macOS ARM64 regression
is a missing prebuilt link contract and established the current cross-platform
feature mapping. No final implementation outcome or release readiness is yet
claimed.

## Original Plan versus Actual Outcome

The plan expected published `gn args` and `gn desc` diagnostics to be primary
evidence. Those files exist but contain a source-root error. The effective
overrides, generated build graph, compile commands, pinned Skia source, and
release archive symbols were sufficient to complete the investigation, and the
metadata-emission slice corrects the diagnostics invocation.

## What Changed

The working tree now contains a focused generator for deterministic, versioned,
SHA-bound CMake metadata plus integration at the shared static-artifact copy
boundary. This section will be reconciled after the logical commit.

## Decisions and Trade-offs

The metadata records both graphical features and external/bundled dependency
choices from the effective GN state. Vulkan and OpenCL are not mapped to loader
libraries because the current `Skia` library graph does not require them.

## Unexpected Problems and Discoveries

The r7 diagnostics root bug and the absence of a Vulkan/OpenCL loader link item
are the two material findings. Linux system Freetype and Fontconfig are existing
external runtime requirements, not dependencies added by this work.

## Validation and Measurable Results

The original macOS ARM64 Metal link failure was reproduced against the exact r7
archive. Three focused generator tests pass. No fixed consumer link is claimed
until the resolver milestone.

## Useful Evidence and Examples

See `.agent/evidence/skia-prebuilt-link-contract.jsonl` for the release hash,
task-specific paths, and concise feature mapping.

## Limitations, Remaining Work, and Open Questions

Artifact publication/fetch, metadata validation, dependency resolution,
synthetic package tests, real consumer links, documentation, and matrix closure
remain.

## Possible Article Angles

Static archives need an explicit package-level link contract because build
systems do not preserve transitive SDK dependencies inside archive files.

## Suggested Narrative

Begin with the concrete Metal failure, show how effective GN state becomes a
versioned sidecar, and finish with a single imported-target consumer interface.

## Claims Requiring Human Review

None are ready for external publication while execution remains incomplete.
