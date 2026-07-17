# Enforce and verify the static MSVC runtime in every Windows static-library build

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, `Outcomes & Retrospective`, and `Editorial Report` must be kept current while the work is executed.

This plan follows the supplied `PLANS.md` requirements. The plan is intentionally self-contained because the supplied planning guide is not currently stored at a known repository-relative path. If a repository-local `PLANS.md` is added or discovered, update this paragraph with its path and continue maintaining this document in accordance with it.

## Purpose / Big Picture

The Windows artifacts published by `TotalCross/totalcross-depot-tools` are static libraries, but a static `.lib` can still contain object files compiled against the dynamic Microsoft C/C++ runtime. In Microsoft compiler terminology, `/MT` means that the object is compiled to use the static multithreaded runtime, while `/MD` means that it expects the dynamic runtime DLLs. Mixing these models can cause duplicate runtimes, unresolved symbols, allocator mismatches, deployment dependencies, or crashes when memory crosses module boundaries.

After this work, every Windows static library built by this repository must be configured explicitly for `/MT`, and every Windows build must inspect the exact artifact it is about to upload. A build must fail before upload when any packaged `.lib` contains dynamic-runtime linker directives or lacks evidence of the static release runtime.

The implementation also audits the Windows assets already published on GitHub, determines which libraries actually require replacement releases, commits the correction, and dispatches the affected release workflows in dependency order. Independent releases run in parallel. Dependent releases wait for their prerequisites. The work is complete only after every affected library has a successful GitHub Actions release run, a published GitHub Release, the expected Windows assets, and a final artifact-level `/MT` verification.

`vcruntime` is explicitly out of scope. Its workflow downloads and packages Microsoft redistributable DLLs; it does not compile static libraries.

## Progress

- [x] (2026-07-17) Authored this ExecPlan after inspecting the current repository build workflows, CMake wrappers, Skia GN scripts, dependency manifests, and release workflows.
- [x] (2026-07-17) Confirmed that `vcruntime` is excluded because it packages prebuilt redistributables instead of compiling libraries.
- [x] (2026-07-17) Recorded baseline: `main` at `bdd0677877e38af2f30279055bfc74fbeb53ead0`, default branch `main`, authenticated `gh` account `flsobral` with `repo` scope, and only this untracked ExecPlan present initially.
- [x] (2026-07-17) Inventoried Windows artifacts: each CMake family packages `<dep>/build/windows-<arch>/<dep>-*.tar.gz`; Skia uploads `skia/dist/libskia-windows-<arch>.lib`, for x86, x64, and ARM64.
- [x] (2026-07-17) Added the shared Windows static-runtime CMake policy and artifact-level PowerShell verifier.
- [x] (2026-07-17) Added positive and negative fixture tests for the verifier.
- [x] (2026-07-17) Wired the verifier into every in-scope Windows build before artifact upload.
- [x] (2026-07-17) Made the Skia GN configuration explicitly emit `/MT`.
- [x] (2026-07-17) Made the libjpeg-turbo nested `ExternalProject` configure explicitly emit `/MT`.
- [ ] Audit the latest published Windows artifacts and calculate the direct and transitive release set.
- [ ] Run all affected build workflows on the correction branch and confirm x86, x64, and ARM64 artifacts pass.
- [ ] Commit and push the correction with a Conventional Commits message and descriptive body.
- [ ] Dispatch independent affected release workflows in parallel.
- [ ] Wait for `zlib-ng`, update its release pins if it was released, and only then dispatch dependent `libpng`.
- [ ] Wait for `libpng`, update its release pins if it was released, and only then dispatch dependent `skia`.
- [ ] Verify every affected GitHub Release, its Windows assets, its tag ancestry, and its final `/MT` directives.
- [ ] Reconcile `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective`.
- [ ] Finalize the `Editorial Report` from actual commits, workflow runs, release URLs, tags, assets, and validation output.

## Surprises & Discoveries

- Observation: the repository currently has eight compiled Windows static-library families in scope: `libjpeg-turbo`, `libjpeg`, `libpng`, `mbedtls`, `skia`, `sqlite3`, `zlib-ng`, and `zlib`.
  Evidence: the corresponding build and release workflows exist under `.github/workflows/`.

- Observation: the CMake-based Windows workflow configure commands do not currently pass `CMAKE_MSVC_RUNTIME_LIBRARY`, so the desired runtime is not visible or enforced at the workflow boundary.
  Evidence: inspect each `build-*.yml` Windows job before implementation and preserve concise excerpts in this section.

- Observation: most dependency wrappers use `FetchContent` or `add_subdirectory`, but `libjpeg-turbo/CMakeLists.txt` uses a nested `ExternalProject`. A runtime setting in the parent configure is not sufficient unless it is explicitly forwarded to the nested configure.
  Evidence: `libjpeg-turbo/CMakeLists.txt` builds `TC_LIBJPEG_TURBO_CMAKE_ARGS` and passes it to `ExternalProject_Add`.

- Observation: Skia is not built by CMake. Its Windows configuration is generated in `skia/scripts/common.sh`, so the CMake policy cannot affect it.
  Evidence: `windows_gn_args` emits GN arguments and `build_skia_windows` invokes the GN/Ninja path.

- Observation: Skia and every other build that consumes a repository artifact resolve the compatible `release` pin from `deps.yml`.
  Evidence: `.github/scripts/read-deps-release.sh` is used by `skia/scripts/fetch-prebuilt-deps.sh` and the libpng, minizip, and minizip-ng build workflows.

- Observation: `libpng` is built against released `zlib-ng` prebuilts, and Skia is built against released `zlib-ng` and `libpng` prebuilts.
  Evidence: `.github/workflows/build-libpng.yml`, `.github/workflows/build-skia.yml`, and the corresponding fetch scripts.

- Observation: `vcruntime` has a Windows workflow but is not a compiled static library.
  Evidence: `.github/workflows/build-vcruntime.yml` downloads redistributable installers and packages runtime DLLs.

