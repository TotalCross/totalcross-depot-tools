<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL3 3.4.16 onboarding editorial report

## Editorial Summary

SDL3 3.4.16 is ready for the explicit publication gate as an independently
buildable, fetchable, packageable, and consumable native dependency.

## Original Plan versus Actual Outcome

Milestones 1–5 were completed. Publication was deliberately not entered because
the plan requires separate explicit authorization and cross-platform evidence.

## What Changed

The repository now has the canonical `sdl3` layout, immutable source metadata,
seven-target central graph, static wrapper/package, strict fetch and CMake
modules, consumer fixture, shared-operation workflow, and usage documentation.

## Decisions and Trade-offs

The package retains only the shared desktop window/context surface, uses libc to
avoid allocator collisions, and keeps upstream relocatable CMake exports rather
than reproducing platform link libraries in consumers.

## Unexpected Problems and Discoveries

The host initially lacked SDL's required X11/Wayland development headers. After
installing environment-only prerequisites, required Linux backends configured
without weakening the profile. SDL3 exports includes through `SDL3::Headers`,
while `SDL3::SDL3` aliases `SDL3::SDL3-static` in a static-only package.

## Validation and Measurable Results

Linux x86_64 built with X11, Wayland, KMSDRM, dummy, offscreen, Vulkan, OpenGL,
and OpenGL ES. Two packages matched SHA-256
`918025d233f719fb1969f5f7d02405d7e39262b58a2e06e24b8521e8809bccbe`.
Fresh module, CONFIG, generic, explicit-static, and MBD-shaped consumers built;
42 focused orchestration tests passed; all seven lanes were planned.

## Useful Evidence and Examples

The consumer fixture demonstrates both target names and module/CONFIG discovery.
The MBD proof used immutable revision
`c82ae744016f447fccb78087eed89f11b3eec0ff` with its SDL3 CPU configuration.

## Limitations, Remaining Work, and Open Questions

Windows, macOS, and Linux cross-architecture builds were unavailable locally.
Their artifacts plus Windows `/MT`, architecture, allocator, and link checks and
macOS framework metadata remain mandatory before publication.

## Possible Article Angles

Possible themes are deterministic native dependency packaging, strict CMake
package confinement, and safe incremental onboarding before first publication.

## Suggested Narrative

Present the immutable source contract, central target policy, static feature
profile, reproducibility proof, consumer confinement, then the gated release.

## Claims Requiring Human Review

Do not claim the six unexecuted cross-platform lanes are green or that SDL3 is
published. Those claims require authorized workflow and release evidence.
