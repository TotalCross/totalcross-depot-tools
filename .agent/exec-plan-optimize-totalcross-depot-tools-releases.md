# Reduce release build time without changing library capabilities

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, `Outcomes & Retrospective`, and `Editorial Report` must be kept up to date as work proceeds.

This repository contains `.agent/PLANS.md`. Maintain this document in accordance with that file. A person or coding agent must be able to resume the work using only the repository and this ExecPlan, without access to the conversation that produced it.

## Purpose / Big Picture

The repository currently builds and publishes many small native libraries through independent GitHub Actions matrices. Each job starts a fresh runner, so releases repeatedly perform checkout, toolchain setup, source downloads, artifact upload, artifact download, and packaging. After this work, maintainers will be able to publish the same separate library releases with fewer runner allocations, less repeated setup, narrower dependency-triggered rebuilds, and reusable platform-oriented build paths.

The result will be visible in GitHub Actions. Android jobs will no longer reinstall the pinned NDK. Native Linux jobs will use minimal purpose-built images. Release workflows will start builds without standalone metadata-only preparation jobs. Changes to `deps.yml` will trigger only actual consumers. Batch workflows will build related libraries on the same platform runner while still generating distinct artifacts, tags, GitHub Releases, and bundle pins. SQLite will remain an isolated workflow. The final ARMv7 Skia cross-build experiment will be attempted only after all safer optimizations and will retain the current QEMU path unless equivalence is proven.

This plan does not change which library features are compiled and does not move builds to larger GitHub-hosted runners. Those subjects require separate plans because they affect the public capability set, artifact size, cost, and compatibility assumptions.

## Progress