- Observation: workflow path filters still name `master` while the GitHub default branch is `main`.
  Evidence: `gh repo view TotalCross/totalcross-depot-tools --json defaultBranchRef --jq '.defaultBranchRef.name'` returned `main`; existing `build-*.yml` headers use `branches: [ master ]`.

- Observation: the local macOS environment has no `pwsh`; Windows validation must run in GitHub Actions.
  Evidence: `command -v pwsh` produced no path on 2026-07-17.

Add new discoveries here as they are observed. Each entry must include a short command, path, workflow run, or output excerpt that proves the observation.

## Decision Log

- Decision: exclude `vcruntime` completely from runtime compilation enforcement and release calculation.
  Rationale: it packages precompiled Microsoft DLLs and has no compiler invocation whose `/MT` setting can be controlled.
  Date/Author: 2026-07-17 / plan author.

- Decision: use two independent enforcement layers for CMake libraries.
  Rationale: a shared CMake policy makes `/MT` an explicit repository rule, while an artifact-level inspection catches upstream overrides, nested builds, future omissions, and packaging mistakes.
  Date/Author: 2026-07-17 / plan author.

- Decision: inspect the exact `.lib` file or packaged `.tar.gz` that will be uploaded, rather than trusting only CMake cache values or compiler command lines.
  Rationale: the uploaded artifact is the contract with consumers. Configuration evidence is useful, but only final binary directives prove what was packaged.
  Date/Author: 2026-07-17 / plan author.

- Decision: use `DUMPBIN /DIRECTIVES` on GitHub-hosted Windows runners.
  Rationale: the static archive contains COFF object members whose linker directives distinguish the dynamic runtime defaults from the static runtime defaults. `dumpbin.exe` is supplied with Visual Studio and supports x86, x64, and ARM64 archives.
  Date/Author: 2026-07-17 / plan author.

- Decision: require Release artifacts to contain static-runtime evidence and reject dynamic- or debug-runtime evidence.
  Rationale: these workflows publish Release libraries. A passing artifact must contain `LIBCMT` evidence, must not contain `MSVCRT`, and must not contain `LIBCMTD` or other debug CRT defaults.
  Date/Author: 2026-07-17 / plan author.

- Decision: adding the verifier to a workflow does not by itself force a new library release.
  Rationale: the release set is based on artifact behavior. A library needs a replacement release when its previously published Windows artifact fails the baseline audit, when its own compilation settings must change, or when it statically embeds or links a dependency that receives a replacement release.
  Date/Author: 2026-07-17 / plan author.

- Decision: calculate the transitive release closure as `zlib-ng -> libpng -> skia`, with Skia also depending directly on `zlib-ng`.
  Rationale: downstream artifacts must be rebuilt after any changed static dependency so they no longer consume the old runtime model.
  Date/Author: 2026-07-17 / plan author.

- Decision: independent release workflows may run concurrently, but no dependent workflow may start until all changed prerequisites have published and their release pins used by the downstream build are updated.
  Rationale: this minimizes elapsed time without sacrificing reproducibility.
  Date/Author: 2026-07-17 / plan author.

- Decision: commit and push the correction before dispatching any release workflow.
  Rationale: every replacement release tag must contain the correction commit in its history, and every release build must execute the corrected workflow and verifier.
  Date/Author: 2026-07-17 / plan author.

- Decision: `deps.yml` is the default source of release pins for all internal build dependencies.
  Rationale: the bundle index defines the compatible set; independently selecting a newer release can produce an untested combination.
  Date/Author: 2026-07-17 / plan executor.

## Outcomes & Retrospective

This section must be updated after each major milestone and at completion.

At completion, state:

1. Which latest published artifacts failed the baseline audit.
2. Which build files required runtime changes.
3. Which libraries were directly affected.
4. Which libraries were added only because of transitive dependency rebuilding.
5. The correction commit SHA.
6. Every release workflow run ID and URL.
7. Every resulting release tag and URL.
8. Whether every Windows x86, x64, and ARM64 artifact passed the final verifier.
9. Any library that could not be proven, any reason for uncertainty, and the exact remaining action.

Do not describe planned results as completed results.

## Editorial Report

This section is mandatory at completion. Replace the guidance below with factual, evidence-based content from the executed work.

### Editorial Summary

Explain why a static `.lib` can still depend on the dynamic MSVC runtime, how the repository now prevents that mismatch, and which releases were replaced.

### Original Plan versus Actual Outcome

State which planned changes were implemented unchanged, which required adaptation, which libraries were already correct, which libraries required rebuilding, and whether the planned release dependency order changed.

### What Changed

Name the important final paths, including the shared CMake policy, PowerShell verifier, verifier tests, modified build workflows, `skia/scripts/common.sh`, `libjpeg-turbo/CMakeLists.txt`, `AGENTS.md`, and any release-pin files updated after publication.

### Decisions and Trade-offs

Describe why final binary inspection was retained even after explicit build configuration, why `dumpbin` was chosen, how archives with multiple `.lib` files were handled, and why release propagation follows the dependency graph.

### Unexpected Problems and Discoveries

Record failures such as an upstream project overriding the runtime property, a nested build not inheriting settings, a `.lib` with no directives, an import library accidentally included, a missing ARM64 tool, stale manifest pins, or a workflow dispatch race.

### Validation and Measurable Results

Include only observed results. Give exact build workflow run IDs, release workflow run IDs, release tags, assets checked, count of `.lib` files inspected, and concise passing or failing directive excerpts. Explicitly state if no size or performance measurement was taken.

### Useful Evidence and Examples

Point to stable repository paths, correction commits, metadata commits, workflow runs, GitHub Releases, JSON verifier summaries, and concise command output.

### Limitations, Remaining Work, and Open Questions

State any unresolved platform, toolchain, third-party, or release-metadata limitation. Confirm that this work does not inspect DLL-only artifacts and intentionally excludes `vcruntime`.

