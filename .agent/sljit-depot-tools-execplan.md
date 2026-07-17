<!--
Copyright (C) 2026 Amalgam Solucoes em TI Ltda

SPDX-License-Identifier: LGPL-2.1-only
-->

# Add reproducible SLJIT static builds to totalcross-depot-tools

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, `Outcomes & Retrospective`, and `Editorial Report` must be kept up to date as work proceeds. Maintain this document in accordance with `.agent/PLANS.md` in the TotalCross repository.

This plan describes work in the separate `TotalCross/totalcross-depot-tools` repository. Do not implement it by editing `TotalCrossVM/deps/totalcross-depot-tools` inside a TotalCross checkout: that path is a generated or fetched dependency checkout and may contain untracked `local/` caches. Perform the implementation in a normal clone or worktree of the owning depot-tools repository, then consume its published release from TotalCross in a separate change.

## Purpose / Big Picture

After this change, TotalCross developers can fetch a pinned, reproducible SLJIT static library for the desktop targets already represented in depot-tools and for Android ARM64. A release contains the SLJIT headers, `libsljit.a` or `sljit.lib`, the upstream Simplified BSD license, and provenance identifying the exact upstream commit and build policy. A small native program proves on executable host targets that the library can generate, call, and free a function returning the sum of three integers.

The Android artifact is intentionally built even though the first TotalCross integration may leave Android JIT execution disabled. It targets `arm64-v8a`, NDK `28.2.13676358` (r28c), and API 23. The Windows artifacts must use the static Microsoft C runtime, `/MT`, for x86, x64, and ARM64. Every SLJIT build opts into its W^X allocator, which makes generated-code pages writable or executable at different times instead of requesting writable-and-executable pages simultaneously.

## Progress

- [x] (2026-07-17 20:26Z) Read `.agent/PLANS.md`, the depot-tools repository guidance, current dependency manifests, CMake modules, packaging scripts, and build/release workflows.
- [x] (2026-07-17 20:26Z) Inspected SLJIT upstream commit `3907e69005ba6e30b225000f24aaef3632f88347`, recorded its archive SHA-256, allocator options, architecture detection, Android cache-flush path, and Simplified BSD license.
- [x] (2026-07-17) Added the pinned `sljit/` dependency definition, owned CMake build, tests, documentation, and bundle entry.
- [x] (2026-07-17) Added artifact packaging, fetching, strict CMake discovery, and auto-fetch support.
- [ ] Added the Linux, Windows, Android, and macOS build workflow; GitHub Actions matrix execution is pending publication of the implementation commit.
- [ ] Prove `/MT` in every Windows archive and prove Android ARM64/API 23 metadata and linkability.
- [ ] Add the release workflow, publish the first complete release, and fetch every published asset into temporary destinations.
- [ ] Finalize the Editorial Report from the completed implementation and validation evidence.

## Surprises & Discoveries

- Observation: SLJIT does not publish numbered releases suitable for a semantic version pin at the time this plan was written.
  Evidence: upstream HEAD was `3907e69005ba6e30b225000f24aaef3632f88347` on 2026-07-17, and the repository exposed no release tag for this snapshot. The depot distribution therefore needs a date-based version plus an immutable commit and archive hash.

- Observation: upstream's root `CMakeLists.txt` is described by upstream as incomplete and builds the test executable, not an installable static-library package.
  Evidence: the file begins with that warning and directly compiles `sljit_src/sljitLir.c` into `sljit_test`. Depot-tools must own a small CMake wrapper rather than relying on upstream installation behavior.

- Observation: SLJIT's default executable allocator is enabled, but its stricter W^X allocator is disabled by default.
  Evidence: `sljit_src/sljitConfig.h` defaults `SLJIT_EXECUTABLE_ALLOCATOR` to 1 and `SLJIT_WX_EXECUTABLE_ALLOCATOR` to 0. The depot build must explicitly define `SLJIT_WX_EXECUTABLE_ALLOCATOR=1`.

- Observation: Android ARM64 is selected automatically by `__aarch64__`, and the W^X POSIX allocator discovers page size at runtime.
  Evidence: `sljit_src/sljitConfigCPU.h` maps `__aarch64__` to `SLJIT_CONFIG_ARM_64`; `sljit_src/sljitUtils.c` uses `sysconf(_SC_PAGESIZE)`. This is compatible in design with both 4 KiB and 16 KiB Android page sizes, although runtime support still requires a device test in the consuming project.

- Observation: compiling SLJIT for iOS would not establish usable JIT behavior for ordinary, non-jailbroken iOS applications.
  Evidence: upstream `sljitConfigInternal.h` states that the Apple instruction-cache invalidation path does not work on non-jailbroken iOS even though compilation succeeds. This release matrix excludes iOS rather than publishing a misleading archive or XCFramework.

## Decision Log