- [x] (2026-07-17 19:58Z) Inspected the current release and build workflow structure, dependency index, Docker recipes, library wrappers, and Skia scripts.
- [x] (2026-07-17 19:58Z) Recorded the scope decisions: minimal Docker images are the second implementation priority; Skia ARMv7 cross-build is last; libjpeg and libjpeg-turbo belong to the Skia-oriented stack; QR and crypto libraries form one small, rarely updated group; SQLite remains separate; larger runners and feature-reducing compile options are excluded.
- [x] (2026-07-17 21:17Z) Routed semantic `deps.yml` changes with a tested Python/Ruby-safe parser and a conditional consumer workflow (Milestone 4, intentionally first at the user's request).
- [x] (2026-07-17 21:17Z) Captured compact baseline metrics for successful libpng and Skia workflows in `artifacts/ci-performance/baseline/` and added reproducible collection and Markdown-summary commands.
- [x] (2026-07-17 21:17Z) Replaced native-workflow Android SDK/NDK installation steps with `.github/actions/setup-android-native`, which verifies NDK 28.2.13676358 and exports its path.
- [x] (2026-07-17 21:17Z) Created minimal Bionic native CMake image definitions, a Skia amd64 image definition, image smoke coverage, and migrated native workflow image tags to `v2.0.0`.
- [x] (2026-07-17 21:17Z) Removed push triggers from build and policy workflows and consolidated commit-message and copyright validation into `.github/workflows/validate-commit.yml`, with one checkout and independent failure reporting.
- [x] (2026-07-17 23:10Z) Removed standalone metadata-only `prepare` jobs from every individual release wrapper. Dependency-release resolution stays in its consuming build job; release version/tag resolution now runs after the release job's existing checkout. The Visual C++ runtime derives its version from the x86 release artifact manifest, so it no longer needs an additional Windows runner.
- [x] (2026-07-17 21:17Z) Added `dry_run=true` as the safe default for individual release workflows; pin, tag, release, and Skia metadata-commit steps are skipped during validation-only dispatches.
- [x] (2026-07-17 22:42Z) Completed a GitHub Actions zlib dry-run (`29618567589`) across Linux, Windows, Android, macOS, iOS, and iOS Simulator; all build and packaging jobs succeeded and pin/tag/release steps were skipped.
- [x] (2026-07-17 21:17Z) Added shared native build and target-manifest primitives, plus guarded graphics and small-library dry-run orchestrators.
- [x] (2026-07-18 00:40Z) Extended `.github/actions/build-native-library` with the opt-in `run-tests` input (default `false`) and migrated the SLJIT macOS build to it with tests enabled.
- [x] (2026-07-18 00:27Z) Made the shared native build action configuration-aware for multi-config generators and migrated every CMake-based Windows build to it. Each build explicitly requests the `/MT` runtime; axTLS, minizip, minizip-ng, QR code generation, and SLJIT now also run the common final-artifact runtime verifier.
- [x] (2026-07-18 00:40Z) Added optional paired Docker image/platform inputs to the shared native build action and migrated all non-Skia Linux CMake builds to it. The action rejects partial Docker configuration and keeps native runner execution when both values are empty.
- [x] (2026-07-18 00:48Z) Migrated every Android CMake build to the shared native build action while preserving the NDK 28.2.13676358 toolchain, arm64-v8a ABI, per-library SDK levels, flexible-page-size option, and prebuilt zlib paths.
- [x] (2026-07-17 23:25Z) Kept SQLite independently dispatchable while migrating its Apple lane to the shared native CMake/package action. One arm64 macOS job now builds macOS, iOS device, and iOS Simulator artifacts, creates the XCFramework from the local installs, and uploads the same four artifact identities without an inter-job round trip.
- [x] (2026-07-17 23:55Z) Consolidated every Apple matrix and iOS packaging job into one `macos-15` job per dependency. Each job checks out once, builds macOS/iOS/simulator sequentially, creates its XCFramework from local install trees, and uploads the unchanged target archive and XCFramework artifact names. Remote macOS validation and before/after timing remain pending.
- [x] (2026-07-17 21:17Z) Stabilized Skia source cache inputs, bounded Linux/Android ccache, made diagnostics failure-or-explicit only, and added an isolated ARMv7 cross-build script while retaining QEMU.
- [ ] Run cold-cache and warm-cache end-to-end validation, compare the results with the baseline, and reconcile all evidence into `Outcomes & Retrospective` (blocked locally: Docker and actionlint/Go are unavailable; GitHub validation requires pushing the commit).
- [ ] Finish metadata-job removal, Apple consolidation, standalone SQLite migration, and real ARMv7 equivalence validation before claiming the optimization plan fully complete.

## Surprises & Discoveries

- Observation: A reusable workflow does not reuse the caller's runner. Only steps in the same job share checkout, local Docker layers, downloaded sources, and installed tools.
  Evidence: The current release wrappers call build workflows as separate jobs, and every called workflow defines its own `runs-on` jobs and checkout steps.

- Observation: Several Android jobs install exactly the NDK version already expected to exist under `${ANDROID_HOME}/ndk/28.2.13676358` on `ubuntu-24.04`.
  Evidence: The build workflows call `android-actions/setup-android` and `sdkmanager "ndk;28.2.13676358" "cmake;3.22.1"` before referencing that same path in `CMAKE_TOOLCHAIN_FILE`.

- Observation: The generic Linux images include SDL, audio, X11, Wayland, and graphics development packages even when used for zlib, jpeg, SQLite, QR, or minizip.
  Evidence: `docker/linux-amd64/Dockerfile`, `docker/linux-arm32v7/Dockerfile`, and `docker/linux-arm64/Dockerfile` install broad graphical stacks; the ARM images also compile SDL during image creation.

- Observation: Changes to the single `deps.yml` file can trigger consumers whose actual dependency entry did not change.
  Evidence: `.github/workflows/build-libpng.yml`, `.github/workflows/build-minizip.yml`, `.github/workflows/build-minizip-ng.yml`, and `.github/workflows/build-skia.yml` include the whole file in path filters.

- Observation: Skia already contains ARMv7-oriented toolchain code, but the active ARMv7 build path does not provide a proven successful replacement for QEMU, and a prior attempt failed.
  Evidence: `skia/scripts/common.sh` contains ARMv7 argument generation while the current workflow still selects an ARMv7 Docker image and QEMU setup.

- Observation: This workstation has neither Docker nor Go/actionlint installed, so image smoke builds and actionlint cannot be run locally.
  Evidence: `docker version` returned `docker: command not found` and `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7` returned `go: command not found` on 2026-07-17.

- Observation: Ubuntu Bionic does not publish a `generate-ninja` package, and a Docker Hub tag may already exist when the image workflow is dispatched.
  Evidence: The Skia image publication failed with `Unable to locate package generate-ninja`; `.github/workflows/docker-linux-images.yml` now queries the Docker Hub tag endpoint before allocating build setup.

- Observation: Bionic's distribution CMake is too old for the repository's `cmake -S/-B` build interface and for CMake projects that require 3.16.
  Evidence: zlib Linux jobs using `v2.0.0` reported `The source directory "/sources/zlib/build/linux-amd64" does not exist`; the prior Bionic Dockerfiles used Kitware's CMake repository, whereas the minimized image had reverted to Bionic's CMake 3.10 package.

- Observation: The Skia Linux and Android dry-run failed before compilation because `ccache` was configured before the environment that supplies it.
  Evidence: run `29618569655` reported `/home/runner/work/_temp/...sh: line 1: ccache: command not found` in Linux and Android jobs. Linux compiles inside images that contain ccache, while Android installed ccache only in the next step.

Add new observations here as implementation proceeds. Every observation that changes the design must also result in a `Decision Log` entry.

## Decision Log

- Decision: Remove Android NDK reinstallation before any broader workflow restructuring.
  Rationale: It is repeated across many workflows, does not change public artifacts, and can be validated with a direct directory and version check.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Make minimal Docker images the second milestone.
  Rationale: The existing broad images impose repeated image transfer and contain dependencies unrelated to most libraries. Establishing the correct images early lets all later workflows use the optimized foundation.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Use one graphics, compression, and image stack containing zlib, zlib-ng, minizip, minizip-ng, libpng, libjpeg, libjpeg-turbo, and Skia.
  Rationale: These libraries share platform matrices and build infrastructure. libjpeg and libjpeg-turbo are included next to Skia even though current GN arguments disable them, because Skia may consume them in the future and the shared topology should not need another redesign.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Group qrcode, qrcodegen, axTLS, and mbedTLS as small and rarely updated; include vcruntime as a Windows-only lane in the same orchestrator when safe.
  Rationale: Their individual compilation time is generally small relative to runner startup and repeated setup, while their release identities must remain separate.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Keep SQLite separate.
  Rationale: SQLite has no dependency edge to the other groups, uses a specific amalgamation source flow, and gains little from being serialized with unrelated releases. It should reuse common actions without joining a batch.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Keep larger runners and library feature-reduction flags out of scope.
  Rationale: Larger runners change cost and capacity assumptions. Feature-reduction flags can change API or file-format capabilities. Both require independent compatibility and cost analysis after structural CI waste is removed.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Perform the Skia ARMv7 cross-build experiment last and preserve QEMU as the default until equivalence is proven.
  Rationale: A previous attempt failed, the risk is higher than the other optimizations, and it must not delay changes with clearer value and lower compatibility risk.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Implement release-stack workflows as guarded dry-run orchestrators before enabling publication.
  Rationale: They can validate component selection and reuse the existing artifact-producing workflows without creating tags or modifying the compatible bundle index from an unvalidated local change.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Treat an existing exact Docker Hub image tag as immutable and skip its image build and push.
  Rationale: The requested version is the publication identity. Rebuilding it can overwrite an already validated image and wastes QEMU, Buildx, checkout, and registry-cache work. A non-200/non-404 Docker Hub response fails rather than incorrectly treating an API failure as a missing image.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Publish corrected minimal Bionic images as `v2.0.1` and pin every affected native workflow to that version.
  Rationale: The image publication workflow deliberately treats version tags as immutable. Restoring the Kitware repository preserves the required CMake interface and version without restoring the removed desktop-graphics package set.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Resolve release metadata in the publication job, after its existing full-history checkout and before artifact publication.
  Rationale: The tag is only consumed by publication, so a separate metadata runner added latency without sharing useful build state. Visual C++ runtime metadata is read from the packaged x86 artifact rather than downloading the installer a second time on a dedicated Windows runner.
  Date/Author: 2026-07-17 / OpenAI

- Decision: Run Linux Skia ccache configuration, GN generation, and reporting inside the build image.
  Rationale: The ccache binary and mounted cache directory belong to the containerized compilation environment. This both fixes the missing-host-tool failure and ensures GN receives the ccache wrapper used for the actual compilation.
  Date/Author: 2026-07-17 / OpenAI

## Outcomes & Retrospective

The first implementation pass added semantic dependency routing, Android toolchain verification, minimal image definitions, baseline metrics collection, shared workflow primitives, dry-run stack orchestration, scoped Skia cache/diagnostic changes, metadata-job removal from individual release wrappers, and Apple consolidation across all dependency workflows. A zlib GitHub Actions dry-run on 2026-07-17 succeeded across its full platform matrix and skipped all state-changing publication steps. Local YAML, shell, Python, and router tests passed. No cold/warm comparison or Docker image smoke run was measured because this workstation has no Docker. Remote Apple validation, performance measurement, and ARMv7 equivalence remain incomplete and must not be represented as delivered.

At completion, compare the final state against the purpose of reducing repeated setup while preserving platform coverage and separate releases. State clearly whether the ARMv7 experiment succeeded or whether QEMU remained necessary.

## Editorial Report

This section is mandatory at completion. Keep it factual, evidence-based, and synchronized with the final implementation.

### Editorial Summary

The implementation pass reduces several repeated setup paths without changing library build flags: native Android jobs now verify the hosted NDK instead of installing it, native Linux image definitions no longer carry desktop graphics stacks, and dependency-pin changes route only to known consumers. The repository also has reproducible metric collection and dry-run batch entry points. No performance percentage is claimed because final comparable GitHub runs have not yet been made.

### Original Plan versus Actual Outcome

The implementation began with Milestone 4 at the user's request. Dependency routing, Android verification, image definitions, metrics collection, shared primitives, dry-run orchestrators, and part of the Skia cache/diagnostic work were delivered. Metadata-only release-job removal, true same-runner platform batching, Apple consolidation, SQLite migration, remote dry-run publication validation, and ARMv7 equivalence testing remain deferred. QEMU remains the production ARMv7 path.

### What Changed

Key additions are `.github/actions/setup-android-native/action.yml`, `.github/actions/build-native-library/action.yml`, `.github/scripts/diff-dependency-pins.py`, `.github/scripts/collect-workflow-metrics.py`, `.github/scripts/update-deps-releases-batch.py`, `.github/workflows/build-dependency-consumers.yml`, and the two guarded release-stack workflows. `docker/linux-*/Dockerfile` now define the smaller native images, while `docker/skia-linux-amd64/Dockerfile` provides the Skia-specific toolchain. `artifacts/ci-performance/baseline/` contains compact observations from pre-change GitHub runs.

### Decisions and Trade-offs

At completion, explain the measured trade-off between parallel jobs and runner reuse, the compatibility policy for Linux images, the chosen dependency routing design, and the reason ARMv7 did or did not move away from QEMU.

### Unexpected Problems and Discoveries

At completion, summarize problems that materially changed the implementation. Link each statement to concise evidence in `Surprises & Discoveries`, logs, commits, or generated metric files.

### Validation and Measurable Results

Observed local validation: `python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'` passed five dependency-router tests; Ruby parsed every workflow and new action; `bash -n` passed changed shell scripts; and `git diff --check` passed. Docker smoke and actionlint were not run because their executables are unavailable. The stored Skia and libpng baseline reports are reference data only, not a before/after result.

### Useful Evidence and Examples

At completion, point to the metrics JSON or Markdown summary, representative workflow runs, Docker image manifests, actionlint output, artifact manifests, and ARMv7 fixture results.

### Limitations, Remaining Work, and Open Questions

Larger runners and library feature-reduction options are intentionally deferred. At completion, add any remaining platform-specific limitations, queue variability, cache instability, or workflows that could not safely be consolidated.

### Possible Article Angles

- For CI maintainers: “Reducing native release time by organizing GitHub Actions around platforms instead of libraries.” The useful takeaway is how runner reuse can matter more than compilation speed for small native dependencies.
- For cross-platform build engineers: “Building separate native releases from a shared dependency stack without coupling their versioning.” The useful takeaway is how to share toolchains and intermediate dependencies while keeping independent artifacts and tags.
- For Skia integrators: “Separating source preparation, compilation caches, and diagnostics in a multi-platform Skia pipeline.” The useful takeaway is how to avoid repeating expensive source synchronization on every host.

### Suggested Narrative

Begin with the large number of separate native releases and the hidden cost of fresh runners. Explain why reusable workflows did not reuse state, then show the low-risk removals: Android setup and oversized Docker images. Describe the dependency router and platform-oriented stacks, including the need to preserve separate releases. Cover Apple and Skia-specific changes, present cold and warm measurements, discuss the failed-or-successful ARMv7 experiment, and close with the deliberately deferred work on larger runners and reduced feature sets.

### Claims Requiring Human Review

Any public claim about percentage time reduction, cost reduction, image size reduction, or cache hit improvement must be verified against the captured baseline and final runs. Statements about supported Linux compatibility, ARMv7 equivalence, or unchanged library capabilities require maintainer review before publication.

## Context and Orientation

`TotalCross/totalcross-depot-tools` builds static native dependencies for multiple TotalCross targets. The repository contains a directory for each dependency, reusable build workflows under `.github/workflows/`, release wrapper workflows that publish GitHub Releases, custom actions under `.github/actions/`, scripts under `.github/scripts/`, Docker recipes under `docker/`, and a compatible-version index in `deps.yml`.

A GitHub Actions runner is the temporary machine assigned to one job. A matrix expands one job definition into several independent jobs. A reusable workflow is a YAML workflow called by another workflow, but its jobs still receive new runners. An artifact is a file uploaded from one job so another job or the final release can download it. An XCFramework is Apple's package that combines libraries and headers for device and simulator targets.

The current common platform set is Linux x86_64, Linux ARMv7, Linux ARM64, Windows x86, Windows x64, Windows ARM64, Android arm64-v8a, macOS arm64, iOS arm64, iOS Simulator arm64, and, for Skia, WebAssembly. Most libraries expose a CMake wrapper and package script. The Linux workflows run those wrappers inside `totalcross/linux-*` Docker images. Apple and Windows build directly on hosted runners.

The principal workflows and files to inspect before editing are:

- `.github/workflows/release-*.yml`, which calculate metadata, invoke builds, download assets, update `deps.yml`, tag, and publish;
- `.github/workflows/build-zlib.yml`, `.github/workflows/build-zlib-ng.yml`, `.github/workflows/build-minizip.yml`, `.github/workflows/build-minizip-ng.yml`, `.github/workflows/build-libpng.yml`, `.github/workflows/build-libjpeg.yml`, `.github/workflows/build-libjpeg-turbo.yml`, and `.github/workflows/build-skia.yml`;
- `.github/workflows/build-qrcode.yml`, `.github/workflows/build-qrcodegen.yml`, `.github/workflows/build-qrcode-common.yml`, `.github/workflows/build-axtls.yml`, `.github/workflows/build-mbedtls.yml`, and `.github/workflows/build-vcruntime.yml`;
- `.github/workflows/build-sqlite3.yml`, which remains an isolated release path;
- `.github/workflows/docker-linux-images.yml` and `docker/linux-*/Dockerfile`;
- `.github/scripts/next-release-tag.sh`, `.github/scripts/read-deps-release.sh`, and the actions that pin or revert dependency releases;
- `deps.yml`, the current bundle index;
- `skia/scripts/common.sh`, `skia/scripts/fetch-source.sh`, platform build scripts, and `skia/scripts/run-ninja-with-summary.py`.

Before changing paths or workflow names, list the repository because some release files may have names not enumerated in this plan. Keep the plan synchronized with the actual tree.

## Scope and Non-Goals

The implementation must preserve all currently published platform artifacts, library names, include layouts, static runtime checks, manifests, checksums, XCFramework contents, release tags, and separate GitHub Release identities unless a verified existing defect requires correction.

Do not change GN, CMake, preprocessor, or source-selection options for the purpose of reducing library size or capabilities. In particular, do not make libjpeg read-only, disable libpng encoding, remove zlib deflate, remove minizip writing, trim mbedTLS algorithms, or disable Skia backends in this plan.

Do not move any job to a larger runner class. Keep existing runner labels unless a change is required to consolidate jobs on the same current class. `macos-15` must remain the Apple Silicon runner for iOS packaging.

Do not delete the current QEMU ARMv7 path until the final experiment passes all acceptance tests. A failed experiment is an acceptable result when it leaves the existing build intact and records useful evidence.

## Baseline and Measurement Model

Before implementation, collect the latest successful manual release run for at least zlib or libjpeg, libpng, qrcodegen, Skia, SQLite, and one small/crypto release. Also record a complete stack run once the batch workflow exists.

If the GitHub CLI is authenticated, run from the repository root:

    mkdir -p artifacts/ci-performance/baseline
    gh workflow list
    gh run list --limit 100 --json databaseId,workflowName,event,status,conclusion,createdAt,startedAt,updatedAt,headSha,url > artifacts/ci-performance/baseline/runs.json

Create `.github/scripts/collect-workflow-metrics.py` or an equivalent deterministic script. It must accept a run ID, query jobs and steps through `gh api`, and produce a compact JSON document containing:

- workflow name and run ID;
- event, head SHA, attempt, status, and conclusion;
- run start and finish timestamps;
- each job's runner label, start, finish, conclusion, and elapsed seconds;
- each step's start, finish, conclusion, and elapsed seconds when the API supplies them;
- count of jobs that obtained runners;
- artifact names and sizes;
- cache status when it can be parsed reliably;
- a distinction between queue time and execution time.

Do not scrape unrestricted full logs into the repository. Save only compact evidence. A typical command must be:

    python3 .github/scripts/collect-workflow-metrics.py \
      --repo TotalCross/totalcross-depot-tools \
      --run-id "$RUN_ID" \
      --output "artifacts/ci-performance/baseline/${RUN_ID}.json"

Add a companion summarizer that produces Markdown or CSV for human comparison. Include cache condition in every row. Compare cold runs with cold runs and warm runs with warm runs.

The measurement work is accepted when another maintainer can rerun the command for a run ID and obtain a valid compact document without manual editing.

## Milestone 4: Route dependency changes precisely and batch pin updates

This milestone is intentionally executed first. It prevents unrelated `deps.yml` edits from rebuilding consumers, and its deterministic routing provides a small, independently testable foundation for the later workflow consolidation. At its end, a change in one dependency entry will produce a deterministic set of affected workflows shown in the job summary.

Keep `deps.yml` as the authoritative compatible-version index. Create `.github/scripts/diff-dependency-pins.py`. It must accept two revisions or two file paths, parse the YAML safely, and emit both human-readable and machine-readable outputs identifying dependencies whose `version`, `release`, or relevant path fields changed.

Create `.github/workflows/build-dependency-consumers.yml`, triggered when `deps.yml` changes. Its first job checks out enough history to compare the previous and current versions, runs the diff script, and exposes booleans for consumer groups. Subsequent jobs call reusable workflows conditionally.

The initial dependency map must be explicit in a repository file or in the script:

- `zlib` affects minizip;
- `zlib-ng` affects libpng, minizip-ng, and Skia;
- `libpng` affects Skia;
- libjpeg and libjpeg-turbo do not currently affect Skia builds, but the map must be easy to extend when GN enables them;
- qrcode, qrcodegen, axTLS, mbedTLS, SQLite, and vcruntime have no current consumers in this repository.

Remove `deps.yml` from broad path filters in the individual consumer workflows after the router is active. Keep direct triggers for source, scripts, manifests, CMake wrappers, and the workflow itself.

For batch releases, modify the publication implementation to collect all new tags first, publish each separate GitHub Release, and update all selected `deps.yml` entries in one commit. A failure before all releases are valid must not leave a partially updated bundle index. If some releases were already published, do not delete them automatically; record the partial result and make the retry idempotently detect existing tags and releases.

Add tests for the diff script. Use fixtures where only mbedTLS changes, only zlib-ng changes, libpng changes, several entries change, and formatting changes without semantic changes.

Acceptance requires the mbedTLS fixture to select no graphics consumers, the zlib-ng fixture to select exactly libpng, minizip-ng, and Skia, and a real test branch or pull request to display the same routing in GitHub Actions.

## Milestone 1: Stop reinstalling the Android NDK

This milestone removes repeated Android SDK setup while preserving the exact NDK version. At its end, every Android build will verify and use the preinstalled toolchain, and a shared implementation will prevent future workflows from reintroducing `sdkmanager` unnecessarily.

Create a composite action such as `.github/actions/setup-android-native/action.yml`. It must accept `ndk-version`, defaulting to `28.2.13676358`, and expose `ndk-path`. The action must:

1. derive `${ANDROID_HOME}/ndk/<version>`;
2. verify that the directory and `build/cmake/android.toolchain.cmake` exist;
3. write `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT`, and `NDK_BUNDLE` to `GITHUB_ENV`;
4. write `ndk-path` to `GITHUB_OUTPUT`;
5. print `cmake --version` and `ninja --version`;
6. fail with a message explaining how to restore an explicit installation if the hosted image changes.

Replace `android-actions/setup-android` and `sdkmanager` in every native build workflow with this action. Do not retain `android-actions/setup-android` with an empty package list unless a workflow demonstrably requires a side effect not provided by the hosted image.

Validate locally with YAML inspection and on GitHub with at least one small Android build and one Skia Android build. The small build proves CMake wrappers work. Skia proves the compatibility shim in `skia/scripts/common.sh` works against the preinstalled NDK.

Acceptance requires all Android artifacts to be produced with the same NDK version recorded in their manifests, and repository search to return no normal build step that installs `ndk;28.2.13676358`.

## Milestone 2: Create minimal Docker build images

This milestone replaces the broad Bionic images for ordinary native libraries and introduces a Skia-specific Linux image. At its end, normal workflow runs will not install packages inside containers, and simple C libraries will not pull an SDL and desktop graphics toolchain.

First document the compatibility contract in `docker/README.md`. State the chosen base distribution or sysroot, compiler version, CMake version, Ninja version, supported target architecture, and the oldest Linux environment the resulting artifacts must support. Do not update glibc compatibility accidentally.

Create purpose-specific Dockerfiles, using repository naming conventions. A recommended layout is:

    docker/native-cmake-amd64/Dockerfile
    docker/native-cmake-arm64/Dockerfile
    docker/native-cmake-arm32v7/Dockerfile
    docker/skia-linux-amd64/Dockerfile

The native CMake images must omit SDL, audio, X11, Wayland, and graphics development packages. Include only tools actually used by the wrappers and package scripts. The Skia image must contain GN or a verified deterministic way to obtain it, Ninja, Python 3, ccache, rsync, and the graphics or cross-toolchain headers required by the existing Skia arguments. Do not perform `apt-get` during normal build jobs after this image is adopted.

Update `.github/workflows/docker-linux-images.yml` so each image is built for its intended native platform. Add BuildKit registry cache inputs and outputs when Docker Hub permissions allow it. Tag images with a new immutable version and publish image digests in the workflow summary. Keep the old `v1.0.7` images available during migration.

Add smoke scripts under `docker/tests/` or `.github/scripts/` that:

- compile and install zlib or qrcode in each native image;
- run Skia GN generation and a small representative target or full existing build in the Skia image;
- verify the expected target architecture with `file`, `readelf`, or the platform-equivalent tool;
- verify no dynamic library is accidentally packaged where a static library is expected.

Migrate one small workflow first. Compare cold image pull plus build time with the old image. Then migrate all non-Skia Linux jobs. Migrate Skia only after its image passes the existing artifact and manifest verification.

Acceptance requires all Linux artifacts to retain expected architecture and public layout, no native CMake image to contain the removed graphical package set, and no migrated workflow to install missing packages at runtime.

## Milestone 3: Remove metadata-only preparation jobs

This milestone removes runners that only read versions, calculate tags, or resolve a dependency release. At its end, builds begin immediately and metadata is calculated inside jobs that already need checkout.

For each `.github/workflows/release-*.yml`, move version and tag calculation from `prepare` into the final `release` job. The build does not need the future release tag. Keep `fetch-depth: 0` in the release checkout because tag calculation and creation need repository history and remote tags.

For reusable build workflows that currently have `prepare` only to read `deps.yml`, choose one of these deterministic paths and document the decision:

- pass the dependency release tag from the top-level orchestrator as a workflow input; or
- execute `.github/scripts/read-deps-release.sh` in each platform job after checkout.

Prefer the input when a batch workflow already resolved the complete compatible set. Prefer local reading for standalone push or pull-request builds. Do not create another runner to avoid a small repeated shell command.

Update release failure rollback so it still reverts any pin commit created before a failed tag or publication. Add a dry-run input to release workflows if one does not exist, allowing metadata and asset validation without publishing tags.

Acceptance requires every release workflow to retain successful tag and rollback behavior while having no standalone version-only runner. The workflow graph must show build jobs starting without waiting for metadata that they do not consume.

## Milestone 5: Establish shared platform build interfaces

This milestone creates common implementation units before adding batch workflows. At its end, existing standalone workflows and new orchestrators will invoke the same scripts or composite actions, avoiding two diverging build systems.

Create a stable platform build interface. It may be a set of composite actions under `.github/actions/build-native-library/` plus repository scripts, or scripts called directly by workflows. Composite actions cannot select `runs-on`; the caller still chooses the runner. The interface must accept at least:

- dependency name;
- source directory;
- build directory;
- install directory;
- target platform and architecture;
- CMake generator and platform arguments;
- dependency root paths such as zlib or libpng;
- package script path;
- artifact output pattern.

Prefer scripts for complex shell logic and composite actions for wiring environment, validation, and upload conventions. Keep platform-specific code visible rather than creating an unreadable universal shell expression.

Add a manifest file, for example `.github/native-build-targets.yml`, that records canonical target names, runner labels, Docker image references, platform names, architecture names, Android API level, and Apple generator arguments. All workflows must derive repeated constants from one maintained location where GitHub Actions expression limitations allow it; scripts may read the manifest when dynamic expressions are not possible.

Migrate zlib and qrcodegen as representative tests before migrating all libraries. Verify that package names and paths are byte-for-byte or structurally equivalent to the existing outputs, ignoring archive timestamps when necessary.

Acceptance requires existing standalone workflows to continue producing the same artifact names and contents while using the common implementation.

## Milestone 6: Add the graphics, compression, and image stack workflow

This milestone adds a platform-oriented batch workflow for zlib, zlib-ng, minizip, minizip-ng, libpng, libjpeg, libjpeg-turbo, and Skia. At its end, a maintainer can release any subset or the complete stack while preserving separate release identities.

Create `.github/workflows/release-graphics-stack.yml` with `workflow_dispatch` inputs selecting components and a `publish` boolean that defaults to false during initial validation. Use one job per target platform or architecture, not one full matrix per library.

Within each job, build selected libraries in dependency order:

    zlib, then minizip when selected;
    zlib-ng, then libpng and minizip-ng when selected;
    libjpeg and libjpeg-turbo;
    Skia last.

When Skia is selected, automatically ensure its currently enabled prebuilt dependencies are available. Do not silently enable jpeg support in Skia. The stack includes jpeg libraries for shared infrastructure and future dependency use, not to change current GN capabilities.

The Linux jobs must use the minimal images. Windows jobs must keep static MSVC runtime verification. Android must use the shared preinstalled NDK action. The Apple path must preserve all individual macOS, iOS, simulator, headers, and XCFramework assets. The WebAssembly job runs only when Skia is selected.

Each platform job uploads one artifact bundle per library or a carefully structured platform bundle that the publication job can split deterministically. Avoid artifact-name collisions. Store a machine-readable manifest containing dependency, version, platform, architecture, file name, checksum, and build configuration.

The publication job downloads all selected outputs, validates completeness against the manifest, calculates release tags, creates separate tags and GitHub Releases, and performs one final `deps.yml` update commit. Existing release workflows should become thin wrappers around the same workflow or remain documented fallbacks during migration. Do not delete them until at least one complete successful batch release and one standalone release have been observed.

Acceptance in dry-run mode requires all selected release directories to contain exactly the expected assets and notes without creating tags. Acceptance in publish mode requires distinct GitHub Releases for each selected library and one compatible bundle pin commit.

## Milestone 7: Add the small, rarely updated workflow and retain SQLite isolation

This milestone reduces overhead for qrcode, qrcodegen, axTLS, and mbedTLS while keeping SQLite independent. At its end, small libraries can share runners during a batch without losing independent artifacts or releases.

Create `.github/workflows/release-small-libraries.yml`. Use the same `publish` and component-selection conventions as the graphics stack. Build qrcode, qrcodegen, axTLS, and mbedTLS sequentially within each selected platform runner. Skip unsupported combinations such as qrcode Windows if the current workflow intentionally excludes them.

Add a Windows-only vcruntime lane to this orchestrator. First attempt to download all three redistributables in one Windows job and extract or install them without cross-architecture registry interference. If one-job packaging is unreliable, preserve a separate ARM64 or per-architecture path and record the evidence. Do not weaken verification merely to reduce runner count.

Do not place SQLite in this workflow. Refactor `.github/workflows/build-sqlite3.yml` and its release wrapper to use the shared Android, Docker, Apple, artifact, and publication primitives while retaining its own workflow graph and release schedule.

Acceptance requires a small-library dry run to produce separate assets for each selected component, vcruntime to retain three architecture-specific packages, and SQLite to run independently without depending on either group workflow.

## Milestone 8: Consolidate Apple build and packaging work

This milestone removes Apple artifact round trips when sequential work on one runner is faster and simpler. At its end, small libraries will compile macOS, iOS device, iOS Simulator, and XCFrameworks in one job, while Skia uses the consolidation that best preserves its parallel critical path.

For small libraries and SQLite, replace the three-entry Apple matrix plus `package-ios` job with one `macos-15` job. Build each target in a separate build directory, package the individual target tarballs, create the XCFramework directly from the local install trees, and upload all outputs at the end.

For the graphics stack, measure two designs:

- one Apple job that builds macOS, iOS device, iOS simulator, and packaging;
- macOS in parallel with one combined iOS device, simulator, and packaging job.

Use the second design if Skia macOS compilation meaningfully extends the critical path when serialized. In either design, the iOS package job must not download artifacts produced earlier in the same logical lane and must not refetch Skia only to stage headers.

Preserve `macos-15`, Apple Silicon architecture, deployment targets, code-signing-disabled settings, individual archives, and XCFramework names.

Acceptance requires every existing Apple artifact to be present, successful `xcodebuild -create-xcframework`, and measured improvement or runner reduction documented for the selected design.

## Milestone 9: Optimize Skia source preparation, tools, caches, and diagnostics

This milestone removes repeated non-compilation work from Skia. At its end, source content is prepared once per manifest, supported hosts reuse it, cache invalidation reflects source changes, and successful builds emit only useful diagnostics.

Refactor `.github/workflows/build-skia.yml` and `skia/scripts/fetch-source.sh` so the prepared source archive has an explicit format version and deterministic content. The cache key must depend on `skia/manifest.json`, source-fetching scripts, and the archive format version, not on unrelated workflow text.

Attempt to restore the same source archive on Windows and macOS. Validate path lengths, executable bits, symlinks, and line endings. If one cross-OS archive cannot preserve required metadata, create platform-family archives from the same pinned source manifest rather than reverting to a full sync per architecture.

Move Linux build tools into the Skia Docker image. On Windows and Apple, check for Ninja and ccache before installing them. Avoid unconditional `choco install` and `brew install`. Pin any installation that remains.

Add `SKIA_DIAGNOSTICS_MODE` with accepted values `none`, `summary`, and `full`. Default normal successful builds to `summary`. Generate or upload `full` diagnostics only on failure or explicit dispatch. Keep the build configuration manifest and concise Ninja summary in normal artifacts.

Set explicit ccache limits per target and print statistics before and after build. Include cache hit rate and cache size in the metrics summary. Do not use broad restore keys that allow incompatible compiler or toolchain caches to be restored without validation.

Acceptance requires Windows and Apple to avoid repeated full source synchronization when their archive restore succeeds, unrelated YAML edits not to invalidate the source archive key, successful jobs not to upload full dependency graphs, and all Skia artifact verifications to pass.

## Milestone 10: Attempt the Skia ARMv7 cross-build last

This is the final engineering milestone because a prior attempt did not succeed. It is an evidence-producing experiment with a safe fallback, not permission to remove QEMU after a compile-only result.

Create or correct a dedicated script such as `skia/scripts/build-linux-armv7-cross.sh`. Do not overload the existing working script until the experiment passes. Run it on the amd64 Skia image with a pinned ARMv7 hard-float toolchain and a complete compatible sysroot. Ensure GN uses the intended compiler, linker, archiver, target triple, float ABI, NEON policy, and dependency paths.

Produce both the existing QEMU artifact and the experimental cross-built artifact from the same source commit and dependency releases. Compare:

- archive member names;
- target architecture and ABI attributes;
- undefined symbols;
- public symbol set, allowing documented toolchain-specific differences;
- GN build manifests;
- ability to link a minimal TotalCross-compatible fixture against the library and its prebuilt zlib/libpng dependencies;
- runtime smoke behavior on real ARMv7 hardware or the existing emulated environment when available.

Record every failed command and concise diagnostic in `Surprises & Discoveries`. Promote the cross-build only if it passes the fixture and runtime or equivalent validation accepted by the maintainer. Otherwise, retain the QEMU job, remove or clearly label experimental workflow paths, and document what blocked promotion.

The plan can complete with QEMU retained, provided the experiment was performed safely and the negative result is documented. The higher-priority optimizations must not be rolled back because this experiment fails.

## Plan of Work

Implement the milestones in their document order: Milestone 4 is intentionally first, followed by Milestones 1 through 10. Make each milestone a logical commit or small series of commits. Do not start the grouped release workflows until the shared Android and Docker foundations are working. Do not remove standalone workflows before the grouped replacements have completed both dry-run and published validation.

Begin every milestone by updating `Progress` with the exact timestamp and intended stopping point. After implementation, add measured evidence to `Surprises & Discoveries` or `Outcomes & Retrospective`, record design changes in `Decision Log`, and commit the living plan together with the code it describes.

Use additive migration. New actions, images, scripts, routers, and batch workflows should coexist with current paths until validated. Retire duplication only after the replacement proves the same artifact set and release behavior.

## Concrete Steps

Work from the repository root unless a step says otherwise.

Inspect the initial state:

    git status --short
    find .github/workflows -maxdepth 1 -type f -name '*.yml' -print | sort
    find .github/actions -maxdepth 3 -type f -print | sort
    find docker -maxdepth 2 -type f -print | sort
    git grep -n 'sdkmanager.*ndk;28.2.13676358' -- .github
    git grep -n 'runs-on:' -- .github/workflows
    git grep -n 'deps.yml' -- .github/workflows

Capture baseline runs using the commands in `Baseline and Measurement Model`. Store large raw logs outside Git. Commit only compact JSON, Markdown summaries, or test fixtures approved for the repository.

After each workflow edit, validate YAML and GitHub Actions semantics. Prefer an existing repository command. If none exists and `actionlint` is installed:

    actionlint

Otherwise use a pinned temporary invocation and do not commit the downloaded binary:

    go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7

Validate shell scripts:

    find .github/scripts skia/scripts docker -type f -name '*.sh' -print0 | xargs -0 shellcheck

If the repository does not currently require shellcheck-clean legacy scripts, run it only on changed scripts and record existing unrelated warnings separately.

Validate Python scripts:

    python3 -m compileall .github/scripts
    python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'

Build Docker images locally for the host platform:

    docker buildx build --load -f docker/native-cmake-amd64/Dockerfile -t totalcross/native-cmake-amd64:test .
    docker buildx build --load -f docker/skia-linux-amd64/Dockerfile -t totalcross/skia-linux-amd64:test .

Run image smoke tests using the exact scripts added by Milestone 2. Record image IDs and compressed registry sizes from the publish workflow rather than relying only on local `docker images` size.

Use dry-run dispatches before publishing:

    gh workflow run release-graphics-stack.yml -f publish=false -f components=all
    gh workflow run release-small-libraries.yml -f publish=false -f components=all

The exact input syntax may differ if component booleans are used. Update these commands in the living plan to match the implemented interface.

After dispatch, record the run ID and metrics:

    gh run list --workflow release-graphics-stack.yml --limit 5
    python3 .github/scripts/collect-workflow-metrics.py --repo TotalCross/totalcross-depot-tools --run-id "$RUN_ID" --output "artifacts/ci-performance/final/${RUN_ID}.json"

Before the first real grouped publication, select versions that can safely produce new revision tags. Verify the dry-run manifest, then run with `publish=true`. Confirm each GitHub Release separately and confirm `deps.yml` changed once.

For artifact comparison, extract old and new archives into separate temporary directories and compare sorted file lists, headers, architecture, and checksums of normalized contents. Do not require byte-identical gzip or zip archives when timestamps differ; compare extracted payloads and metadata that affect consumers.

## Validation and Acceptance

The implementation is accepted only when all applicable criteria below are demonstrated with repository paths and workflow-run evidence.

Android acceptance:

- no normal build workflow reinstalls NDK `28.2.13676358`;
- every Android job verifies the preinstalled path and records the expected version;
- representative small-library and Skia Android artifacts build successfully.

Docker acceptance:

- native CMake images exclude SDL, audio, X11, Wayland, and desktop graphics development packages;
- the Skia image contains all tools required by its Linux builds without runtime package installation;
- every migrated Linux target produces the expected architecture and static artifact;
- Linux compatibility policy is documented and validated with the repository's supported baseline.

Workflow-graph acceptance:

- metadata-only `prepare` jobs are removed;
- a semantic mbedTLS-only pin change does not run graphics consumers;
- zlib-ng and libpng pin changes select the documented consumer set;
- a grouped release starts no more than one job per selected platform/architecture lane, plus necessary packaging and publication jobs;
- separate library tags and GitHub Releases remain intact.

Apple acceptance:

- all current macOS, iOS, simulator, header, and XCFramework assets remain available;
- small libraries no longer upload and redownload iOS artifacts solely for XCFramework creation;
- Skia packaging does not refetch the complete source tree only for headers.

Skia acceptance:

- source cache keys change when pinned source content changes and remain stable for unrelated workflow edits;
- normal successful builds upload summary diagnostics, not full diagnostics;
- ccache statistics are visible and bounded;
- all existing manifest assertions and static runtime checks pass.

SQLite acceptance:

- SQLite remains independently dispatchable and publishable;
- it uses common optimized primitives without depending on either grouped release workflow;
- its artifact layout and platform coverage remain unchanged.

ARMv7 acceptance:

- the existing QEMU path remains available until the cross-build passes link and runtime-equivalent validation;
- if promoted, the cross-built artifact passes architecture, ABI, symbols, fixture link, and runtime smoke checks;
- if not promoted, the negative result and exact blocker are recorded, and all other milestones remain complete.

Performance acceptance:

- baseline and final measurements use comparable cache conditions;
- the final report lists runner count, total run time, summed job execution time, setup time, and artifact sizes for representative workflows;
- any regression in the critical path is explained and approved rather than hidden by aggregate runner savings.

The plan is not complete until final validation evidence is reconciled into `Outcomes & Retrospective` and the `Editorial Report`.

## Idempotence and Recovery

The Android setup action is read-only except for environment exports and can be rerun safely. Docker builds must use versioned tags so a failed publication does not overwrite the currently consumed tag. Keep old image references in workflows or a migration branch until smoke validation succeeds.

The dependency diff router must be deterministic and safe to rerun. It must not mutate `deps.yml`. Batch publication must detect existing tags and releases so a retry after partial publication does not create duplicates. Do not delete published releases automatically during rollback. Revert only the bundle pin commit when that commit exists and publication has not reached a consistent state.

Maintain existing workflows during migration. If a grouped workflow fails, dispatch the existing individual release workflow. Remove or deprecate the fallback only after evidence from successful grouped and standalone runs.

Apple consolidation can be reverted by restoring the previous matrix and package job because artifact formats remain unchanged. Skia diagnostic mode changes must not delete diagnostics on failure; `full` mode remains available.

The ARMv7 experiment must use separate build directories, artifact names, and optionally a separate workflow input. A failure must leave the QEMU artifact untouched. Clean experimental outputs before retrying to avoid linking stale objects.

## Artifacts and Notes

Maintain compact evidence in a structure similar to:

    artifacts/ci-performance/
      baseline/
        <run-id>.json
      final/
        <run-id>.json
      comparison.md
      docker-images.json
      artifact-comparison.md
      armv7-experiment.md

If the repository does not want generated evidence committed, place the files in workflow artifacts and commit only a short index containing run URLs, IDs, commands, and conclusions. Update this section to reflect the chosen policy.

Every workflow should write a concise `GITHUB_STEP_SUMMARY` containing selected components, dependency releases, runner/toolchain versions, cache status, produced artifacts, and publication mode.

Keep sample output excerpts short. A useful metrics excerpt is:

    workflow: Release graphics stack
    cache_condition: warm
    runner_jobs: 12
    elapsed_seconds: <observed>
    summed_job_seconds: <observed>
    artifacts: <observed count>

Do not fill placeholders with estimates.

## Interfaces and Dependencies

The Android setup composite action must expose a stable interface equivalent to:

    inputs:
      ndk-version:
        required: false
        default: 28.2.13676358
    outputs:
      ndk-path:
        value: ${{ steps.resolve.outputs.ndk-path }}

The dependency diff script must support a command equivalent to:

    python3 .github/scripts/diff-dependency-pins.py \
      --before deps-before.yml \
      --after deps.yml \
      --format github-output

It must emit changed dependency names and consumer booleans without relying on line-oriented text comparison.

The grouped release workflows must expose explicit component selection and publication mode. Prefer either a comma-separated validated component input or individual booleans. The workflow must reject unknown component names before allocating build matrices.

The graphics stack component set is fixed initially to:

    zlib
    zlib-ng
    minizip
    minizip-ng
    libpng
    libjpeg
    libjpeg-turbo
    skia

The small-library component set is fixed initially to:

    qrcode
    qrcodegen
    axtls
    mbedtls
    vcruntime

`sqlite3` is not a valid component of either group.

The publication implementation must preserve the existing release-tag policy in `.github/scripts/next-release-tag.sh`, existing bundle pin semantics, failure rollback behavior, release titles and notes, and component-specific asset completeness checks.

Docker images must be versioned and pinned. Do not use `latest` in production workflows. Record the image digest in workflow summaries and update the digest intentionally when rebuilding an image.

No new external service is required. Continue using GitHub Actions, GitHub Releases, Docker Hub, the GitHub CLI in publication jobs, CMake, Ninja, platform toolchains, and the repository's existing scripts.

## Revision Note

Created on 2026-07-17 from the workflow performance analysis. This revision moves Milestone 4 (precise dependency routing and atomic batch pin updates) to the first implementation position at the user's request, keeps minimal Docker images as the next infrastructure priority, places the Skia ARMv7 cross-build experiment last because a previous attempt failed, includes libjpeg and libjpeg-turbo in the Skia-oriented stack, combines QR and crypto libraries as small and rarely updated, keeps SQLite isolated, and explicitly defers larger runners and library feature-reduction compilation changes to separate future plans.