### Possible Article Angles

Suggest technically honest angles such as:

- For native build engineers: “Why a static `.lib` can still require the MSVC runtime DLLs.”
- For CI maintainers: “Verifying `/MT` from final COFF archives instead of trusting build flags.”
- For release engineers: “Rebuilding static dependency chains in topological order.”
- For cross-platform maintainers: “Applying one runtime policy across CMake, ExternalProject, and GN.”

### Suggested Narrative

Outline the strongest article as: the runtime mismatch; why configuration alone was insufficient; repository constraints; shared policy; binary inspection; nested `ExternalProject` and GN exceptions; baseline audit; dependency-aware releases; observed evidence; remaining limits.

### Claims Requiring Human Review

List any statement about compatibility failures, production crashes, redistribution obligations, security impact, or historical release correctness that was not directly proven. If no special claims remain, state that normal technical and editorial review is still required.

## Context and Orientation

The repository is `TotalCross/totalcross-depot-tools`. It builds, packages, and releases native dependencies consumed by TotalCross. Each dependency lives in its own top-level directory. Reusable build workflows are under `.github/workflows/build-*.yml`; release workflows are under `.github/workflows/release-*.yml`.

The in-scope compiled library families are:

- `zlib-ng`, built through `zlib-ng/CMakeLists.txt` and `.github/workflows/build-zlib-ng.yml`.
- `zlib`, built through `zlib/CMakeLists.txt` and `.github/workflows/build-zlib.yml`.
- `libpng`, built through `libpng/CMakeLists.txt` and `.github/workflows/build-libpng.yml`. It consumes released `zlib-ng` artifacts.
- `libjpeg`, built through `libjpeg/CMakeLists.txt` and `.github/workflows/build-libjpeg.yml`.
- `libjpeg-turbo`, built through `libjpeg-turbo/CMakeLists.txt` and `.github/workflows/build-libjpeg-turbo.yml`. Its wrapper launches a second CMake configure through `ExternalProject_Add`.
- `mbedtls`, built through `mbedtls/CMakeLists.txt` and `.github/workflows/build-mbedtls.yml`.
- `sqlite3`, built through `sqlite3/CMakeLists.txt` and `.github/workflows/build-sqlite3.yml`.
- `skia`, built through GN/Ninja helpers in `skia/scripts`, principally `skia/scripts/common.sh`, and `.github/workflows/build-skia.yml`. It consumes released `zlib-ng` and `libpng` artifacts.

The corresponding release workflows are:

- `.github/workflows/release-zlib-ng.yml`
- `.github/workflows/release-zlib.yml`
- `.github/workflows/release-libpng.yml`
- `.github/workflows/release-libjpeg.yml`
- `.github/workflows/release-libjpeg-turbo.yml`
- `.github/workflows/release-mbedtls.yml`
- `.github/workflows/release-sqlite3.yml`
- `.github/workflows/release-skia.yml`

A Windows static library is a COFF archive ending in `.lib`. It contains one or more object members. MSVC-compatible compilers usually place linker defaults in each object. For this plan:

- `/DEFAULTLIB:MSVCRT`, `/DEFAULTLIB:VCRUNTIME`, or `/DEFAULTLIB:UCRT` without the `LIB` prefix indicate the dynamic Release CRT family associated with `/MD`.
- `/DEFAULTLIB:LIBCMT`, `/DEFAULTLIB:LIBVCRUNTIME`, and `/DEFAULTLIB:LIBUCRT` indicate the static Release CRT family associated with `/MT`.
- Names ending in `D`, such as `LIBCMTD`, are Debug-runtime defaults and are invalid in these Release artifacts.
- Matching is case-insensitive and must account for quoted and unquoted directive output.

The artifact verifier must treat `LIBVCRUNTIME` and `LIBUCRT` as static evidence, not as dynamic evidence. It must match complete default-library names so that `VCRUNTIME` does not accidentally match the substring inside `LIBVCRUNTIME`.

The repository currently publishes Windows x86, x64, and ARM64 variants. Every architecture is required for acceptance.

The release dependency graph is:

    zlib-ng
       |
       v
    libpng
       |
       v
      skia

Skia also has a direct edge from `zlib-ng`:

    zlib-ng ------> skia

All other in-scope libraries are independent of this graph for the purpose of this task.

## Plan of Work

### Milestone 1: Establish the baseline and exact artifact inventory

Start from the repository root. Record the current commit, branch, default branch, and working-tree state. Do not discard unrelated changes.

Read all eight build workflows and all package scripts. For each Windows matrix entry, record:

- the architecture;
- the build directory;
- the install directory;
- the package archive path or raw `.lib` path;
- every `.lib` expected inside the artifact;
- whether the build is direct CMake, nested CMake through `ExternalProject`, or GN/Ninja.

Use `git grep` rather than assumptions to find all `.lib`, `package-artifact`, `cmake -S`, `ExternalProject_Add`, `windows_gn_args`, and upload paths.

Download the latest published Windows assets for all eight libraries into a temporary directory. Preserve the selected release tags in the living plan. Do not yet decide the release set from source inspection alone; the binary audit in Milestone 4 is the authority.

At the end of this milestone, the plan must contain a concise inventory and no in-scope Windows artifact path may be unknown.

### Milestone 2: Add one reusable runtime policy and one final-artifact verifier

Create `cmake/TotalCrossWindowsStaticRuntime.cmake`. It must be safe on non-Windows platforms and must establish the repository policy before a CMake project enables the MSVC language.

The module must:

- return immediately when the compiler is not MSVC-compatible;
- set policy `CMP0091` to `NEW` when available;
- set `CMAKE_MSVC_RUNTIME_LIBRARY` to `MultiThreaded` in the cache with `FORCE`;
- emit a concise status line showing that the TotalCross Windows runtime policy is `/MT`;
- avoid modifying generic `CMAKE_C_FLAGS` or `CMAKE_CXX_FLAGS`.

Include this module after `cmake_minimum_required` and before `project` in:

