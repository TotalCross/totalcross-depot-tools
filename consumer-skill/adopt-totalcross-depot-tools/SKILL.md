---
name: adopt-totalcross-depot-tools
description: Integrate a published totalcross-depot-tools native library into another CMake repository by preserving or creating a pinned checkout bootstrap, reading the pinned library modules, fetching its artifacts, and linking its imported CMake target without system-library fallback.
---

# Adopt a depot-tools dependency in a consumer

Use this skill in the consumer repository, not while implementing the library itself in `totalcross-depot-tools`.

Required inputs are the desired dependency name and a repository tag or immutable ref. Do not select `main` for a reproducible integration. Ask for the pin only when it is not provided and cannot be derived from an existing compatible consumer policy.

## Inspect the existing consumer pattern

Search narrowly for:

    rg -n "totalcross-depot-tools|fetch-depot-tools|DEPOT_TOOLS" .
    rg --files | rg 'fetch-depot-tools\.sh|totalcross-depot-tools\.ref|CMakeLists\.txt$'

Determine whether the project already has:

- a depot-tools checkout or submodule;
- a fetch script;
- a committed ref file;
- an environment override policy;
- CMake module-path or direct auto-fetch includes;
- a generated dependency directory that must not be committed.

Preserve a compatible existing implementation. Do not create a second checkout or competing pin mechanism.

## Create the pinned bootstrap when absent

Use a project-appropriate dependency directory, normally:

    deps/fetch-depot-tools.sh
    deps/totalcross-depot-tools.ref
    deps/totalcross-depot-tools/

The ref file contains the requested tag or immutable ref.

The fetch script must clone when absent, restore Git metadata when a source archive contains the directory without `.git`, verify the origin, fetch tags, and check out the pin. Support environment overrides for checkout path, repository URL, and ref. Preserve the consumer repository's license header; do not copy TotalCross's LGPL header into an unrelated project.

Use `references/totalcross-example.md` for behavior, not blind text copying.

## Read the pinned library interface

Fetch or inspect the pinned checkout, then read only:

    <dependency>/README.md
    <dependency>/cmake/AutoFetch*.cmake
    <dependency>/cmake/Find*.cmake
    deps.yml

Extract the exact:

- auto-fetch module name;
- auto-fetch function or option;
- `find_package` name;
- imported target;
- release override variables;
- supported platform and architecture artifacts.

Do not guess these names from the dependency directory.

## Update the CMake build

1. Ensure the checkout exists before including its modules. Prefer configure-time bootstrap only when that matches the project's existing policy.
2. Add the dependency's CMake directory to `CMAKE_MODULE_PATH` or include its auto-fetch module directly.
3. Invoke the documented auto-fetch function or enable its option.
4. Call `find_package(... REQUIRED)`.
5. Link the documented imported target to the correct consumer target.
6. Preserve existing feature flags and platform conditions.
7. Do not add raw include/library paths when an imported target is available.
8. Do not silently fall back to a system, SDK, Homebrew, vcpkg, Conan, or other package-manager copy.

## Validate

Run:

    bash -n <fetch script>
    bash <fetch script>
    cmake -S <source> -B <focused build dir> <existing generator/options>
    cmake --build <focused build dir> --target <small affected target>

Confirm that resolved includes and libraries are under:

    <checkout>/<dependency>/local/<platform>/<arch>

Run the directly affected platform/package validation only when needed. Save full build output to a log and report a concise result.

## Commit guidance

When the user requests a commit, keep the checkout pin, fetch bootstrap, CMake integration, and focused documentation in one logical adoption commit unless the repository's own `AGENTS.md` requires a different boundary. Explain the selected depot-tools pin and imported target in the commit body.
