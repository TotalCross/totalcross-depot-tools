<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Skia prebuilt link contract history

## Milestone 1: actual dependency matrix

The r7 release diagnostics, archives, and pinned Skia source graph established
the mapping summarized in the evidence JSONL. The notable diagnostic defect is
that the existing `gn args` and `gn desc` collection ran outside the Skia source
root, so those text files contain an error rather than graph output. The
generated `args.gn`, `build.ninja`, compile commands, pinned `BUILD.gn`, and
archive symbols still provided independent evidence.

The macOS ARM64 release archive hash is recorded in evidence. A consumer that
references `GrDirectContext::MakeMetal` fails to link without the Metal-side
frameworks and reports unresolved `MTL*` Objective-C classes. This proves the
original regression at the package boundary.

Vulkan does not add a loader library in the pinned `Skia` target: callers supply
Vulkan entry points through the backend context and VMA is compiled into the
archive. Likewise, the enabled Linux `skia_use_opencl` setting does not add an
OpenCL source or dependency to the `Skia` library; it only gates a separate
development tool in the pinned source graph. WebGL is handled by Emscripten.

Linux official builds expose pre-existing system Freetype and Fontconfig
requirements. They are not new package-manager dependencies introduced by this
plan and no installer behavior will be added.

## Milestone 4: metadata-driven imported target

Commit `1083f82` added a pure logical classifier and a platform resolver,
validated v1 identity and archive SHA before target creation, and kept current
r7 plus explicit external libraries on a clearly warned legacy path. Strict
managed packages require their sidecar, and auto-fetch treats a missing strict
sidecar as a missing artifact.

The fixed macOS ARM64 proof used the exact r7 archive and a sidecar generated
from the corrected 144-line effective GN listing. The consumer references
`GrDirectContext::MakeMetal` and links only `Skia::Skia`. CMake propagated the
repository PNG/zlib archives, ApplicationServices, AppKit, OpenGL, Metal, and
Foundation frameworks, plus the GL, Metal, and Vulkan compile definitions; the
link produced an ARM64 Mach-O executable.

The effective-argument checkpoint exposed a GN scope nuance: nested dependency
arguments are absent when their target is inactive. Metadata generation now
classifies inactive nested choices as off, fails when an active choice is
missing, and records repository zlib/libpng selection from the validated shared
prebuilt configuration applied to the build.

## Milestone 5: operation family and downstream consumer

The first fresh macOS build exposed that `SKIA_DEP_USE_ZLIB` and
`SKIA_DEP_USE_LIBPNG` were set inside the command substitution used to produce
GN arguments, then lost before metadata generation. Its sidecar therefore
omitted repository targets and the real consumer failed with PNG symbols. The
packaging boundary now re-resolves and validates those choices in its own shell,
and the generator rejects a repository libpng/effective GN mismatch.

Fresh macOS, iOS device, and iOS Simulator archives and sidecars were built.
Both mobile pairs passed metadata/hash validation and the existing XCFramework
packager succeeded. The corrected fresh macOS pair linked the Metal fixture
with only `Skia::Skia`.

The TotalCross local override compiled far enough to expose its legacy `linux`
definition selecting the wrong pinned Skia header platform once `SK_METAL` was
propagated. `Skia::Skia` now exports a metadata-derived `SK_BUILD_FOR_*`
definition for every supported platform. The repeated focused downstream build
then produced ARM64 `libtcvm.dylib` without any downstream source or pin change.
