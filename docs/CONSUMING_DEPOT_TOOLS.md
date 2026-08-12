<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Consuming TotalCross depot-tools artifacts

## Recommended model

A consumer should pin a repository tag or immutable ref, fetch the repository
into its dependency area, and use the CMake modules shipped with each library to
download and resolve native artifacts.

The recommended consumer layout is:

    <project>/
      CMakeLists.txt
      deps/
        fetch-depot-tools.sh
        totalcross-depot-tools.ref
        totalcross-depot-tools/        # generated checkout/cache

Commit the fetch script and ref file. Do not commit the generated checkout or its
`local` artifact caches unless the consumer has an explicit vendoring policy.

## Pin file

`deps/totalcross-depot-tools.ref` contains one non-empty, non-comment line:

    <repository tag or immutable ref>

Use a tag validated for the dependency set required by the project. Do not use
`main` for reproducible normal builds.

An environment override such as `TOTALCROSS_DEPOT_TOOLS_REF` may take precedence
for testing a pending release, but CI and ordinary developer builds should use
the committed pin.

## Bootstrap script behavior

`deps/fetch-depot-tools.sh` should:

1. resolve its own directory;
2. read `totalcross-depot-tools.ref` unless an environment ref override is set;
3. clone `https://github.com/TotalCross/totalcross-depot-tools.git` when the
   checkout is absent;
4. restore Git metadata when a source package contains the checkout without
   `.git`;
5. verify the checkout's origin before changing it;
6. fetch tags;
7. check out the configured ref in detached mode;
8. print only the resolved checkout path.

Useful environment overrides are:

    TOTALCROSS_DEPOT_TOOLS_DIR
    TOTALCROSS_DEPOT_TOOLS_REPO
    TOTALCROSS_DEPOT_TOOLS_REF

Do not print access tokens or authenticated repository URLs.

## CMake bootstrap

A consumer may ensure the checkout exists during configure:

    set(PROJECT_DEPOT_TOOLS_DIR
        "${CMAKE_SOURCE_DIR}/deps/totalcross-depot-tools"
        CACHE PATH "totalcross-depot-tools checkout")

    if(NOT EXISTS "${PROJECT_DEPOT_TOOLS_DIR}/deps.yml")
      find_program(PROJECT_BASH_EXECUTABLE bash REQUIRED)
      execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env
          "TOTALCROSS_DEPOT_TOOLS_DIR=${PROJECT_DEPOT_TOOLS_DIR}"
          "${PROJECT_BASH_EXECUTABLE}"
          "${CMAKE_SOURCE_DIR}/deps/fetch-depot-tools.sh"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        RESULT_VARIABLE PROJECT_DEPOT_TOOLS_FETCH_RESULT
        OUTPUT_VARIABLE PROJECT_DEPOT_TOOLS_FETCH_STDOUT
        ERROR_VARIABLE PROJECT_DEPOT_TOOLS_FETCH_STDERR
      )
      if(NOT PROJECT_DEPOT_TOOLS_FETCH_RESULT EQUAL 0)
        message(FATAL_ERROR
          "Failed to fetch totalcross-depot-tools.\n"
          "${PROJECT_DEPOT_TOOLS_FETCH_STDERR}")
      endif()
    endif()

Keep console output concise. Do not echo the complete checkout log on success.

## Add one dependency to CMake

Do not guess module, function, variable, package, or imported-target names. Inspect
these files from the pinned checkout:

    <dependency>/README.md
    <dependency>/cmake/AutoFetch*.cmake
    <dependency>/cmake/Find*.cmake

A typical integration is:

    list(PREPEND CMAKE_MODULE_PATH
      "${PROJECT_DEPOT_TOOLS_DIR}/<dependency>/cmake")

    include("${PROJECT_DEPOT_TOOLS_DIR}/<dependency>/cmake/AutoFetch<Package>.cmake")
    <auto-fetch-function>()
    find_package(<Package> REQUIRED)

    target_link_libraries(my_target PRIVATE <Package>::<ImportedTarget>)

Some modules define an auto-fetch option. Preserve the module's documented
interface rather than creating a consumer-specific fork.

## Example: zlib

The pinned repository's zlib module can be integrated in this pattern:

    list(PREPEND CMAKE_MODULE_PATH
      "${PROJECT_DEPOT_TOOLS_DIR}/zlib/cmake")

    include("${PROJECT_DEPOT_TOOLS_DIR}/zlib/cmake/AutoFetchZlib.cmake")
    tcvm_auto_fetch_zlib()
    find_package(ZLIB REQUIRED)

    target_link_libraries(my_target PRIVATE ZLIB::ZLIB)

Confirm the actual imported target from the pinned `FindZlib.cmake`; do not rely
on this example after intentionally changing the module contract.

## Example: Skia

