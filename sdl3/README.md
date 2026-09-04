<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL3

This directory will wrap sdl3 at https://github.com/libsdl-org/SDL.git, revision release-3.4.16.

## Published targets

- linux-x86_64
- linux-armv7l
- linux-aarch64
- windows-x86
- windows-x64
- windows-arm64
- macos-arm64

## Build, fetch, and consume

Run scripts/build-<target>.sh for a published target. Fetch artifacts into
local/<platform>/<arch>, include cmake/AutoFetchSDL3.cmake, call
tcvm_auto_fetch_sdl3, find_package(SDL3 REQUIRED), and link
SDL3::SDL3.

## Completion work

TC_DEPOT_SCAFFOLD_TODO: identify upstream license and notices, implement build/package/
fetch/CMake/workflow behavior, add central configuration, validate a real
consumer, and update deps.yml only in the release operation. This scaffold never
publishes a release or updates deps.yml by itself.