- `zlib-ng/CMakeLists.txt`
- `zlib/CMakeLists.txt`
- `libpng/CMakeLists.txt`
- `libjpeg/CMakeLists.txt`
- `libjpeg-turbo/CMakeLists.txt`
- `mbedtls/CMakeLists.txt`
- `sqlite3/CMakeLists.txt`

`sqlite3/CMakeLists.txt` currently declares a CMake minimum older than the runtime abstraction. Raise its minimum to the same supported baseline used by the other wrappers, at least CMake 3.16.

For `libjpeg-turbo/CMakeLists.txt`, also forward the runtime policy into `TC_LIBJPEG_TURBO_CMAKE_ARGS`, because its nested `ExternalProject` has an independent CMake cache. Pass both:

    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded

Also set the upstream libjpeg-turbo option that disables CRT DLL use when that option exists for the pinned upstream version:

    -DWITH_CRT_DLL=OFF

Do not assume the parent cache reaches the nested configure. Confirm the nested cache after a Windows build.

Create `.github/scripts/verify-windows-static-runtime.ps1`. Use approved PowerShell syntax and an SPDX header consistent with repository policy. The script must accept:

- one or more direct `.lib` paths, directories, glob patterns, or `.tar.gz` artifact paths;
- a configuration argument whose default is `Release`;
- an optional JSON output path.

The script must:

1. Resolve all inputs and fail when an input matches nothing.
2. Extract each `.tar.gz` into a unique temporary directory.
3. Discover every `.lib` recursively.
4. Fail when an artifact contains no `.lib`.
5. Locate `dumpbin.exe` by trying `Get-Command dumpbin.exe`, then `vswhere.exe` under the standard Visual Studio Installer directory.
6. Run `dumpbin.exe /nologo /directives` for every `.lib`.
7. Parse complete `/DEFAULTLIB` names case-insensitively.
8. In Release mode, fail if any library contains `MSVCRT`, `MSVCRTD`, `VCRUNTIME`, `VCRUNTIMED`, `UCRT`, or `UCRTD` without the `LIB` prefix.
9. In Release mode, fail if any library contains `LIBCMTD`, `LIBVCRUNTIMED`, or `LIBUCRTD`.
10. In Release mode, require at least `LIBCMT` evidence in every final library unless an explicitly documented exception is added for an archive whose members contain no compiler-generated directives.
11. Never silently allow an exception. Any exception must name the exact library, explain why it has no CRT-bearing object, and have a fixture or artifact test proving that the exception cannot hide `/MD`.
12. Print a compact console summary and optionally emit structured JSON containing artifact path, library path, detected default libraries, result, and failure reason.
13. Remove temporary extraction directories in a `finally` block.
14. Return a nonzero exit code on any failure.

Create `.github/scripts/test-windows-static-runtime-validator.ps1`. The test must build tiny COFF static libraries on `windows-2022`:

- compile one C source with `/MT`, archive it with `lib.exe`, and prove the verifier succeeds;
- compile the same source with `/MD`, archive it, and prove the verifier fails;
- compile with `/MTd`, archive it, and prove Release verification fails;
- create or provide an empty/no-directive archive and prove the verifier fails clearly;
- package the `/MT` fixture into `.tar.gz` and prove archive extraction plus validation succeeds.

Create `.github/workflows/validate-windows-static-runtime-policy.yml`. Run the fixture test on `windows-2022` for pull requests, pushes to the default branch, and manual dispatch. Limit its path filters to the shared policy, verifier, verifier tests, the validation workflow, and relevant repository guidance.

Update `AGENTS.md` with a Windows subsection stating:

- every Windows static library must use `/MT`;
- CMake wrappers must include `cmake/TotalCrossWindowsStaticRuntime.cmake` before `project`;
- nested CMake builds must receive `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded`;
- non-CMake builds must set the equivalent compiler option explicitly;
- every Windows build must run the artifact verifier before upload;
- `vcruntime` is excluded because it packages prebuilt DLLs;
- no new Windows static-library workflow is acceptable without x86, x64, and ARM64 runtime verification.

At the end of this milestone, the fixture workflow must distinguish `/MT`, `/MD`, and `/MTd` correctly.

### Milestone 3: Wire policy and final-artifact validation into all Windows builds

Modify the Windows job in each CMake build workflow:

- `.github/workflows/build-zlib-ng.yml`
- `.github/workflows/build-zlib.yml`
- `.github/workflows/build-libpng.yml`
- `.github/workflows/build-libjpeg.yml`
- `.github/workflows/build-libjpeg-turbo.yml`
- `.github/workflows/build-mbedtls.yml`
- `.github/workflows/build-sqlite3.yml`

After build and install, and after packaging when the workflow creates a `.tar.gz`, add a distinct PowerShell step named `Verify static MSVC runtime`. Pass the exact archive path that the subsequent upload step uses. The verifier must run before `actions/upload-artifact`.

The validation step must inspect all `.lib` files inside the archive. It must not use `continue-on-error`, `|| true`, or an `if` condition that permits upload after failure.

Add the shared policy and verifier paths to each workflow's `push` and `pull_request` path filters so a policy change exercises the relevant build. If running all seven full builds on every verifier-only edit is judged too expensive during implementation, retain the lightweight fixture workflow as the mandatory verifier regression test and document the narrower path-filter choice in `Decision Log`; do not remove artifact validation from actual builds.

Modify `.github/workflows/build-skia.yml`:

- include `.github/scripts/verify-windows-static-runtime.ps1` and `skia/scripts/common.sh` in the relevant path filters;
- in the Windows matrix, invoke the verifier against `skia/dist/libskia-windows-${arch}.lib` after the existing artifact checks and before upload;
- keep validation on x86, x64, and ARM64;
- optionally verify the merged release asset again in `package-release-assets` only if that job runs on Windows or the archive is returned to a Windows verification job. The per-architecture pre-upload check is mandatory.