- Decision: publish snapshot version `20260717` under release tag `sljit-20260717`, pinned to upstream commit `3907e69005ba6e30b225000f24aaef3632f88347` and archive SHA-256 `f3e299647a610c537296a41d8866f1e7b664401c229e6cdb67a621250086efd9`.
  Rationale: the upstream repository has no numbered release for this revision. A date identifies the depot distribution while the full commit and hash provide immutable provenance. If packaging changes without changing upstream, use the repository's existing `-r2`, `-r3`, and later release-tag convention instead of silently replacing assets.
  Date/Author: 2026-07-17 / Codex

- Decision: compile `sljit_src/sljitLir.c` directly in a depot-owned `sljit/CMakeLists.txt` and install only its public headers.
  Rationale: upstream explicitly presents separate compilation of `sljitLir.c` as the library integration method, while its own CMake file is not an installation definition.
  Date/Author: 2026-07-17 / Codex

- Decision: define `SLJIT_WX_EXECUTABLE_ALLOCATOR=1`, keep `SLJIT_SINGLE_THREADED` disabled, enable `SLJIT_ARGUMENT_CHECKS`, and disable `SLJIT_DEBUG` and `SLJIT_VERBOSE` in distributed Release libraries.
  Rationale: W^X is required by the intended TotalCross JIT design; thread support is required by the VM; argument checks make invalid emitter calls fail deterministically; debug and verbose support are not needed in the release artifact. The imported CMake target must propagate the same public definitions so header declarations and library behavior remain consistent.
  Date/Author: 2026-07-17 / Codex

- Decision: keep Android at `ANDROID_PLATFORM=android-23` and publish only `android/arm64-v8a`.
  Rationale: `mmap`, `mprotect`, pthread synchronization, and ARM64 cache invalidation used by this build are available at API 23. Raising the minimum without evidence would unnecessarily reduce compatibility. API 24 is permitted only if an API-23 compile, link, or device execution failure is reproduced and documented; any increase must update the manifest, README, artifact provenance, workflow, and consuming TotalCross configuration together.
  Date/Author: 2026-07-17 / user and Codex

- Decision: force `MSVC_RUNTIME_LIBRARY` to `MultiThreaded` for every MSVC target and pass `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` in CI.
  Rationale: `MultiThreaded` is CMake's representation of `/MT`. Applying it globally after setting policy `CMP0091` to `NEW`, and also on the `SLJIT` target, prevents Visual Studio defaults from introducing `/MD` into the library or smoke executable.
  Date/Author: 2026-07-17 / user and Codex

- Decision: use a dedicated `build-sljit.yml` rather than the QR-code reusable workflow.
  Rationale: SLJIT deliberately excludes iOS, needs explicit W^X and Windows runtime validation, and needs different test expectations for executable hosts and cross-compiled Android.
  Date/Author: 2026-07-17 / Codex

## Outcomes & Retrospective

The implementation defines one coherent eight-archive release matrix: Linux x86_64, ARMv7, and AArch64; Windows x86, x64, and ARM64; Android ARM64; and macOS ARM64. On 2026-07-17, a native Apple Silicon host configured the wrapper from the independently checksum-verified codeload archive, built and passed `sljit-smoke-test` (1/1), installed the four headers, `libsljit.a`, and the upstream license, then packaged `sljit-macos-arm64.tar.gz`. The extracted package was staged under `sljit/local/macos/arm64`; the independent find-consumer then configured, built, and passed (1/1). GitHub Actions is the remaining source of cross-platform build evidence.

## Editorial Report

This report is mandatory at completion. Until execution begins, the entries below distinguish planned claims from observed research and must not be presented as completed implementation.

### Editorial Summary

This change packages SLJIT as a reproducible native dependency for TotalCross. The immutable source pin, static-library build, W^X allocator policy, Android API level, Windows CRT choice, artifact layout, and strict CMake consumption contract are implemented. No depot release has yet been published.

### Original Plan versus Actual Outcome

The original plan is to publish the eight-target matrix described above without iOS. Record the actual target matrix and every changed, deferred, or rejected item after CI and release validation.

### What Changed

The implementation adds `sljit/**`, `.github/workflows/build-sljit.yml`, and `.github/workflows/release-sljit.yml`, and adds the `sljit` bundle entry in `deps.yml`. The stable imported target is `SLJIT::SLJIT`; each archive is named `sljit-<platform>-<arch>.tar.gz`.

### Decisions and Trade-offs

The initial decisions are a commit-pinned snapshot, a depot-owned CMake wrapper, W^X executable allocation, Android API 23, Windows `/MT`, and no iOS artifact. Reconcile these decisions with the final implementation rather than copying this planned list unchanged.

### Unexpected Problems and Discoveries

The known upstream and platform discoveries are recorded above. Add only problems observed during implementation or CI, with concise evidence.

### Validation and Measurable Results