Skia prebuilts carry a machine link contract beside each static archive. Use
the imported target as the complete interface:

    list(PREPEND CMAKE_MODULE_PATH
      "${PROJECT_DEPOT_TOOLS_DIR}/skia/cmake")

    include("${PROJECT_DEPOT_TOOLS_DIR}/skia/cmake/AutoFetchSkia.cmake")
    tcvm_auto_fetch_skia()
    find_package(Skia REQUIRED)

    target_link_libraries(my_target PRIVATE Skia::Skia)

Do not add Metal, OpenGL, Vulkan, PNG, zlib, or platform libraries based only
on the consumer host. `FindSkia.cmake` validates the selected archive's
`SkiaBuildConfig.cmake` and derives those requirements from the backends and
dependency choices recorded for that artifact. A strict repository-managed
package with missing, mismatched, or unsupported metadata fails during
configuration rather than exposing a partially described imported target.

The machine contract covers compile definitions, public include directories,
and link dependencies separately. For a Vulkan-enabled repository artifact,
`Skia::Skia` exports `SK_VULKAN` and the development bundle's
`include/third_party/vulkan` directory so Skia public headers compile without an
external Vulkan SDK. The bundled header check is deterministic and fails during
configuration when the managed package is incomplete. It does not add a Vulkan
loader library or provide an application-level Vulkan runtime; applications
that directly load Vulkan remain responsible for that separate integration.

## Platform and architecture selection

Auto-fetch modules derive the artifact platform and architecture from CMake:

- Android from `ANDROID_ABI`;
- iOS device or simulator from `CMAKE_SYSTEM_NAME` and `CMAKE_OSX_SYSROOT`;
- Windows from the selected Visual Studio platform;
- macOS from `CMAKE_OSX_ARCHITECTURES` or the system processor;
- Linux from `CMAKE_SYSTEM_PROCESSOR`.

The project must configure only targets for which the pinned dependency release
contains an artifact. A missing asset should fail clearly rather than silently
falling back to a system library.

## Release-pin resolution

The repository's `deps.yml` is the compatible bundle index. Auto-fetch modules
normally use the release recorded there.

Per-library environment or CMake variables may override a release tag for a
controlled handoff. Examples use a library-specific prefix such as:

    ZLIB_RELEASE_TAG
    LIBPNG_RELEASE_TAG
    MBEDTLS_RELEASE_TAG

Treat these as temporary overrides. Update the repository pin when adopting a
new compatible depot-tools revision.

## Private or alternate releases

Some fetch scripts allow a repository and token-environment override. Store the
token in the named environment variable and pass only the variable name to CMake
or fetch scripts. Never print the token value.

A consumer must preserve the same archive layout and package interface when using
an alternate release repository.

## Updating the depot-tools pin

1. Select a validated tag or immutable ref.
2. Update `deps/totalcross-depot-tools.ref`.
3. Remove no source files and do not delete unrelated caches.
4. Run the bootstrap script so the checkout moves to the new ref.
5. Configure the smallest affected CMake target.
6. Confirm auto-fetch downloads only missing artifacts.
7. Confirm `find_package` resolves paths under the depot-tools checkout.
8. Build and link one affected consumer target.
9. Run the directly affected platform build or package gate.
10. Commit the pin and consumer changes together with a descriptive body.

## Adopting depot-tools with Codex

Install or copy the `adopt-totalcross-depot-tools` skill into the consumer
repository's `.agents/skills` directory. Invoke it with the desired library and
pin, for example:

    Use $adopt-totalcross-depot-tools to add zlib-ng from tag <tag> to this CMake project.

The skill first checks for an existing checkout/bootstrap pattern. It preserves
an existing compatible implementation, creates missing files only when needed,
and reads the pinned library modules before editing the consumer build.

## Validation

For a focused adoption, verify:

    bash -n deps/fetch-depot-tools.sh
    bash deps/fetch-depot-tools.sh
    cmake -S . -B build/depot-tools-consumer -G Ninja
    cmake --build build/depot-tools-consumer

Then inspect the concise CMake result or cache to confirm that include and library
paths come from:

    deps/totalcross-depot-tools/<dependency>/local/<platform>/<arch>

Do not claim the integration is complete when CMake selected a system, SDK,
Homebrew, vcpkg, Conan, or other package-manager copy.

## TotalCross reference implementation

The principal consumer is `TotalCross/totalcross`:

- `TotalCrossVM/deps/fetch-depot-tools.sh` implements the clone/ref bootstrap;
- `TotalCrossVM/deps/totalcross-depot-tools.ref` pins the checkout;
- `TotalCrossVM/CMakeLists.txt` fetches the checkout when absent, adds library
  module paths, invokes auto-fetch functions, and links imported targets.

Use that implementation as a behavioral reference, not as text to copy blindly.
A new consumer must preserve its own license headers, directory conventions,
target names, and platform requirements.
