#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Validate SPDX headers on first-party, comment-capable repository files."""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
from dataclasses import dataclass


COPYRIGHT = "SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda."
LICENSE = "SPDX-License-Identifier: MIT"
EXCLUDED_PATHS = {".agent/PLANS.md"}
EXCLUDED_PATHS.update({
    "axtls/extensions/windows/stdbool.h",
    "qrcodegen/extensions/windows/stdbool.h",
})
EXCLUDED_DIRECTORIES = {
    ".git",
    "build",
    "dist",
    "out",
    "target",
    "node_modules",
    "third_party",
    "third-party",
    "vendor",
    "vendored",
    "generated",
}
EXCLUDED_BASENAMES = {"THIRD_PARTY_NOTICES.md"}
HASH_EXTENSIONS = {
    ".bash",
    ".cmake",
    ".dockerfile",
    ".ps1",
    ".py",
    ".rb",
    ".sh",
    ".yaml",
    ".yml",
}
BLOCK_EXTENSIONS = {
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".java",
    ".js",
    ".jsx",
    ".kt",
    ".kts",
    ".m",
    ".mm",
    ".rs",
    ".ts",
    ".tsx",
}


@dataclass(frozen=True)
class Candidate:
    path: str
    style: str


def classify(path: str) -> Candidate | None:
    """Return the comment style for a path, or None when it is not applicable."""
    normalized = path.replace("\\", "/")
    if normalized in EXCLUDED_PATHS:
        return None
    parts = pathlib.PurePosixPath(normalized).parts
    if any(part in EXCLUDED_DIRECTORIES for part in parts):
        return None
    if pathlib.PurePosixPath(normalized).name in EXCLUDED_BASENAMES:
        return None
    suffix = pathlib.PurePosixPath(normalized).suffix.lower()
    if suffix in HASH_EXTENSIONS or pathlib.PurePosixPath(normalized).name in {"Dockerfile", "CMakeLists.txt"}:
        return Candidate(normalized, "hash")
    if suffix in BLOCK_EXTENSIONS:
        return Candidate(normalized, "block")
    return None


def tracked_paths(root: pathlib.Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    )
    return sorted(path for path in result.stdout.decode().split("\0") if path)


def staged_paths(root: pathlib.Path) -> list[str]:
    """Return added, copied, modified, or renamed paths staged for commit."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    )
    return sorted(path for path in result.stdout.decode().split("\0") if path)


def selected_paths(root: pathlib.Path, paths: list[str]) -> list[str]:
    """Normalize user paths and reject values outside the selected root."""
    normalized: list[str] = []
    for path in paths:
        candidate = pathlib.Path(path)
        resolved = (candidate if candidate.is_absolute() else root / candidate).resolve()
        try:
            normalized.append(str(resolved.relative_to(root)))
        except ValueError as error:
            raise ValueError(f"path is outside --root: {path}") from error
    return sorted(set(normalized))


def header_lines(candidate: Candidate) -> tuple[str, str]:
    if candidate.style == "block":
        return (
            " * " + COPYRIGHT,
            " * " + LICENSE,
        )
    return ("# " + COPYRIGHT, "# " + LICENSE)


def validate(root: pathlib.Path, paths: list[str] | None = None) -> list[str]:
    diagnostics: list[str] = []
    candidates = [classify(path) for path in (paths if paths is not None else tracked_paths(root))]
    for candidate in sorted((item for item in candidates if item), key=lambda item: item.path):
        file_path = root / candidate.path
        try:
            text = file_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            diagnostics.append(f"{candidate.path}: cannot read file ({exc})")
            continue
        first_lines = text.splitlines()[:16]
        copyright_line, license_line = header_lines(candidate)
        if copyright_line not in first_lines:
            diagnostics.append(f"{candidate.path}: missing SPDX-FileCopyrightText")
        if COPYRIGHT not in text:
            diagnostics.append(
                f'{candidate.path}: expected copyright holder "2026 Amalgam Solucoes em TI Ltda."'
            )
        if license_line not in first_lines:
            diagnostics.append(f"{candidate.path}: missing SPDX-License-Identifier")
        if LICENSE not in text:
            diagnostics.append(f'{candidate.path}: expected SPDX license "MIT"')
        for old_license in ("LG" + "PL-2.1-only", "LG" + "PL-2.1-or-later", "LG" + "PL-2.1+"):
            if old_license in text:
                diagnostics.append(f'{candidate.path}: obsolete SPDX license "{old_license}"')
        obsolete_company_notice = "Copyright (C) 2026 " + "Amalgam Solucoes em TI Ltda"
        if obsolete_company_notice in text:
            diagnostics.append(f"{candidate.path}: obsolete company copyright notice")
    return sorted(set(diagnostics))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd())
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--paths", nargs="+", metavar="PATH", help="validate only these repository paths")
    selection.add_argument("--staged", action="store_true", help="validate only staged added, copied, modified, or renamed paths")
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        paths = selected_paths(root, args.paths) if args.paths is not None else staged_paths(root) if args.staged else None
    except ValueError as error:
        parser.error(str(error))
    diagnostics = validate(root, paths)
    if diagnostics:
        print("\n".join(diagnostics), file=sys.stderr)
        return 1
    applicable_paths = tracked_paths(root) if paths is None else paths
    applicable = sum(classify(path) is not None for path in applicable_paths)
    print(
        f"Copyright validation passed: {applicable} applicable files checked; "
        f"{len(EXCLUDED_PATHS)} explicit path excluded."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