The local Apple Silicon validation measured 1/1 passing smoke test and 1/1 passing extracted-package consumer test. It verified the package manifest records `platform_arch=macos/arm64` and `executable_allocator=wx`. GitHub Actions must still produce the full architecture, Windows CRT, Android metadata, asset checksum, and fetch evidence. Android runtime execution is not claimed.

### Useful Evidence and Examples

The upstream archive hash and source locations in this plan are research evidence. At completion, point to workflow runs, release assets, test output, `dumpbin` output, manifest excerpts, commits, and the release URL.

### Limitations, Remaining Work, and Open Questions

The depot change alone does not enable TotalCross JIT execution, update `TotalCrossVM/deps/totalcross-depot-tools.ref`, or prove Android runtime executable-memory policy. Those are consumer integration tasks. iOS is explicitly out of scope.

### Possible Article Angles

One angle for native build maintainers is “Packaging a JIT backend reproducibly across desktop and Android,” centered on source provenance, architecture matrices, W^X policy, and cross-compilation evidence. Another angle for Windows C/C++ maintainers is “Proving static CRT selection in prebuilt libraries,” centered on CMake policy `CMP0091`, `/MT`, and artifact inspection. A third angle for Android native developers is “Separating cross-compilation support from runtime JIT support,” centered on NDK/API compatibility, 16 KiB pages, and honest acceptance boundaries.

### Suggested Narrative

Start with TotalCross's need for one pinned low-level code generator. Explain why upstream source inclusion alone is not a reproducible binary supply chain, then cover the immutable pin, depot-owned wrapper, platform matrix, W^X allocator, `/MT`, and Android API 23. Describe CI difficulties and any corrections, show executable host smoke evidence and Android archive/link evidence separately, and close with the remaining device-runtime and TotalCross consumer integration work.

### Claims Requiring Human Review

Any claim that Android JIT execution is production-ready, that W^X behavior satisfies a particular store or platform security policy, or that the binaries support targets not exercised by CI requires explicit security and platform-owner review. License redistribution and public release notes require normal legal and technical review.

## Context and Orientation

`TotalCross/totalcross-depot-tools` is the owning repository for native dependency acquisition, builds, release artifacts, and CMake discovery used by TotalCross. Each dependency lives under a top-level directory. `deps.yml` is the compatible bundle index. `<dependency>/manifest.yml` pins source and release information. `<dependency>/CMakeLists.txt` builds in isolation. `<dependency>/scripts/package-artifact.sh` creates a platform archive. `<dependency>/fetch.sh` downloads a published archive into `local/<platform>/<arch>`. `<dependency>/cmake/Find*.cmake` resolves only that local prebuilt, and `AutoFetch*.cmake` downloads it when allowed. `.github/workflows/build-*.yml` produces CI artifacts and `release-*.yml` tags and publishes them.

SLJIT is a low-level code generator. Its C API receives instructions and emits native machine code for the current architecture. The upstream library build is one C translation unit, `sljit_src/sljitLir.c`; that file includes the selected architecture backend internally. Consumers include `sljitLir.h`. SLJIT automatically recognizes x86, x86-64, ARM, and ARM64 from compiler predefined macros, so depot-tools must not hard-code an architecture macro that could disagree with the toolchain target.

W^X means a memory page is writable or executable, but never both at once. `SLJIT_WX_EXECUTABLE_ALLOCATOR=1` selects the upstream POSIX allocator based on `mmap` and `mprotect`, or the Windows allocator based on `VirtualAlloc` and `VirtualProtect`. Do not use the default allocator for these binaries because it may request writable-and-executable mappings. Do not define `SLJIT_SINGLE_THREADED`; the TotalCross VM may compile and execute on multiple threads.

The initial distribution version is `20260717`. Its source is the codeload archive for commit `3907e69005ba6e30b225000f24aaef3632f88347`, whose SHA-256 is `f3e299647a610c537296a41d8866f1e7b664401c229e6cdb67a621250086efd9`. The upstream LICENSE is the Simplified BSD license and must be retained verbatim in source staging and every binary archive. Repository-authored new files need the current-year Amalgam copyright and SPDX header appropriate to their file type; do not replace or prepend that header to upstream license text.

The required artifact matrix is:

- `linux/x86_64`, `linux/armv7l`, and `linux/aarch64` produce `lib/libsljit.a`.
- `windows/x86`, `windows/x64`, and `windows/arm64` produce `lib/sljit.lib` and use `/MT`.
- `android/arm64-v8a` produces `lib/libsljit.a` using NDK `28.2.13676358`, API 23, and the non-legacy NDK CMake toolchain.
- `macos/arm64` produces `lib/libsljit.a`.

Every archive is named `sljit-<platform>-<arch>.tar.gz` and expands to `sljit/<platform>/<arch>/`. Under that root, `include/` contains `sljitLir.h`, `sljitConfig.h`, `sljitConfigCPU.h`, and `sljitConfigInternal.h`; `lib/` contains the static library; `share/licenses/sljit/LICENSE` contains the unmodified upstream notice; and `manifest.txt` contains provenance. Do not publish iOS, iOS simulator, or an XCFramework in this plan.