Modify `skia/scripts/common.sh` in `windows_gn_args` so both `extra_cflags` and `extra_cxxflags` include `/MT`. Preserve the existing optimization, warning, include, and linker flags. Ensure `/MT` is not later overridden by `/MD`; use generated command lines and final archive directives as proof.

Update the Skia build manifest or diagnostics generation, if necessary, so the final `build_config_manifest-windows-*.md` visibly contains the `/MT` argument. Extend the existing workflow artifact checks to grep for that value. This is secondary evidence; the `dumpbin` result remains authoritative.

At the end of this milestone, every Windows build path must have explicit configuration plus artifact-level verification.

### Milestone 4: Audit existing releases and calculate the release set

Run the new verifier against the latest published Windows assets selected in Milestone 1. Perform this audit on a Windows machine or a temporary Windows GitHub Actions run so `dumpbin.exe` is available. Do not overwrite downloaded artifacts.

For each library and architecture, record:

- release tag;
- asset filename;
- each `.lib` discovered;
- detected default libraries;
- pass or fail;
- failure reason.

A library is directly affected when at least one currently published Windows artifact fails, or when implementation proves its build previously selected `/MD` and therefore requires a corrected artifact.

Calculate the transitive release closure:

- If `zlib-ng` is directly affected, add `libpng` and `skia`.
- If `libpng` is directly affected, add `skia`.
- If `skia` is directly affected, add only `skia`.
- `zlib`, `libjpeg`, `libjpeg-turbo`, `mbedtls`, and `sqlite3` are independent and are added only when directly affected.
- Wiring the verifier into an already-correct build does not by itself add that library to the release set.

Record two lists:

- Directly affected libraries.
- Transitively affected libraries and the dependency edge that caused inclusion.

Before proceeding, run each affected reusable build workflow from the correction branch. Every x86, x64, and ARM64 job must pass the verifier. A failing job means the implementation is incomplete; do not weaken the verifier to obtain a green build.

### Milestone 5: Commit and push the correction

Review the diff and ensure it contains no generated build directories, downloaded release assets, credentials, or unrelated user changes.

Run repository-level static checks and workflow syntax validation. Use `actionlint` when available. Run PowerShell parser checks and the fixture workflow. Run `git diff --check`.

Commit the implementation with a Conventional Commits message in English. The expected primary commit is:

    fix(windows): enforce static runtime for static libraries

The commit body must explain:

- that static Windows libraries were not uniformly guaranteed to use `/MT`;
- that CMake, nested `ExternalProject`, and GN paths are now explicit;
- that final `.lib` directives are inspected before upload;
- that `vcruntime` is intentionally excluded;
- that release propagation follows `zlib-ng -> libpng -> skia`.

Push the branch. Record the correction commit SHA as `CORRECTION_COMMIT`. No release workflow may be dispatched before this commit is available on GitHub.

If implementation required multiple logical commits, identify the final commit containing the complete correction and use that SHA for ancestry validation.

### Milestone 6: Dispatch affected releases in dependency order

Authenticate `gh` with Actions and contents write permissions. Resolve the branch or tag ref that contains `CORRECTION_COMMIT`; call it `RELEASE_REF`.

Before each dispatch, record:

- workflow filename;
- current `RELEASE_REF` head SHA;
- dispatch timestamp;
- latest preexisting release tag for that library.

Use `gh workflow run <workflow> --ref "$RELEASE_REF"`.

The scheduler must obey this graph.

Wave A contains all affected roots that have no affected prerequisite:

- `release-zlib-ng.yml`, when `zlib-ng` is affected;
- `release-zlib.yml`, when `zlib` is affected;
- `release-libjpeg.yml`, when `libjpeg` is affected;
- `release-libjpeg-turbo.yml`, when `libjpeg-turbo` is affected;
- `release-mbedtls.yml`, when `mbedtls` is affected;
- `release-sqlite3.yml`, when `sqlite3` is affected;
- `release-libpng.yml`, only when `libpng` is affected and `zlib-ng` is not being released;
- `release-skia.yml`, only when `skia` is affected and neither `zlib-ng` nor `libpng` is being released.

Dispatch all eligible Wave A workflows without waiting between unrelated libraries. Capture the run ID for each dispatch by matching workflow, event `workflow_dispatch`, head SHA, and dispatch time. Do not use only “latest run” when another maintainer could dispatch concurrently.

When `zlib-ng` is in the release set:

1. Wait for its exact run ID with `gh run watch <id> --exit-status`.
2. Identify the newly published tag by comparing the latest matching release before and after the run.
3. Verify that the GitHub Release exists and has Windows x86, x64, and ARM64 assets.
4. Download and run the verifier against those assets.
5. Update every repository default pin that still points to the old zlib-ng release. At minimum inspect `zlib-ng/manifest.yml`, `zlib-ng/fetch.sh`, and `deps.yml`; use `git grep` for the old tag so no hard-coded default is missed.
6. Commit and push the pin update with a message such as:

       chore(zlib-ng): update static runtime release

7. Advance `RELEASE_REF` to the pushed commit.
8. Only then dispatch `release-libpng.yml` when `libpng` is in the release set.

When `libpng` is in the release set:

1. Wait for its exact run ID.
2. Verify the newly published release and all Windows assets.
3. Prove from workflow logs that it fetched the intended zlib-ng release tag.
4. Run the verifier against the published libpng Windows assets.
5. Update every repository default pin that still points to the old libpng release. At minimum inspect `libpng/manifest.yml`, `libpng/fetch.sh`, and `deps.yml`; use `git grep` for the old tag.
6. Commit and push the pin update with a message such as:

       chore(libpng): update static runtime release

7. Advance `RELEASE_REF` to the pushed commit.
8. Confirm that `zlib-ng/manifest.yml` and `libpng/manifest.yml` now name the releases just verified.
9. Only then dispatch `release-skia.yml` when `skia` is in the release set.

