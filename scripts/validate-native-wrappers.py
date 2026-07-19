#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Reject policy literals and non-delegating explicit native target wrappers."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY_LITERALS = (
    r"28\.2\.13676358",
    r"ANDROID_PLATFORM=android-",
    r"totalcross/linux-[^\s'\"]+:v",
    r"Visual Studio 17 2022",
    r"CMAKE_MSVC_RUNTIME_LIBRARY",
)
DELEGATION = re.compile(
    r'exec "\$\{repo_root\}/scripts/build-native-target\.sh" ([a-z0-9-]+) ([a-z0-9_-]+) "\$@"'
)


def validate(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    failures: list[str] = []
    if not DELEGATION.search(text):
        failures.append("does not delegate to build-native-target.sh")
    for literal in POLICY_LITERALS:
        if re.search(literal, text):
            failures.append("contains a native build policy literal")
            break
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path)
    args = parser.parse_args()
    paths = args.paths or sorted((ROOT / "zlib" / "scripts").glob("build-*.sh"))
    failures = [(path, reason) for path in paths for reason in validate(path)]
    if failures:
        for path, reason in failures:
            print(f"{path}: {reason}", file=sys.stderr)
        return 1
    print(f"validated {len(paths)} native target wrappers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