## Plan of Work

### Milestone 1: add an immutable source and build definition

Create `sljit/manifest.yml` with `name: sljit`, `version: 20260717`, `release: sljit-20260717`, the full upstream commit, codeload URL, archive SHA-256, expected extracted directory, public headers, static library name, license path, configuration definitions, Android NDK/API metadata, Windows CRT metadata, and all eight archive names. Add the same version, release, and path under `dependencies.sljit` in root `deps.yml`.

Create `sljit/CMakeLists.txt` with a repository header and `cmake_minimum_required(VERSION 3.16)`. Set CMake policy `CMP0091` to `NEW` before `project(...)`. Define cache inputs `SLJIT_SOURCE_DIR`, `SLJIT_SOURCE_ARCHIVE`, `SLJIT_SOURCE_URL`, and `SLJIT_SOURCE_SHA256`, defaulted to the pinned values. Support an already unpacked source directory for offline and CI testing. Otherwise download or use the supplied archive, verify SHA-256 before extraction, unpack into the build directory, and require exactly one directory named for the pinned commit. Never build an unverified moving branch.

Add static target `SLJIT` from `<unpacked>/sljit_src/sljitLir.c` and alias `SLJIT::SLJIT`. Set `OUTPUT_NAME sljit`, `POSITION_INDEPENDENT_CODE ON`, C99 required, and public build/install include directories. Apply these public compile definitions to the library and propagate them through the installed/imported target:

    SLJIT_WX_EXECUTABLE_ALLOCATOR=1
    SLJIT_PROT_EXECUTABLE_ALLOCATOR=0
    SLJIT_ARGUMENT_CHECKS=1
    SLJIT_DEBUG=0
    SLJIT_VERBOSE=0

Do not define `SLJIT_CONFIG_STATIC`, `SLJIT_SINGLE_THREADED`, or an architecture selector. On non-Windows targets, call `find_package(Threads REQUIRED)` and link `Threads::Threads` publicly because the W^X allocator synchronizes its first capability check. On MSVC, force `CMAKE_MSVC_RUNTIME_LIBRARY` and target property `MSVC_RUNTIME_LIBRARY` to `MultiThreaded`. Treat any attempt to configure a different MSVC runtime as a fatal error so a caller cannot accidentally publish `/MD` artifacts.

Install the target archive, the four public headers, and upstream `LICENSE` at the paths described above. Do not install backend `.c` files because they are already compiled through `sljitLir.c` and are not a consumer interface.

Create `sljit/tests/sljit_smoke_test.c`. It creates a compiler with `sljit_create_compiler(NULL)`, emits a function with signature `SLJIT_ARGS3(W, W, W, W)`, adds the three saved-register arguments into `SLJIT_R0`, emits a return, generates code, calls it with `4`, `5`, and `6`, frees both compiler and code, and exits nonzero unless the result is `15`. It must check every pointer and every emitter return value and print one concise marker:

    [PASS] SLJIT generated add3(4, 5, 6) = 15

Build this test when `BUILD_TESTING=ON`, link only `SLJIT::SLJIT`, and register it with CTest. Add compile-time assertions that the public definitions select W^X, do not select the dual-map allocator, and do not select single-threaded mode. Run the test on executable desktop jobs. Android cross-compiles and links the same executable but does not claim to run it.

Acceptance for this milestone is a macOS or Linux Release configure, build, install, and passing CTest using either the verified download or a local archive. The install tree must contain one static library, four headers, and the BSD license.

### Milestone 2: add packaging, strict discovery, and fetch support

Create `sljit/scripts/package-artifact.sh` following existing three-argument package scripts: `BUILD_DIR INSTALL_DIR PLATFORM_ARCH`. It must reject missing headers, library, or license; copy only installed deliverables; write `manifest.txt`; and create `sljit-<platform>-<arch>.tar.gz`. The manifest records at least:

    name=sljit
    upstream_commit=3907e69005ba6e30b225000f24aaef3632f88347
    source_sha256=f3e299647a610c537296a41d8866f1e7b664401c229e6cdb67a621250086efd9
    distribution_version=20260717
    platform_arch=<platform>/<arch>
    build_type=Release
    executable_allocator=wx
    argument_checks=enabled

For Windows append `msvc_runtime=MT`. For Android append `android_abi=arm64-v8a`, `android_ndk=28.2.13676358`, and `android_min_sdk=23`. The script must derive fixed values from `manifest.yml` or constants checked against it, not accept provenance overrides from untrusted command-line input.

