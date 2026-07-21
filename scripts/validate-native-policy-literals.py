#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Reject native build policy literals outside approved central or runtime files."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LITERALS = (
    re.compile(r"28\.2\.13676358"),
    re.compile(r"ANDROID_PLATFORM=android-\d+"),
    re.compile(r"totalcross/(?:linux|skia-linux)-[^\s'\"]+:v[\d.]+"),
    re.compile(r"Visual Studio 17 2022"),
    re.compile(r"(?:CMAKE_MSVC_RUNTIME_LIBRARY|MSVC_RUNTIME_LIBRARY).*MultiThreaded"),
)
APPROVED = {
    ".github/actions/setup-android-native/action.yml",
    ".github/workflows/build-skia.yml",
    "config/native-builds.yml",
    "libjpeg-turbo/CMakeLists.txt",
    "scripts/build-native-target.sh",
    "scripts/inventory-native-build-orchestration.py",
    "scripts/tests/test_native_build.py",
    "scripts/tests/test_native_build_target.py",
    "scripts/validate-native-policy-literals.py",
    "scripts/validate-native-wrappers.py",
    "sljit/CMakeLists.txt",
    "sljit/README.md",
    "sljit/fetch.sh",
    "sljit/manifest.yml",
}


def candidates() -> list[Path]:
    paths: list[Path] = []
    for directory in (ROOT / ".github", ROOT / "config", ROOT / "scripts"):
        paths.extend(path for path in directory.rglob("*") if path.is_file())
    for manifest in ROOT.glob("*/manifest.yml"):
        dependency = manifest.parent
        paths.extend(path for path in (dependency / "CMakeLists.txt", dependency / "README.md", dependency / "fetch.sh") if path.is_file())
    return sorted({path for path in paths if "__pycache__" not in path.parts})


def main() -> int:
    violations: list[str] = []
    for path in candidates():
        relative = str(path.relative_to(ROOT))
        if relative in APPROVED:
            continue
        content = path.read_text(encoding="utf-8", errors="ignore")
        if any(pattern.search(content) for pattern in LITERALS):
            violations.append(relative)
    if violations:
        print("native policy literals outside approved files:", *violations, sep="\n", file=sys.stderr)
        return 1
    print("validated native policy literals: 0 violations outside approved files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
