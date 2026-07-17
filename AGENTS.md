# Repository Guidelines

## Purpose

This repository owns the native dependency toolchain consumed by TotalCross.
Each dependency should be self-contained: source fetching, build files,
packaging scripts, CMake find/auto-fetch modules, manifests, and documentation
live under that dependency directory.

The root `deps.yml` is only the compatible bundle index. Keep dependency
versions, release tags, and paths aligned with the dependency manifests.

Builds that consume another dependency from this repository must use that
dependency's `release` pin in `deps.yml` by default. Do not resolve the latest
GitHub release or read a separate dependency manifest as an alternative source
of truth. Use `.github/scripts/read-deps-release.sh` for shell and workflow
resolution; explicit workflow inputs may override it only for a deliberate
release handoff.

## Layout

- `deps.yml`: bundle index for compatible dependency releases.
- `<dep>/manifest.yml`: source version, build flags, release tag, and archive
  names.
- `<dep>/fetch.sh`: downloads published release artifacts into the local cache.
- `<dep>/CMakeLists.txt`: builds the dependency in isolation.
- `<dep>/cmake/AutoFetch*.cmake`: fetches missing prebuilts for consumers.
- `<dep>/cmake/Find*.cmake`: resolves only this repository's prebuilts.
- `<dep>/scripts/package-artifact.sh`: creates release archives.
- `skia/scripts`: Skia-specific GN/Ninja source build scripts.
- `docker`: shared images used by workflows.
- `.github/workflows`: build and release automation.

Do not add per-dependency `docker` directories. Builds should use the shared
images from the root `docker` setup and the published `totalcross/*` images.

## Dependency Conventions

- Install fetched prebuilts in platform-specific directories:
  `local/<platform>/<arch>`.
- Archive contents should also be platform-specific:
  `<dep>/<platform>/<arch>/{include,lib,manifest.txt}`.
- `Find*.cmake` modules must not silently fall back to system libraries.
  Prefer repository-local paths and use `NO_DEFAULT_PATH` /
  `NO_CMAKE_FIND_ROOT_PATH` when appropriate.
- `AutoFetch*.cmake` should derive paths from `CMAKE_CURRENT_LIST_FILE`, not
  from the caller's `CMAKE_CURRENT_LIST_DIR`.
- Auto-fetch should check whether this repository already exists locally before
  trying to clone or update it. When it exists, skip repository fetching and
  fetch only the required library artifacts.
- Keep artifact names consistent across `manifest.yml`, `fetch.sh`,
  packaging scripts, and release workflows.

## Android

Only generate or consume Android ABIs that have published artifacts. At the
moment the TotalCross Android consumer is expected to use `arm64-v8a` unless a
change explicitly adds more release assets and updates the consumer filters.

Do not make local Android builds request `armeabi-v7a` unless the corresponding
SQLite3, mbedTLS, and Skia artifacts exist in the target releases.

## iOS packaging runners

Every `package-ios` job in a build workflow must run on `macos-15`. GitHub maps
that hosted-runner label to Apple Silicon (`arm64`); do not replace it with
`macos-15-intel`. The packaging jobs only combine already-built iOS artifacts
into XCFrameworks, so keeping them on the standard ARM64 macOS pool avoids
unnecessary waits for Intel macOS capacity.

## Windows static runtime

- Every Windows static library must use the static MSVC runtime (`/MT`).
- CMake wrappers must include `cmake/TotalCrossWindowsStaticRuntime.cmake`
  before `project()`; nested CMake builds must also receive
  `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` explicitly.
- Non-CMake builds must set the equivalent compiler option explicitly.
- Every Windows build must run `.github/scripts/verify-windows-static-runtime.ps1`
  against its final artifact before upload, for x86, x64, and ARM64.
- `vcruntime` is excluded: it packages prebuilt DLLs rather than static libraries.

## Skia Notes

Skia is different from the CMake-built dependencies:

- Release assets are described by `skia/artifacts.json`.
- Source/build pins are described by `skia/manifest.json`.
- `skia/fetch.sh` should perform the artifact fetch directly.
- Do not reintroduce a separate `scripts/fetch-skia.sh` wrapper.
- References should point to `TotalCross/totalcross-depot-tools`, not the old
  `TotalCross/totalcross-skia-build` repository.
- GN/Ninja builds must run Ninja through the repository log wrapper instead of
  invoking `ninja` directly. Preserve complete raw logs and structured
  summaries as CI artifacts, keep console output compact, and publish full
  diagnostics as a separate release archive when release assets are produced.

## Workflows

- Reusable build workflows should contain the build matrix and artifact upload
  steps.
- Release workflows should call the reusable build workflows instead of
  duplicating build commands.
- Keep Docker image tags current and consistent across workflows.
- Release assets should be generated from `dist` or dependency build output
  exactly as declared by the manifest.

## Scripts

- Every script in the repository must have the executable permission bit set.
- New scripts must be created with executable permissions and must retain `+x`
  when committed.

## Validation

Before handing off dependency changes, run the checks that fit the scope:

```bash
bash -n sqlite3/fetch.sh mbedtls/fetch.sh skia/fetch.sh
ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "ok"' deps.yml */manifest.yml
git diff --check
```

For CMake module changes, configure a tiny consumer or the TotalCrossVM build
that includes the changed modules. Verify it resolves dependencies from
`local/<platform>/<arch>` and does not pick up Homebrew, system, or SDK copies.

## Git Hygiene

- Keep changes scoped to the dependency or workflow being modified.
- Do not commit generated build directories.
- Treat `dist` assets intentionally: include them only when the task is to
  publish or prepare release assets.
- Commits must follow Conventional Commits, be logical and atomic, and include
  a descriptive body explaining the change, especially its purpose or
  motivation. The automated commit-message validation checks the Conventional
  Commits header; a body is recommended but is not required for validation.
- When asked for a commit message, write it in English. Use an imperative,
  concise subject line without a trailing period, then a body explaining the
  cause, the fix, and compatibility or workflow impact when relevant. Mention
  concrete error messages or platform details when they motivated the change.
- Never revert unrelated local changes. This repository is often edited in
  parallel with the TotalCross consumer repository.
