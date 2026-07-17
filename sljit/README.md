# SLJIT static libraries

This directory packages [SLJIT](https://github.com/zherczeg/sljit) snapshot
`3907e69005ba6e30b225000f24aaef3632f88347` as reproducible static libraries.
The source archive is pinned by SHA-256 in `manifest.yml`. SLJIT is redistributed
under its upstream Simplified BSD license, copied into every artifact at
`share/licenses/sljit/LICENSE`.

The `20260717` distribution contains these packages:

- Linux: `x86_64`, `armv7l`, and `aarch64`
- Windows: `x86`, `x64`, and `arm64`
- Android: `arm64-v8a`
- macOS: `arm64`

iOS is intentionally unsupported. Building the sources there does not establish
that ordinary iOS applications can execute generated code.

Each archive expands to `sljit/<platform>/<arch>/` and contains the four public
headers, `lib/libsljit.a` (or `lib/sljit.lib` on Windows), the upstream license,
and `manifest.txt` provenance. Release builds define
`SLJIT_WX_EXECUTABLE_ALLOCATOR=1`, so code pages are writable or executable at
different times; they also enable argument checks and retain multithreaded
support. Windows libraries and smoke executables use the static MSVC runtime
(`/MT`).

Android uses NDK `28.2.13676358` (r28c), `arm64-v8a`, API 23, the non-legacy
CMake toolchain, and flexible page-size support. Cross-compilation proves the
archive can be linked for that API; it does not claim that Android runtime policy
permits JIT execution on a particular device.

## Local build

```bash
cmake -S sljit -B sljit/build/linux-x86_64 \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -G Ninja
cmake --build sljit/build/linux-x86_64
ctest --test-dir sljit/build/linux-x86_64 --output-on-failure
cmake --install sljit/build/linux-x86_64 \
  --prefix sljit/build/linux-x86_64/install
bash sljit/scripts/package-artifact.sh sljit/build/linux-x86_64 \
  sljit/build/linux-x86_64/install linux/x86_64
```

For offline builds, set `SLJIT_SOURCE_ARCHIVE` to the verified codeload archive,
or set `SLJIT_SOURCE_DIR` to an unpacked source directory containing
`sljit_src/sljitLir.c` and `LICENSE`.

## Fetch and CMake consumption

Fetch uses `SLJIT_GITHUB_TOKEN`, falling back to `GITHUB_TOKEN`; neither value
is printed. The release tag, source repository, token environment variable, and
destination can be overridden deliberately.

```bash
bash sljit/fetch.sh --platform linux --arch x86_64
```

```cmake
list(APPEND CMAKE_MODULE_PATH "<depot-tools>/sljit/cmake")
include(AutoFetchSLJIT)
tcvm_auto_fetch_sljit()
find_package(SLJIT REQUIRED)
target_link_libraries(your-target PRIVATE SLJIT::SLJIT)
```

`FindSLJIT.cmake` searches only `sljit/local/<platform>/<arch>` and never falls
back to a system, SDK, Homebrew, or package-manager installation.