When dispatching Skia, record the manifest values from the exact dispatch commit. The build must fetch those pins through `skia/scripts/fetch-prebuilt-deps.sh`. Verify the workflow logs show the intended dependency releases, or add concise logging if the current output is insufficient.

If a prerequisite release fails, stop only its dependent branch of the graph. Unrelated already-running releases may continue. Fix the cause in a new commit, push, rerun the failed build or release, and record the superseded run. Never dispatch a dependent release from a failed or unverified prerequisite.

### Milestone 7: Verify published releases and close the plan

For every directly or transitively affected library:

1. Confirm the exact release workflow run concluded `success`.
2. Confirm a new GitHub Release was published after the correction.
3. Confirm the release is neither draft nor prerelease unless repository policy explicitly requires otherwise.
4. Confirm its tag commit contains `CORRECTION_COMMIT` as an ancestor.
5. Confirm all expected Windows architectures are present.
6. Download the exact published Windows assets.
7. Run the same verifier used by the build workflows.
8. Confirm no dynamic or Debug CRT defaults are present.
9. Confirm `LIBCMT` static Release evidence is present.
10. Record the release tag, URL, workflow run ID, workflow run URL, dispatch commit, and verifier summary.

For Skia, verify the raw Windows `.lib` assets for x86, x64, and ARM64. For the other libraries, verify each packaged Windows `.tar.gz`.

The plan is complete only when every library in the calculated release set has a verified release entry. “Workflow succeeded” alone is not completion. “Tag exists” alone is not completion. “Artifact uploaded” alone is not completion.

Reconcile the living sections and finalize the `Editorial Report`.

## Concrete Steps

Run all commands from the repository root unless a different working directory is stated.

### Capture repository state

    git status --short
    git branch --show-current
    git rev-parse HEAD
    gh auth status
    gh repo view TotalCross/totalcross-depot-tools \
      --json defaultBranchRef \
      --jq '.defaultBranchRef.name'

Record the results in `Progress` and `Surprises & Discoveries`.

### Inventory Windows build and release paths

    git grep -nE 'build-windows|windows-\$\{\{ matrix\.arch \}\}|package-artifact|\.lib|workflow_dispatch' \
      -- .github/workflows '*/*.yml' '*/*.sh' '*/*.ps1' '*CMakeLists.txt'

    git grep -nE 'ExternalProject_Add|FetchContent|add_subdirectory|windows_gn_args|extra_cflags|extra_cxxflags' \
      -- '*CMakeLists.txt' skia/scripts

    git grep -nE '^release:|release_tag=|default: .*-[0-9]' \
      -- deps.yml '*/manifest.yml' '*/fetch.sh'

### Implement the shared policy and verifier

After creating the files, check PowerShell syntax:

    pwsh -NoProfile -Command '
      $errors = $null
      [void][System.Management.Automation.Language.Parser]::ParseFile(
        ".github/scripts/verify-windows-static-runtime.ps1",
        [ref]$null,
        [ref]$errors
      )
      if ($errors.Count) {
        $errors | Format-List
        exit 1
      }
    '

    pwsh -NoProfile -Command '
      $errors = $null
      [void][System.Management.Automation.Language.Parser]::ParseFile(
        ".github/scripts/test-windows-static-runtime-validator.ps1",
        [ref]$null,
        [ref]$errors
      )
      if ($errors.Count) {
        $errors | Format-List
        exit 1
      }
    '

Check that every CMake wrapper includes the shared policy before `project`:

    for file in \
      zlib-ng/CMakeLists.txt \
      zlib/CMakeLists.txt \
      libpng/CMakeLists.txt \
      libjpeg/CMakeLists.txt \
      libjpeg-turbo/CMakeLists.txt \
      mbedtls/CMakeLists.txt \
      sqlite3/CMakeLists.txt
    do
      echo "== $file =="
      grep -nE 'cmake_minimum_required|TotalCrossWindowsStaticRuntime|project\(' "$file"
    done

Expected ordering in every file is `cmake_minimum_required`, shared policy include, then `project`.

Check the nested libjpeg-turbo configure:

    grep -nE 'CMAKE_POLICY_DEFAULT_CMP0091|CMAKE_MSVC_RUNTIME_LIBRARY|WITH_CRT_DLL' \
      libjpeg-turbo/CMakeLists.txt

Check the Skia GN flags:

    grep -nE 'windows_gn_args|extra_cflags|extra_cxxflags|/MT' \
      skia/scripts/common.sh

### Run static validation

    git diff --check

    ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "yaml ok"' \
      deps.yml */manifest.yml .github/workflows/*.yml

    if command -v actionlint >/dev/null 2>&1; then
      actionlint
    fi

Do not treat a local YAML parse as a substitute for GitHub Actions execution.

### Dispatch the lightweight verifier test workflow

    gh workflow run validate-windows-static-runtime-policy.yml --ref "$(git branch --show-current)"

Poll for the exact run and then:

    gh run watch <validator-run-id> --exit-status
    gh run view <validator-run-id> --log

The log must show:

- `/MT` fixture accepted;
- `/MD` fixture rejected;
- `/MTd` fixture rejected in Release mode;
- no-directive fixture rejected;
- packaged `/MT` fixture accepted.

### Run affected build workflows before release

For each in-scope workflow changed by the implementation, dispatch its reusable build workflow manually from the correction branch, or let the pull-request trigger run it. Examples:

    gh workflow run build-zlib-ng.yml --ref "$RELEASE_REF"
    gh workflow run build-zlib.yml --ref "$RELEASE_REF"
    gh workflow run build-libpng.yml --ref "$RELEASE_REF"
    gh workflow run build-libjpeg.yml --ref "$RELEASE_REF"
    gh workflow run build-libjpeg-turbo.yml --ref "$RELEASE_REF"
    gh workflow run build-mbedtls.yml --ref "$RELEASE_REF"
    gh workflow run build-sqlite3.yml --ref "$RELEASE_REF"
    gh workflow run build-skia.yml --ref "$RELEASE_REF"