Create `sljit/fetch.sh` with the established options `--platform`, `--arch`, `--release-tag`, `--github-repo`, `--github-token-env`, and `--dest`. Default to release `sljit-20260717`, repository `TotalCross/totalcross-depot-tools`, token environment `SLJIT_GITHUB_TOKEN`, and destination `sljit/local`. Normalize only supported aliases: Linux `amd64` to `x86_64`, Linux `arm64` to `aarch64`, Windows `amd64` to `x64`, and Apple `aarch64` to `arm64`. Reject unsupported platform/architecture pairs before network access. Download to a temporary directory, extract, validate all four headers, the license, the expected library name, `name=sljit`, the full upstream commit, `executable_allocator=wx`, and platform-specific metadata, then replace only `local/<platform>/<arch>`. Never print a token or authenticated URL.

Create `sljit/cmake/FindSLJIT.cmake`. Detect the same platform/architecture names, but fail immediately for iOS and unknown targets. Set `SLJIT_DIR` to `sljit/local/<platform>/<arch>`, find `sljitLir.h` and only the local static library with `NO_DEFAULT_PATH` and `NO_CMAKE_FIND_ROOT_PATH`, verify `manifest.txt` exists, and expose imported target `SLJIT::SLJIT`. Give that target the include directory, the five public compile definitions above, and `Threads::Threads` on non-Windows platforms. It must never fall back to a system, Homebrew, SDK, or package-manager SLJIT.

Create `sljit/cmake/AutoFetchSLJIT.cmake` following the repository rule that paths derive from `CMAKE_CURRENT_LIST_FILE`. It defaults `SLJIT_RELEASE_TAG` and `SLJIT_GITHUB_REPO`, includes `FindSLJIT.cmake`, returns if the artifact already exists, otherwise invokes `fetch.sh` for the detected pair and resolves again. A failed download or a still-missing target is fatal.

Create `sljit/tests/find_consumer/CMakeLists.txt` and `main.c`. This independent tiny consumer includes CTest, appends `sljit/cmake` to `CMAKE_MODULE_PATH`, calls `find_package(SLJIT REQUIRED)`, links `SLJIT::SLJIT`, registers the executable with `add_test`, and executes a one-argument generated function. Configure it against an extracted package staged under `sljit/local/<platform>/<arch>` to prove that include definitions and thread linkage are carried by the imported target.

Create `sljit/README.md` documenting the immutable source, Simplified BSD redistribution, matrix, archive layout, W^X choice, Android build values, `/MT`, local build commands, fetch environment variables, CMake target, and explicit iOS exclusion. Explain that Android cross-compilation proves availability of a compatible binary, not runtime permission to execute generated code.

Acceptance for this milestone is a locally packaged host archive that can be extracted into a temporary `local/` root, discovered without system fallback, linked by `tests/find_consumer`, and executed successfully. A deliberately absent local package must make `find_package(SLJIT REQUIRED)` fail rather than find a system copy.

### Milestone 3: build and test the release matrix

Create `.github/workflows/build-sljit.yml` with `workflow_call`, `workflow_dispatch`, push, and pull-request triggers scoped to `sljit/**`, the workflow itself, and any shared script it actually uses. Use the repository's current action versions and `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` convention. Each job performs configure, build, host test when executable, install, package, artifact validation, and upload. Keep full command output available in Actions while console output remains readable.

For Linux, use the current shared images and naming convention: `totalcross/linux-amd64:v1.0.7` for `linux/x86_64`, `totalcross/linux-arm32v7:v1.0.7` under QEMU for `linux/armv7l`, and `totalcross/linux-arm64:v1.0.7` on the native ARM runner for `linux/aarch64`. Configure Release with Ninja, build, run `ctest --output-on-failure`, install, and package. Use `file` or `readelf` on the object inside the archive to verify the expected ELF machine. If the ARMv7 test fails only because QEMU refuses executable-memory transitions, record the exact evidence and obtain a native ARMv7 run before calling that artifact runtime-tested; do not silently turn a failing test green.

For Windows, use Visual Studio 2022 on `windows-2022` for x86 and x64 and `windows-11-arm` for ARM64. Configure each with `-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` and the corresponding `-A Win32`, `-A x64`, or `-A ARM64`. Build and test Release, install, and package. Capture a verbose compile line containing `/MT` and no `/MD`. Run `dumpbin /directives` on `sljit.lib` and on the smoke-test object or executable inputs; require `DEFAULTLIB:LIBCMT` and reject `DEFAULTLIB:MSVCRT`. Apply the same `MultiThreaded` setting to the smoke executable so the validation does not mix CRT models.

For macOS, run on `macos-15`, configure Release with Ninja and `-DCMAKE_OSX_ARCHITECTURES=arm64`, then build, run CTest, install, package, and use `lipo -info` or `file` to prove ARM64. Do not add iOS rows to this matrix.

For Android, run on Ubuntu 24.04, install `ndk;28.2.13676358` and `cmake;3.22.1`, and configure exactly:

    cmake -S sljit -B sljit/build/android-arm64-v8a \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE="${ANDROID_HOME}/ndk/28.2.13676358/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-23 \
      -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
      -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF \
      -DBUILD_TESTING=ON \
      -G Ninja

