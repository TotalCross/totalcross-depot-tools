<!--
Copyright (C) 2026 Amalgam Solucoes em TI Ltda

SPDX-License-Identifier: LGPL-2.1-only
-->

# Changelog

All notable changes to the TotalCross axTLS distribution are documented here.

## Unreleased

### Security

- Corrected HMAC-SHA1 handling of keys larger than the SHA-1 block, avoiding
  the legacy fixed-buffer overwrite and applying the RFC 2104 key reduction.
- Added the checked `axtls_pbkdf2_sha1` API based on OpenBSD `libutil`, with
  overflow validation, secret-buffer cleanup and protected output on failure.

## 2.1.5 - 2026-07-10

### Added

- Reproducible static-library builds from the verified upstream axTLS 2.1.5
  archive, platform artifact packaging, repository-local discovery and
  artifact fetching.
- MD2 source support required by the TotalCross-compatible axTLS feature set.
- Per-SSL-context integration hooks for allocation, socket I/O, close, logging
  and abort handling. The hooks preserve native defaults for `ssl_ctx_new()`
  and support `ssl_ctx_new_with_port()` plus the RSA `*_with_port` helpers.
- CTest coverage for the portable hook ABI and its context-local state.

### Changed

- Patched the upstream source so allocation, socket operations and diagnostics
  are dispatched through the optional hook table without linking axTLS to
  TotalCross symbols.
- Added the TotalCross build configuration, dependency manifest, CMake
  auto-fetch/find modules and release workflows for published prebuilts.

### Fixed

- Injected a C99 `stdbool.h` compatibility header only for Windows MSVC builds
  and removed the older `crypto_misc.h` workaround from the functional patch.
