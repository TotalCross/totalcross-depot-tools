#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Emit a deterministic baseline inventory for native build orchestration."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
MANIFEST_NAMES = ("manifest.yml", "manifest.yaml", "manifest.json")
POLICY_LITERALS = {
    "android_ndk_version": r"28\.2\.13676358",
    "android_api": r"ANDROID_PLATFORM=android-[0-9]+|\bapi:\s*[0-9]+",
    "linux_image_tag": r"totalcross/linux-[^\s'\"]+:v[0-9][^\s'\"]*",
    "visual_studio_generator": r"Visual Studio 17 2022",
    "msvc_runtime": r"CMAKE_MSVC_RUNTIME_LIBRARY",
}


def first_value(text: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}:\s*([^#\n]+)", text, re.MULTILINE)
    return match.group(1).strip().strip("'\"") if match else None


def nested_names(text: str, heading: str, indent: int) -> list[str]:
    lines = text.splitlines()
    names: list[str] = []
    heading_pattern = re.compile(rf"^ {{{indent}}}{re.escape(heading)}:\s*$")
    item_pattern = re.compile(rf"^ {{{indent + 2}}}([A-Za-z0-9_-]+):")
    for index, line in enumerate(lines):
        if not heading_pattern.match(line):
            continue
        for child in lines[index + 1 :]:
            if child and len(child) - len(child.lstrip(" ")) <= indent:
                break
            match = item_pattern.match(child)
            if match:
                names.append(match.group(1))
    return sorted(set(names))


def workflow_details(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    jobs_section = text.split("\njobs:\n", 1)[1] if "\njobs:\n" in text else ""
    job_names = [
        match.group(1)
        for match in re.finditer(r"^  ([A-Za-z0-9_-]+):\s*$", jobs_section, re.MULTILINE)
    ]
    artifact_names: list[str] = []
    for match in re.finditer(r"uses:\s*actions/upload-artifact@[^\n]+", text):
        window = text[match.end() : match.end() + 600]
        name = re.search(r"^\s{10,}name:\s*([^\n#]+)", window, re.MULTILINE)
        if name:
            artifact_names.append(name.group(1).strip().strip("'\""))
    triggers = re.findall(
        r"^  (workflow_call|workflow_dispatch|pull_request|push):", text, re.MULTILINE
    )
    return {
        "name": first_value(text, "name"),
        "triggers": sorted(set(triggers)),
        "inputs": nested_names(text, "inputs", 4),
        "jobs": job_names,
        "matrix_jobs": [job for job in job_names if re.search(rf"^  {re.escape(job)}:.*?(?=^  [A-Za-z0-9_-]+:|\Z)", jobs_section, re.MULTILINE | re.DOTALL) and "matrix:" in re.search(rf"^  {re.escape(job)}:.*?(?=^  [A-Za-z0-9_-]+:|\Z)", jobs_section, re.MULTILINE | re.DOTALL).group(0)],
        "artifact_uploads": artifact_names,
        "uses_reusable_workflow": "uses: ./.github/workflows/" in text,
    }


def manifest_details(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    archives: list[str] = []
    collecting = False
    for line in text.splitlines():
        if re.match(r"^\s{2}archives:\s*$", line):
            collecting = True
            continue
        if collecting:
            match = re.match(r"^\s{4}-\s+(.+)$", line)
            if match:
                archives.append(match.group(1).strip().strip("'\""))
                continue
            if line and not line.startswith("    "):
                break
    return {
        "version": first_value(text, "version"),
        "release": first_value(text, "release"),
        "archives": archives,
    }


def library_manifests() -> dict[str, Path]:
    manifests: dict[str, Path] = {}
    for directory in sorted(path for path in ROOT.iterdir() if path.is_dir()):
        for name in MANIFEST_NAMES:
            path = directory / name
            if path.is_file():
                manifests[directory.name] = path
                break
    return dict(sorted(manifests.items()))


def matching_workflows(prefix: str, library: str) -> list[Path]:
    candidates = [WORKFLOWS / f"{prefix}-{library}.yml", WORKFLOWS / f"{prefix}-{library}.yaml"]
    return [path for path in candidates if path.exists()]


def policy_occurrences() -> dict[str, list[str]]:
    files = [candidate for candidate in (ROOT / ".github").rglob("*") if candidate.is_file()]
    files.extend(candidate for candidate in (ROOT / "scripts").rglob("*") if candidate.is_file())
    for library in library_manifests().values():
        directory = library.parent
        files.extend(
            path
            for path in (
                directory / "CMakeLists.txt",
                directory / "fetch.sh",
                directory / "README.md",
                library,
            )
            if path.is_file()
        )
    for name in ("cmake", "scripts"):
            child = directory / name
            if child.is_dir():
                files.extend(path for path in child.rglob("*") if path.is_file())
    files = [
        path
        for path in set(files)
        if "__pycache__" not in path.parts and path.resolve() != Path(__file__).resolve()
    ]
    result: dict[str, list[str]] = {}
    for name, pattern in POLICY_LITERALS.items():
        result[name] = sorted(
            str(path.relative_to(ROOT))
            for path in files
            if re.search(pattern, path.read_text(encoding="utf-8", errors="ignore"))
        )
    return result


def inventory() -> dict[str, Any]:
    manifests = library_manifests()
    libraries: dict[str, Any] = {}
    for library, manifest in manifests.items():
        libraries[library] = {
            "manifest": str(manifest.relative_to(ROOT)),
            **manifest_details(manifest),
            "build_workflows": [
                str(path.relative_to(ROOT)) for path in matching_workflows("build", library)
            ],
            "release_workflows": [
                str(path.relative_to(ROOT)) for path in matching_workflows("release", library)
            ],
        }
    workflow_inventory = {
        str(path.relative_to(ROOT)): workflow_details(path)
        for path in sorted(WORKFLOWS.glob("*.y*ml"))
    }
    helpers = [
        ".github/actions/publish-native-release/action.yml",
        ".github/scripts/read-deps-release.sh",
        "scripts/native-release.py",
    ]
    return {
        "schema": 2,
        "libraries": libraries,
        "workflows": workflow_inventory,
        "policy_literal_occurrences": policy_occurrences(),
        "release_helpers": helpers,
        "release_suffix_rule": "<dependency>-<version>, then -r<N> after any matching tag exists",
        "stack_workflows": [
            ".github/workflows/graphics-stack.yml",
            ".github/workflows/others-stack.yml",
        ],
        "skia_parallelism": {
            "workflow": ".github/workflows/build-skia.yml",
            "jobs": workflow_inventory[".github/workflows/build-skia.yml"]["jobs"],
            "matrix_jobs": workflow_inventory[".github/workflows/build-skia.yml"]["matrix_jobs"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", choices=("json", "summary"), default="json")
    args = parser.parse_args()
    result = inventory()
    if args.format == "summary":
        summary = {
            "libraries": len(result["libraries"]),
            "workflows": len(result["workflows"]),
            "policy_literal_files": {
                key: len(value) for key, value in result["policy_literal_occurrences"].items()
            },
            "skia_jobs": result["skia_parallelism"]["jobs"],
        }
        print(json.dumps(summary, sort_keys=True))
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