Build both the library and smoke executable, but do not run the cross-compiled executable on the Ubuntu host. Install and package. Use the NDK's `llvm-nm` to require exported `sljit_create_compiler`, `sljit_generate_code`, and `sljit_free_code` symbols. Use the NDK's `llvm-readelf` on the archive object to require `Machine: AArch64`. Require the package manifest to report API 23 and NDK r28c. Inspect the link command for the cross-compiled smoke executable to prove the installed API surface links under API 23. NDK r28 enables flexible 16 KiB page alignment by default; the explicit option makes that contract visible and protects against workflow drift.

Do not raise Android to API 24 merely to avoid investigating a failure. First retain the full compiler/linker error, identify the unavailable symbol or behavior, and verify it is genuinely introduced in API 24. If and only if that evidence exists, change every `android-23` and `android_min_sdk=23` occurrence to 24, add a dated `Surprises & Discoveries` entry, record the decision here, and note the compatibility impact in release notes.

Acceptance for this milestone is eight uploaded archives with the exact names declared in `sljit/manifest.yml`. Desktop CTest is green on each natively executable runner; cross-compiled artifacts have correct architecture and metadata; all archives contain the license; all Windows artifacts prove `/MT`; and Android compiles and links at API 23.

### Milestone 4: publish and verify the depot release

Create `.github/workflows/release-sljit.yml` modeled on current dependency releases. It resolves version `20260717`, obtains the next non-conflicting tag with `.github/scripts/next-release-tag.sh`, calls `build-sljit.yml`, downloads all eight artifacts into one release-assets directory, verifies their filenames against the manifest, creates an annotated tag, and publishes a GitHub release. Release notes state the upstream commit, W^X build policy, platform matrix, Android NDK/API, Windows `/MT`, license, and the fact that Android runtime execution is not claimed by this build-only validation.

After publication, fetch every asset with `sljit/fetch.sh` into a separate temporary destination. For one host platform, configure and run `tests/find_consumer` from the fetched package. For Android, configure the same consumer with the NDK toolchain and API 23 and link it. Compare SHA-256 values of downloaded release assets with the workflow artifacts if both are retained. Record the final tag and release URL in this plan.

Acceptance is observable: the public or authorized GitHub release has exactly the declared eight `.tar.gz` assets; each fetch prints `Installed sljit <platform>/<arch> into <destination>`; invalid pairs such as `ios/arm64` fail before downloading; the host consumer prints its pass marker; and Android consumer linking succeeds at API 23.

### Milestone 5: reconcile evidence and hand off to TotalCross

Run the repository-wide static checks, inspect the final diff for generated files, and ensure no `sljit/build`, `sljit/local`, `dist`, downloaded archive, or token-bearing log is committed. Update every living section of this plan. Reconcile the actual implementation, workflow results, measurements, limitations, and release link into `Outcomes & Retrospective` and all Editorial Report subsections.

The handoff to the separate TotalCross JIT work must name the exact depot-tools release tag and imported target `SLJIT::SLJIT`. Updating `TotalCrossVM/deps/totalcross-depot-tools.ref`, Android Gradle fetching, or VM JIT code is deliberately outside this depot-tools ExecPlan and belongs in the TotalCross consumer plan.

## Concrete Steps

Use a normal clone of the owning repository. From its root, verify source provenance before writing build logic:

    curl -fsSL --retry 3 \
      -o /tmp/sljit-3907e69005ba6e30b225000f24aaef3632f88347.tar.gz \
      https://codeload.github.com/zherczeg/sljit/tar.gz/3907e69005ba6e30b225000f24aaef3632f88347
    shasum -a 256 /tmp/sljit-3907e69005ba6e30b225000f24aaef3632f88347.tar.gz

The expected checksum line begins:

    f3e299647a610c537296a41d8866f1e7b664401c229e6cdb67a621250086efd9

On an ARM64 macOS host, exercise the owned wrapper and package without redownloading:

    cmake -S sljit -B sljit/build/macos-arm64 \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DSLJIT_SOURCE_ARCHIVE=/tmp/sljit-3907e69005ba6e30b225000f24aaef3632f88347.tar.gz \
      -DBUILD_TESTING=ON \
      -G Ninja
    cmake --build sljit/build/macos-arm64
    ctest --test-dir sljit/build/macos-arm64 --output-on-failure
    cmake --install sljit/build/macos-arm64 \
      --prefix sljit/build/macos-arm64/install
    bash sljit/scripts/package-artifact.sh \
      sljit/build/macos-arm64 \
      sljit/build/macos-arm64/install \
      macos/arm64

Expected CTest evidence includes the pass marker and `100% tests passed`. The archive is `sljit/build/macos-arm64/sljit-macos-arm64.tar.gz`.