Capture exact run IDs. Every Windows matrix job must contain a successful `Verify static MSVC runtime` step.

### Commit the correction

    git status --short
    git diff --stat
    git diff --check
    git add \
      AGENTS.md \
      cmake/TotalCrossWindowsStaticRuntime.cmake \
      .github/scripts/verify-windows-static-runtime.ps1 \
      .github/scripts/test-windows-static-runtime-validator.ps1 \
      .github/workflows/validate-windows-static-runtime-policy.yml \
      .github/workflows/build-zlib-ng.yml \
      .github/workflows/build-zlib.yml \
      .github/workflows/build-libpng.yml \
      .github/workflows/build-libjpeg.yml \
      .github/workflows/build-libjpeg-turbo.yml \
      .github/workflows/build-mbedtls.yml \
      .github/workflows/build-sqlite3.yml \
      .github/workflows/build-skia.yml \
      zlib-ng/CMakeLists.txt \
      zlib/CMakeLists.txt \
      libpng/CMakeLists.txt \
      libjpeg/CMakeLists.txt \
      libjpeg-turbo/CMakeLists.txt \
      mbedtls/CMakeLists.txt \
      sqlite3/CMakeLists.txt \
      skia/scripts/common.sh

Inspect the staged set. Remove paths that were not actually changed; add any legitimate test or documentation path created during implementation. Never stage unrelated changes.

    git diff --cached --check
    git commit -m "fix(windows): enforce static runtime for static libraries" \
      -m "Configure CMake, nested ExternalProject, and Skia GN builds to use /MT and reject Windows artifacts whose final COFF directives select the dynamic or debug MSVC runtime. Verify x86, x64, and ARM64 artifacts before upload. vcruntime remains excluded because it packages prebuilt redistributable DLLs."
    git push

    CORRECTION_COMMIT="$(git rev-parse HEAD)"
    echo "$CORRECTION_COMMIT"

### Dispatch and track releases

Define a helper that records the dispatch SHA and polls for the matching run rather than blindly selecting the latest run. An implementation may use `gh run list --json databaseId,workflowName,headSha,event,createdAt,status,conclusion,url` and filter by all known fields.

Dispatch independent roots without waiting between commands:

    gh workflow run release-zlib-ng.yml --ref "$RELEASE_REF"
    gh workflow run release-zlib.yml --ref "$RELEASE_REF"
    gh workflow run release-libjpeg.yml --ref "$RELEASE_REF"
    gh workflow run release-libjpeg-turbo.yml --ref "$RELEASE_REF"
    gh workflow run release-mbedtls.yml --ref "$RELEASE_REF"
    gh workflow run release-sqlite3.yml --ref "$RELEASE_REF"

Run only workflows present in the calculated release set.

Watch a captured run:

    gh run watch <run-id> --exit-status
    gh run view <run-id> --json databaseId,headSha,status,conclusion,url,workflowName

Inspect a release:

    gh release view <tag> \
      --json tagName,url,isDraft,isPrerelease,publishedAt,assets

Download its Windows assets into a clean temporary directory:

    rm -rf .tmp/windows-runtime-release-audit/<library>/<tag>
    mkdir -p .tmp/windows-runtime-release-audit/<library>/<tag>
    gh release download <tag> \
      --pattern '*windows-*' \
      --dir .tmp/windows-runtime-release-audit/<library>/<tag>

