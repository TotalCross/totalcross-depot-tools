<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# SDL2 2.32.8 onboarding report

## Editorial Summary

SDL 2.32.8 is integrated as the repository-facing `sdl2` dependency through the
standard native build, package, fetch, CMake, workflow, and documentation
contracts. The implementation stops at the explicit publication gate.

## Original Plan versus Actual Outcome

All five non-publication milestones were implemented. Seven desktop targets and
assets are declared in central policy. macOS ARM64 was built, packaged, fetched,
and consumer-tested locally. Linux and Windows lanes were resolved and validated
structurally but could not execute on the available host.

## What Changed

- Added the standard `sdl2/` dependency with version, revision, license, targets,
  minimal wrappers, and shared configuration.
- Added an immutable SHA-256-verified upstream build, static PIC policy,
  SDL2main exclusion, license installation, relocatable upstream exports, and
  deterministic packaging.
- Added checksum-pinned atomic fetch, release-pin resolution, strict depot-only
  `FindSDL2.cmake`, auto-fetch, and a real consumer fixture.
- Added the shared desktop build/release workflow and full usage documentation.

## Decisions and Trade-offs

Upstream SDL2 config exports are preserved because they carry platform system
links correctly. Repository code verifies their imported paths instead of
reimplementing platform framework and library lists. The source download uses a
resolved revision archive plus SHA-256 rather than trusting a movable tag.

The dependency is in stack `others`, builds static PIC only, omits SDL2main, and
does not add mobile or WebAssembly targets. Fetch without a default release pin
fails clearly until publication is authorized.

## Unexpected Problems and Discoveries

The native policy-literal validator rejected a repeated MSVC runtime literal.
The wrapper was corrected to inherit the value established by the central
Windows runtime module, and artifact manifests now record the resolved value.

Moving the first CMake build directory made its cache non-reusable because CMake
records absolute build paths. The evidence was preserved and a fresh build
directory was used for the corrected validation.

The first `others` stack build failed because stack planning loaded publication
metadata even for build-only operations. Build planning now reads manifest
identity independently. Initial release planning reads the same manifest identity
and the authorized metadata-preparation step creates the mandatory `deps.yml`
entry before the release tag is created.

## Validation and Measurable Results

The macOS archive contained 96 entries and no shared library or SDL2main. Upstream
CMake metadata was relocatable and supplied Apple framework transitive links.
The final repeated archive hash was identical on two package runs. A consumer
linked only `SDL2::SDL2`, called `SDL_GetVersion`, and ran successfully.

Fetch downloaded one checksum-pinned local handoff and reused it on the second
call. An incomplete depot root failed even with a valid SDL config on the host
prefix. Central configuration, the seven-target plan, seven dry-run commands,
release asset contract, shell syntax, headers, policy literals, and focused
orchestration tests passed.

After the stack-planner correction, `others build` produced seven sdl2 lanes and
the 52 focused build, stack, and release regression tests passed.

After the initial-release correction, release selection produced
`sdl2-2.32.8` as `build-required` without a pre-existing pin. Metadata
preparation inserted the complete dependency entry in an isolated test root, and
55 focused regression tests passed without changing repository `deps.yml`.

## Useful Evidence and Examples

Compact evidence and log paths are recorded in
`.agent/evidence/add-sdl2-2.32.8.md`. Consumer usage is documented in
`sdl2/README.md` and exercised by `sdl2/cmake/tests/consumer`.

## Limitations, Remaining Work, and Open Questions

The available host could not execute Linux Docker lanes or Windows MSVC lanes.
Those builds, Linux backend capability reports, and the Windows `/MT` archive
verifier remain required CI evidence before publication.

Publication requires explicit authorization. No release, tag, push, checksum
publication metadata, or compatible `deps.yml` pin exists yet. After publication,
one real default-pin auto-fetch and consumer run remains required.

## Possible Article Angles

- Preserving rich upstream static-link metadata while enforcing depot-only
  resolution.
- Reproducible native dependency packaging across platform-specific filenames.
- Separating publication readiness from publication authority.

## Suggested Narrative

Start with the naming boundary (`sdl2` versus upstream `SDL2`), explain the
immutable static build and upstream export preservation, then show how strict
fetch/find validation prevents accidental host dependency selection. Close with
the explicit publication gate and platform evidence still needed from CI.

## Claims Requiring Human Review

- Confirm Linux image packages enable the desired SDL X11/Wayland backend set.
- Confirm all three Windows artifacts pass the repository `/MT` verifier.
- Confirm all seven workflow lanes build before authorizing initial publication.