On Windows, run these commands in a Visual Studio 2022 developer shell, substituting `Win32`, `x64`, and `ARM64` in separate build directories:

    cmake -S sljit -B sljit/build/windows-x64 \
      -G "Visual Studio 17 2022" -A x64 \
      -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
      -DBUILD_TESTING=ON
    cmake --build sljit/build/windows-x64 --config Release --verbose
    ctest --test-dir sljit/build/windows-x64 -C Release --output-on-failure
    cmake --install sljit/build/windows-x64 --config Release \
      --prefix sljit/build/windows-x64/install
    dumpbin /directives sljit/build/windows-x64/install/lib/sljit.lib
    bash sljit/scripts/package-artifact.sh \
      sljit/build/windows-x64 \
      sljit/build/windows-x64/install \
      windows/x64

Save a concise directive excerpt showing `DEFAULTLIB:LIBCMT`. Fail validation if `/MD`, `MSVCRT`, or `MSVCRTD` appears in compile lines or directives. Repeat for x86 and ARM64 on their designated runners.

For Android ARM64, run from the repository root after `ANDROID_HOME` is configured:

    sdkmanager "ndk;28.2.13676358" "cmake;3.22.1"
    cmake -S sljit -B sljit/build/android-arm64-v8a \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE="${ANDROID_HOME}/ndk/28.2.13676358/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-23 \
      -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
      -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF \
      -DBUILD_TESTING=ON \
      -G Ninja
    cmake --build sljit/build/android-arm64-v8a
    cmake --install sljit/build/android-arm64-v8a \
      --prefix sljit/build/android-arm64-v8a/install
    bash sljit/scripts/package-artifact.sh \
      sljit/build/android-arm64-v8a \
      sljit/build/android-arm64-v8a/install \
      android/arm64-v8a

Locate `llvm-nm` and `llvm-readelf` under the installed NDK toolchain and inspect `sljit/build/android-arm64-v8a/install/lib/libsljit.a`. Expected evidence includes AArch64 and the three required public symbols. Do not execute this binary on the Ubuntu build host.

After a release exists, validate fetch behavior without modifying a developer's normal `local/` cache:

    sljit_fetch_root="$(mktemp -d)"
    bash sljit/fetch.sh --platform macos --arch arm64 \
      --release-tag sljit-20260717 --dest "${sljit_fetch_root}"
    find "${sljit_fetch_root}/macos/arm64" -maxdepth 4 -type f | sort

If the release helper creates `sljit-20260717-r2` because the base tag already exists, use the actual returned tag in this command and update all living documentation; never overwrite the old tag.

Before handoff, run from the depot-tools root:

    bash -n sljit/fetch.sh sljit/scripts/package-artifact.sh
    ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "ok"' \
      deps.yml sljit/manifest.yml
    cmake -S sljit/tests/find_consumer \
      -B sljit/build/find-consumer -G Ninja
    cmake --build sljit/build/find-consumer
    ctest --test-dir sljit/build/find-consumer --output-on-failure
    git diff --check
    git status --short -- sljit deps.yml .github/workflows

The find-consumer command assumes the matching package is staged at `sljit/local/<platform>/<arch>`; use a temporary worktree or symlink-free copy if preserving an existing cache matters. Validate repository-authored copyright/SPDX headers before committing. Review staged files explicitly and never stage build output or `local/`.

## Validation and Acceptance

The implementation is accepted only when all of the following behavior is observed and recorded:

- The source archive is rejected if its SHA-256 differs from the pinned value, and offline configuration succeeds when the correct archive or unpacked source directory is supplied.
- Host smoke tests generate native code, call `add3(4, 5, 6)`, observe `15`, and free generated code on Linux x86_64, Linux AArch64, Windows x86/x64/ARM64, and macOS ARM64. Linux ARMv7 must have either the same passing evidence or a clearly recorded native-run follow-up if QEMU itself blocks JIT mappings.
- Every compiled library uses the W^X allocator definitions and retains multithreaded support. No release build uses the default simultaneous writable/executable allocation path.
- Windows verbose compile evidence contains `/MT`; `dumpbin /directives` contains `DEFAULTLIB:LIBCMT`; neither evidence contains `/MD`, `MSVCRT`, nor `MSVCRTD`.
- Android `arm64-v8a` compiles and links with NDK `28.2.13676358`, API 23, flexible page sizes enabled, and the non-legacy toolchain. Its archive is AArch64 and exports the required SLJIT API. This is not evidence of Android runtime execution.
- Each archive has exactly the declared platform root, headers, static library, unmodified BSD license, and provenance manifest. The package contains no build directory or upstream source tree.
- `FindSLJIT.cmake` resolves only a fetched depot artifact, exports `SLJIT::SLJIT`, propagates definitions and thread linkage, and fails when no matching local artifact exists. `AutoFetchSLJIT.cmake` downloads the requested supported pair and rejects iOS.
- The published release contains exactly eight declared archives, and `fetch.sh` successfully validates all eight into temporary destinations.
- Shell syntax, YAML parsing, focused CMake consumer tests, copyright/SPDX header validation, and `git diff --check` pass. No generated or cached dependency artifact is staged.
- `Outcomes & Retrospective` and the Editorial Report contain actual workflow, release, artifact, and test evidence before the plan is marked complete.