The actual binary verification must run on Windows:

    pwsh -NoProfile -File .github/scripts/verify-windows-static-runtime.ps1 `
      -ArtifactPath ".tmp/windows-runtime-release-audit/<library>/<tag>/*windows*" `
      -Configuration Release `
      -JsonOutput ".tmp/windows-runtime-release-audit/<library>/<tag>/runtime-verification.json"

Update pins after a prerequisite release:

    old_tag="<old-tag>"
    new_tag="<new-tag>"
    git grep -n --fixed-strings "$old_tag" -- \
      deps.yml zlib-ng libpng skia .github || true

Edit every default pin that is intended to track the new release, run validation, commit, and push before dispatching the dependent workflow.

Verify tag ancestry:

    git fetch --tags origin
    git merge-base --is-ancestor "$CORRECTION_COMMIT" "<tag>^{commit}"

A zero exit status is required.

## Validation and Acceptance

The implementation is accepted only when all of the following observable behaviors are true.

### Policy behavior

A new CMake-built Windows dependency that includes `cmake/TotalCrossWindowsStaticRuntime.cmake` before `project` configures with `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded`.

A nested CMake configure in libjpeg-turbo receives the same runtime setting and has CRT DLL use disabled.

The Skia Windows GN args visibly contain `/MT` for C and C++ compilation.

`AGENTS.md` describes the mandatory rule and the verifier requirement.

### Verifier behavior

The fixture workflow proves:

- an `/MT` Release archive exits zero;
- an `/MD` archive exits nonzero and names the offending default libraries;
- an `/MTd` archive exits nonzero in Release mode;
- an artifact with no `.lib` exits nonzero;
- a `.lib` with no acceptable static-runtime evidence exits nonzero unless a documented narrow exception exists;
- a `.tar.gz` containing a valid `/MT` library exits zero;
- JSON output is valid and identifies every inspected `.lib`.

### Build behavior

For each of the eight in-scope library families, every Windows x86, x64, and ARM64 build reaches and passes `Verify static MSVC runtime` before upload.

No upload step runs after a verifier failure.

The exact archive uploaded by each CMake workflow is the archive inspected by the verifier.

The exact raw Skia `.lib` uploaded by each Windows matrix entry is inspected.

### Release behavior

The baseline audit identifies direct failures from actual published artifacts, not assumptions.

The calculated release set includes downstream closure:

- changed `zlib-ng` implies new `libpng` and `skia`;
- changed `libpng` implies new `skia`.

Independent workflows are dispatched in parallel.

A dependent workflow starts only after every changed prerequisite release is successful, published, artifact-verified, and pinned in the dispatch commit.

Every affected release:

- has a successful workflow run;
- has a published GitHub Release;
- has x86, x64, and ARM64 Windows assets;
- has `CORRECTION_COMMIT` in tag ancestry;
- passes the final artifact verifier after download from GitHub.

The plan is not complete until the tag and release URL of every affected library are recorded in `Outcomes & Retrospective` and `Editorial Report`.

## Idempotence and Recovery

The CMake policy include, workflow verification steps, and `AGENTS.md` rule are additive and may be applied repeatedly without changing generated output.

The verifier uses unique temporary extraction directories and removes them in `finally`, so interrupted audits may be rerun safely. Remove `.tmp/windows-runtime-release-audit` manually when desired; it must not be committed.

Build workflow dispatch is safe to repeat because it does not publish releases. Release workflow dispatch is not automatically safe to repeat because it can create a new incremented release tag. Before retrying a release:

1. Inspect whether the failed run created a tag.
2. Inspect whether it published a release.
3. Inspect whether a metadata commit was pushed.
4. Do not delete a published release or tag unless repository policy and a human maintainer explicitly approve.
5. Prefer fixing the cause and allowing the existing next-tag logic to create a new revision.
6. Record abandoned or superseded tags and runs in the plan.

If a pin-update commit fails halfway, use `git status`, inspect the exact files, and either complete the same logical commit or restore only the files changed by this task. Never reset unrelated work.

If `zlib-ng` succeeds but `libpng` fails, retain the verified zlib-ng release and pin. Fix libpng and rerun only libpng, then continue to Skia.

If an unrelated root release fails while the `zlib-ng -> libpng -> skia` chain is progressing, the chain may continue. The plan closes only after the unrelated failure is also resolved and released.

If Skia fails after dependency pins are updated, do not roll back verified upstream releases. Fix Skia in a new commit and rerun `release-skia.yml`.

If a published artifact fails the final downloaded verification despite passing the build job, treat this as a packaging or asset-selection defect. Stop completion, compare workflow artifacts with release assets, correct the packaging path, and publish a new release revision.

## Artifacts and Notes

Keep concise evidence during execution. Do not paste full build logs into this plan.

For each baseline and final audit, retain a JSON summary outside Git tracking under:

    .tmp/windows-runtime-release-audit/<library>/<tag>/runtime-verification.json

For each release, record in the living plan:

- library;
- direct or transitive reason;
- correction or pin commit used for dispatch;
- workflow filename;
- run ID and URL;
- release tag and URL;
- Windows asset names;
- verifier result;
- dependency tags observed by the build.

Useful concise directive evidence resembles:

    library: zlib.lib
    default libraries: LIBCMT, OLDNAMES
    result: PASS

A failing excerpt should name exact tokens:

    library: png_static.lib
    forbidden default libraries: MSVCRT, VCRUNTIME, UCRT
    result: FAIL

Do not retain downloaded release assets in the repository.

## Interfaces and Dependencies

### `cmake/TotalCrossWindowsStaticRuntime.cmake`

This file is the CMake-facing policy interface. It must be included before `project` or language enablement. Its externally observable result on MSVC-compatible Windows builds is:

    CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded

It must be a no-op on non-MSVC toolchains.

### `.github/scripts/verify-windows-static-runtime.ps1`

The final script should expose parameters equivalent to:

    param(
      [Parameter(Mandatory = $true, Position = 0)]
      [string[]] $ArtifactPath,

      [ValidateSet("Release")]
      [string] $Configuration = "Release",

      [string] $JsonOutput
    )

Names may vary only when the final invocation remains clear and stable. The script must support direct `.lib` files and packaged `.tar.gz` artifacts.

The JSON result should be stable enough for future CI consumption. A recommended shape is:

    {
      "configuration": "Release",
      "artifacts": [
        {
          "path": "...",
          "libraries": [
            {
              "path": "...",
              "defaultLibraries": ["LIBCMT", "OLDNAMES"],
              "result": "pass",
              "reason": null
            }
          ],
          "result": "pass"
        }
      ],
      "result": "pass"
    }

Do not include full `dumpbin` output in JSON unless a failure requires a concise excerpt.

### `.github/scripts/test-windows-static-runtime-validator.ps1`

This script is the verifier's executable contract. It creates deterministic `/MT`, `/MD`, `/MTd`, no-directive, and packaged fixtures and exits nonzero when expected behavior changes.

### Build workflow contract

Every in-scope Windows build job must execute in this order:

    checkout
    dependency fetch, when applicable
    configure
    build
    install or stage
    package, when applicable
    verify static MSVC runtime
    upload artifact

No upload may precede verification.

### Release workflow contract

Release workflows continue to call reusable build workflows. Therefore, artifact verification is automatically part of release publication.

Release orchestration uses these dependency edges:

    zlib-ng -> libpng
    zlib-ng -> skia
    libpng -> skia

No edge exists from `zlib` to `libpng`; current libpng builds use `zlib-ng`.

### External tools

The implementation uses:

- CMake 3.16 or newer for `CMP0091` and `CMAKE_MSVC_RUNTIME_LIBRARY`.
- Visual Studio 2022 compiler tools and `dumpbin.exe`.
- PowerShell 7 on GitHub-hosted Windows runners.
- `gh` for workflow dispatch, run inspection, release inspection, and asset download.
- `actionlint` when available for local workflow validation.
- Git for commit ancestry and pin management.

Do not add a third-party binary parser unless `dumpbin` proves technically insufficient. If that happens, record the failure and decision before changing the interface.

## Revision Note

2026-07-17: Initial plan created from the supplied ExecPlan template and current repository inspection. It establishes explicit `/MT` configuration for CMake, nested `ExternalProject`, and Skia GN builds; final `.lib` directive validation; baseline release auditing; affected-library calculation; dependency-aware release sequencing; release-pin updates; and final GitHub Release verification. `vcruntime` is excluded because it only fetches and packages prebuilt redistributable DLLs.
