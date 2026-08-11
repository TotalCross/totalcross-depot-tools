#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

"""Generate the versioned CMake link-contract sidecar for a Skia archive."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import sys


FORMAT_VERSION = 1

BOOLEAN_FIELDS = (
    ("skia_enable_gpu", "SKIA_BUILD_ENABLE_GPU"),
    ("skia_use_gl", "SKIA_BUILD_USE_GL"),
    ("skia_use_egl", "SKIA_BUILD_USE_EGL"),
    ("skia_use_metal", "SKIA_BUILD_USE_METAL"),
    ("skia_use_vulkan", "SKIA_BUILD_USE_VULKAN"),
    ("skia_use_opencl", "SKIA_BUILD_USE_OPENCL"),
    ("skia_use_webgl", "SKIA_BUILD_USE_WEBGL"),
    ("skia_use_angle", "SKIA_BUILD_USE_ANGLE"),
    ("skia_use_dawn", "SKIA_BUILD_USE_DAWN"),
    ("skia_use_direct3d", "SKIA_BUILD_USE_DIRECT3D"),
    ("skia_use_vma", "SKIA_BUILD_USE_VMA"),
    ("skia_use_x11", "SKIA_BUILD_USE_X11"),
    ("skia_use_fonthost_mac", "SKIA_BUILD_USE_FONTHOST_MAC"),
    ("skia_use_freetype", "SKIA_BUILD_USE_FREETYPE"),
    ("skia_use_fontconfig", "SKIA_BUILD_USE_FONTCONFIG"),
    ("skia_enable_fontmgr_fontconfig", "SKIA_BUILD_ENABLE_FONTMGR_FONTCONFIG"),
    ("skia_enable_fontmgr_android", "SKIA_BUILD_ENABLE_FONTMGR_ANDROID"),
    ("skia_enable_fontmgr_win", "SKIA_BUILD_ENABLE_FONTMGR_WIN"),
    ("skia_enable_fontmgr_win_gdi", "SKIA_BUILD_ENABLE_FONTMGR_WIN_GDI"),
    ("skia_use_harfbuzz", "SKIA_BUILD_USE_HARFBUZZ"),
    ("skia_use_expat", "SKIA_BUILD_USE_EXPAT"),
    ("skia_use_icu", "SKIA_BUILD_USE_ICU"),
    ("skia_use_zlib", "SKIA_BUILD_USE_ZLIB"),
    ("skia_use_libpng_decode", "SKIA_BUILD_USE_LIBPNG_DECODE"),
    ("skia_use_libpng_encode", "SKIA_BUILD_USE_LIBPNG_ENCODE"),
    ("skia_use_system_libpng", "SKIA_BUILD_USE_SYSTEM_LIBPNG"),
)

TARGET_LOCAL_BOOLEAN_FIELDS = (
    ("skia_use_system_freetype2", "SKIA_BUILD_USE_SYSTEM_FREETYPE2"),
    ("skia_use_system_harfbuzz", "SKIA_BUILD_USE_SYSTEM_HARFBUZZ"),
    ("skia_use_system_expat", "SKIA_BUILD_USE_SYSTEM_EXPAT"),
    ("skia_use_system_icu", "SKIA_BUILD_USE_SYSTEM_ICU"),
)

STRING_FIELDS = (
    ("target_os", "SKIA_BUILD_TARGET_OS"),
    ("target_cpu", "SKIA_BUILD_TARGET_CPU"),
    ("skia_gl_standard", "SKIA_BUILD_GL_STANDARD"),
)

INTEGER_FIELDS = (("ndk_api", "SKIA_BUILD_NDK_API"),)

ASSIGNMENT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$")


def parse_effective_args(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = ASSIGNMENT_RE.match(raw_line.strip())
        if match:
            values[match.group(1)] = match.group(2)
    return values


def parse_boolean(name: str, raw: str) -> str:
    if raw == "true":
        return "ON"
    if raw == "false":
        return "OFF"
    raise ValueError(f"effective GN argument {name} must be true or false, got {raw!r}")


def parse_string(name: str, raw: str) -> str:
    if len(raw) >= 2 and raw.startswith('"') and raw.endswith('"'):
        value = raw[1:-1]
        if re.fullmatch(r"[A-Za-z0-9_.:+/-]*", value):
            return value
    raise ValueError(f"effective GN argument {name} must be a simple quoted string, got {raw!r}")


def parse_integer(name: str, raw: str) -> str:
    if re.fullmatch(r"[0-9]+", raw):
        return raw
    raise ValueError(f"effective GN argument {name} must be a non-negative integer, got {raw!r}")


def require(values: dict[str, str], name: str) -> str:
    if name not in values:
        raise ValueError(f"effective GN argument listing is missing required value {name}")
    return values[name]


def library_sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as library:
        for block in iter(lambda: library.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def cmake_set(name: str, value: str, quoted: bool = False) -> str:
    if quoted:
        value = f'"{value}"'
    return f"set({name} {value})"


def generate(args: argparse.Namespace) -> str:
    effective = parse_effective_args(args.gn_args_file)
    lines = [
        "# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.",
        "# SPDX-License-Identifier: MIT",
        "# Generated from the effective GN configuration. Do not edit.",
        "",
        cmake_set("SKIA_BUILD_CONFIG_VERSION", str(FORMAT_VERSION)),
        cmake_set("SKIA_BUILD_UPSTREAM_REVISION", args.revision, quoted=True),
        cmake_set("SKIA_BUILD_PLATFORM", args.platform, quoted=True),
        cmake_set("SKIA_BUILD_ARCHITECTURE", args.architecture, quoted=True),
        cmake_set("SKIA_BUILD_LIBRARY_SHA256", library_sha256(args.library), quoted=True),
    ]

    for gn_name, cmake_name in BOOLEAN_FIELDS:
        lines.append(cmake_set(cmake_name, parse_boolean(gn_name, require(effective, gn_name))))
    for gn_name, cmake_name in TARGET_LOCAL_BOOLEAN_FIELDS:
        raw = effective.get(gn_name)
        # These declarations live in nested third_party targets. GN omits them
        # from the effective listing when that target was not loaded, which is
        # itself the authoritative inactive classification.
        value = parse_boolean(gn_name, raw) if raw is not None else "OFF"
        lines.append(cmake_set(cmake_name, value))

    repository_zlib = parse_boolean("repository_zlib", args.repository_zlib)
    repository_libpng = parse_boolean("repository_libpng", args.repository_libpng)
    system_libpng = parse_boolean(
        "skia_use_system_libpng", require(effective, "skia_use_system_libpng")
    )
    if repository_libpng != system_libpng:
        raise ValueError(
            "repository libpng selection does not match effective GN system libpng selection"
        )
    if repository_libpng == "ON" and repository_zlib != "ON":
        raise ValueError("repository libpng requires the repository zlib prebuilt")
    lines.append(cmake_set("SKIA_BUILD_USE_REPOSITORY_ZLIB", repository_zlib))
    lines.append(cmake_set("SKIA_BUILD_USE_REPOSITORY_LIBPNG", repository_libpng))
    # Retain the representative v1 system-zlib field even though this pinned
    # Skia declares it only inside a nested target that is not always loaded.
    lines.append(cmake_set("SKIA_BUILD_USE_SYSTEM_ZLIB", repository_zlib))
    for gn_name, cmake_name in STRING_FIELDS:
        lines.append(cmake_set(cmake_name, parse_string(gn_name, require(effective, gn_name)), quoted=True))

    for gn_name, cmake_name in INTEGER_FIELDS:
        raw = effective.get(gn_name)
        value = parse_integer(gn_name, raw) if raw is not None else ""
        lines.append(cmake_set(cmake_name, value, quoted=True))

    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gn-args-file", type=pathlib.Path, required=True)
    parser.add_argument("--library", type=pathlib.Path, required=True)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--architecture", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--repository-zlib", choices=("true", "false"), required=True)
    parser.add_argument("--repository-libpng", choices=("true", "false"), required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        content = generate(args)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