## Idempotence and Recovery

All CMake source extraction occurs under the selected build directory and may be deleted and regenerated without touching tracked source. Reconfiguring with the same verified source archive is safe. Packaging replaces only its own `build/<target>/artifact/sljit/<platform>/<arch>` staging tree and output archive. Fetching downloads to a temporary directory, validates fully, and only then replaces the requested `local/<platform>/<arch>` directory.

Never delete a broad `local/`, `build/`, repository root, or a path derived from an empty variable. Use a fresh target-specific build directory when changing generator, architecture, NDK, or Visual Studio platform. If a release workflow fails before tagging, fix and rerun it. If it fails after the tag exists, do not retag or replace assets silently; use the existing release-revision convention and update `manifest.yml`, `deps.yml`, fetch defaults, and this plan together.

If the upstream archive checksum changes for the same commit, stop and investigate rather than accepting the new bytes. If API 23 fails, retain the log and prove the API-level cause before considering API 24. If `/MT` validation fails, inspect policy `CMP0091`, cached `CMAKE_MSVC_RUNTIME_LIBRARY`, and target properties; discard only the target-specific Windows build directory before reconfiguring.

Do not commit `sljit/build/`, `sljit/local/`, downloaded source archives, unpacked upstream sources, GitHub tokens, or workflow diagnostic bundles. The upstream LICENSE must remain byte-for-byte unchanged.

## Artifacts and Notes

Expected tracked additions in depot-tools are:

    sljit/CMakeLists.txt
    sljit/README.md
    sljit/manifest.yml
    sljit/fetch.sh
    sljit/cmake/AutoFetchSLJIT.cmake
    sljit/cmake/FindSLJIT.cmake
    sljit/scripts/package-artifact.sh
    sljit/tests/sljit_smoke_test.c
    sljit/tests/find_consumer/CMakeLists.txt
    sljit/tests/find_consumer/main.c
    .github/workflows/build-sljit.yml
    .github/workflows/release-sljit.yml

Root `deps.yml` is the only expected modification outside those paths unless implementation evidence justifies a focused shared-script correction. No SLJIT upstream source is checked in; the pinned archive is downloaded and verified during the build.

Keep concise evidence for each artifact: workflow job URL, archive SHA-256 and size, architecture inspection, CTest pass line where executable, Android link line, Windows `/MT` compile excerpt and `LIBCMT` directive, package manifest, and fetch result. Record code-size or build-duration measurements only when actually measured and with runner/toolchain context; do not turn them into performance claims.

## Interfaces and Dependencies

At completion, depot consumers use this stable CMake interface:

    list(APPEND CMAKE_MODULE_PATH "<depot-tools>/sljit/cmake")
    include(AutoFetchSLJIT)
    tcvm_auto_fetch_sljit()
    find_package(SLJIT REQUIRED)
    target_link_libraries(<consumer> PRIVATE SLJIT::SLJIT)

`FindSLJIT.cmake` provides `SLJIT_FOUND`, `SLJIT_DIR`, `SLJIT_INCLUDE_DIR`, `SLJIT_LIBRARY`, and imported static target `SLJIT::SLJIT`. The target supplies the include path, W^X and release compile definitions, and non-Windows thread dependency. Consumers include:

    #include <sljitLir.h>

The fetch interface is:

    bash sljit/fetch.sh \
      --platform <linux|windows|android|macos> \
      --arch <supported-arch> \
      [--release-tag <tag>] \
      [--github-repo <owner/repository>] \
      [--github-token-env <environment-variable-name>] \
      [--dest <directory>]

Supported platform/architecture pairs are exactly the eight pairs in this plan. The default token variable is `SLJIT_GITHUB_TOKEN`, with `GITHUB_TOKEN` as the standard fallback. Values must never be echoed.

The only upstream compilation unit is `sljit_src/sljitLir.c`. Its public API is defined by the installed four headers. The package has no native dependency beyond operating-system APIs and the platform thread library selected by `Threads::Threads`; Android pthread functions are supplied by bionic. The consuming TotalCross repository remains responsible for deciding when JIT is enabled and for device-level runtime tests and shutdown behavior.

2026-07-17 / Codex: Initial plan created from `.agent/PLANS.md`. It pins the researched SLJIT snapshot, requires W^X builds, keeps Android ARM64 at API 23 with an evidence-gated API 24 fallback, forces Windows `/MT`, excludes iOS, and separates depot publication from the later TotalCross consumer integration.
