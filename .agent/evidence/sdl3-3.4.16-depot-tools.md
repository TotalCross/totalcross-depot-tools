<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL3 3.4.16 evidence

- 2026-09-04, source contract: `release-3.4.16` resolved to
  `fa2c02bb6e21974a89ea9824bc53c9932abe5f9c`; codeload archive SHA-256
  `d246967187a4f37cc850608dbaf5cff9d1df4d731259903d25539755cdfcc657`.
- 2026-09-04, Milestone 1: canonical seven-target graph and unpublished
  `others` stack membership were added without changing `deps.yml`.
- 2026-09-04, Milestone 2 host proof: Linux x86_64 built and installed SDL3;
  the package recorded X11, Wayland, KMSDRM, dummy, offscreen, Vulkan, OpenGL,
  and OpenGL ES. Two archive writes matched SHA-256
  `918025d233f719fb1969f5f7d02405d7e39262b58a2e06e24b8521e8809bccbe`.
  Fresh CONFIG consumers linked and ran against both `SDL3::SDL3` and
  `SDL3::SDL3-static`. Logs: `/tmp/sdl3-m2-host.log` and
  `/tmp/sdl3-m2-consumer.log`.
- Limitation: Docker, MSVC, PowerShell, and macOS are unavailable on this Linux
  host, so cross-platform runtime validation remains a CI checkpoint before
  publication.
