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
