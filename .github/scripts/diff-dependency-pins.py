#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Report semantic dependency-pin changes between two deps.yml documents.

The bundle index is YAML, so line based diffs incorrectly route formatting-only
changes.  This command compares the fields that identify a usable prebuilt
release and emits both a JSON report and GitHub Actions outputs.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

CONSUMERS = {
    "zlib": ("minizip",),
    "zlib-ng": ("libpng", "minizip-ng", "skia"),
    "libpng": ("skia",),
    "libjpeg": (),
    "libjpeg-turbo": (),
}
FIELDS = ("version", "release", "path")


def read_document(value: str) -> dict[str, Any]:
    """Read a path or a git revision's deps.yml without shell interpolation."""
    path = Path(value)
    if path.is_file():
        contents = path.read_text(encoding="utf-8")
    else:
        result = subprocess.run(
            ["git", "show", f"{value}:deps.yml"],
            check=True,
            text=True,
            capture_output=True,
        )
        contents = result.stdout
    # Ruby is already required by this repository's YAML validation command.
    # Its Psych.safe_load implementation avoids adding a Python package install
    # to the routing job and rejects object deserialization.
    result = subprocess.run(
        [
            "ruby",
            "-rjson",
            "-ryaml",
            "-e",
            "puts JSON.generate(YAML.safe_load(STDIN.read, permitted_classes: [], aliases: false))",
        ],
        input=contents,
        check=True,
        text=True,
        capture_output=True,
    )
    document = json.loads(result.stdout)
    if not isinstance(document, dict) or not isinstance(document.get("dependencies"), dict):
        raise ValueError(f"{value} is not a deps.yml document with dependencies")
    return document["dependencies"]


def build_report(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    changed: list[str] = []
    details: dict[str, list[str]] = {}
    for name in sorted(set(before) | set(after)):
        previous = before.get(name)
        current = after.get(name)
        if not isinstance(previous, dict) or not isinstance(current, dict):
            changed.append(name)
            details[name] = ["added-or-removed"]
            continue
        fields = [field for field in FIELDS if previous.get(field) != current.get(field)]
        if fields:
            changed.append(name)
            details[name] = fields

    consumers = sorted({consumer for name in changed for consumer in CONSUMERS.get(name, ())})
    outputs = {name.replace("-", "_"): str(name in consumers).lower() for name in sorted({x for values in CONSUMERS.values() for x in values})}
    outputs["has_consumers"] = str(bool(consumers)).lower()
    outputs["changed_dependencies"] = ",".join(changed)
    outputs["affected_consumers"] = ",".join(consumers)
    return {"changed_dependencies": changed, "changed_fields": details, "affected_consumers": consumers, "github_outputs": outputs}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, help="deps.yml path or git revision")
    parser.add_argument("--after", required=True, help="deps.yml path or git revision")
    parser.add_argument("--format", choices=("json", "github-output", "human"), default="human")
    args = parser.parse_args()
    report = build_report(read_document(args.before), read_document(args.after))
    if args.format == "json":
        print(json.dumps(report, indent=2, sort_keys=True))
    elif args.format == "github-output":
        for key, value in report["github_outputs"].items():
            print(f"{key}={value}")
    else:
        changed = ", ".join(report["changed_dependencies"]) or "none"
        consumers = ", ".join(report["affected_consumers"]) or "none"
        print(f"Changed dependency pins: {changed}")
        print(f"Affected consumers: {consumers}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
