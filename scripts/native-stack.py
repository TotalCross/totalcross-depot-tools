#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Plan selective native dependency stacks without mutating release state."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any, Callable, Sequence


ROOT = Path(__file__).resolve().parents[1]


def _load_module(name: str, path: Path) -> Any:
    specification = importlib.util.spec_from_file_location(name, path)
    assert specification and specification.loader
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


NATIVE_BUILD = _load_module("native_build", ROOT / "scripts" / "native-build.py")
NATIVE_RELEASE = _load_module("native_release", ROOT / "scripts" / "native-release.py")
OPERATIONS = ("build", "release", "force-release")


class NativeStackError(ValueError):
    """A compact stack-planning error."""


def _requested_members(config: dict[str, Any], stack: str, requested: str | None) -> list[str]:
    members = list(config["stacks"][stack]["libraries"])
    if requested in (None, "", "all"):
        return members
    names = [name.strip() for name in requested.split(",") if name.strip()]
    unknown = sorted(set(names) - set(members))
    if unknown:
        raise NativeStackError(f"{stack} does not contain {', '.join(unknown)}")
    return names


def _order_for_roots(config: dict[str, Any], roots: Sequence[str]) -> list[str]:
    libraries = config["libraries"]
    ordered: list[str] = []
    permanent: set[str] = set()

    def visit(library: str) -> None:
        if library in permanent:
            return
        for dependency in libraries[library].get("dependencies", {}):
            visit(dependency)
        permanent.add(library)
        ordered.append(library)

    for root in roots:
        visit(root)
    return ordered


def plan_stack(
    config: dict[str, Any],
    stack: str,
    operation: str,
    requested: str | None,
    release_info: Callable[[str], dict[str, Any]],
    tags: Sequence[str],
    releases: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    if stack not in config["stacks"]:
        raise NativeStackError(f"unknown stack {stack}")
    if operation not in OPERATIONS:
        raise NativeStackError(f"invalid operation {operation}")
    roots = _requested_members(config, stack, requested)
    order = _order_for_roots(config, roots)
    entries: list[dict[str, Any]] = []
    selected: set[str] = set()
    recoveries: list[dict[str, str]] = []
    metadata_by_library: dict[str, dict[str, Any]] = {}
    for library in order:
        info = release_info(library)
        metadata_by_library[library] = info
        if operation == "build":
            action = "build"
            tag = ""
            state = "build"
        elif operation == "release":
            inspected = NATIVE_RELEASE.inspect_release(info, tags, releases)
            state = inspected["status"]
            tag = inspected["effective_release_tag"]
            if state == "existing-release":
                action = "external"
            elif state == "build-required":
                action = "build-and-release"
            else:
                action = "recovery-required"
                recoveries.append({"library": library, "reason": inspected["reason"]})
        else:
            tag = NATIVE_RELEASE.next_force_tag(info["base_tag"], tags)
            state = "build-required"
            action = "build-and-release"
        if action != "external" and action != "recovery-required":
            selected.add(library)
        entries.append(
            {
                "library": library,
                "action": action,
                "state": state,
                "version": info["version"],
                "effective_release_tag": tag,
                "dependencies": [],
            }
        )
    by_library = {entry["library"]: entry for entry in entries}
    for library in order:
        dependencies = config["libraries"][library].get("dependencies", {})
        for dependency in dependencies:
            dependency_info = metadata_by_library[dependency]
            by_library[library]["dependencies"].append(
                {
                    "library": dependency,
                    "source": "local" if dependency in selected else "external",
                    "release": by_library[dependency]["effective_release_tag"] or dependency_info["deps_release"],
                }
            )
    lanes: dict[tuple[str, str], dict[str, Any]] = {}
    for library in order:
        if library not in selected or config["libraries"][library]["build_system"] != "cmake":
            continue
        for target in config["libraries"][library]["targets"]:
            resolved = NATIVE_BUILD.resolve(config, library, target)
            key = (target, resolved["runner"])
            lane = lanes.setdefault(
                key,
                {"target": target, "runner": resolved["runner"], "libraries": []},
            )
            lane["libraries"].append(library)
    return {
        "stack": stack,
        "operation": operation,
        "requested_libraries": roots,
        "order": order,
        "libraries": entries,
        "lanes": [lanes[key] for key in sorted(lanes)],
        "publication_order": [library for library in order if library in selected],
        "recoveries": recoveries,
    }


def _fixture(path: Path | None, fallback: Callable[[], Any]) -> Any:
    if path is None:
        return fallback()
    return json.loads(path.read_text(encoding="utf-8"))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--tags-file", type=Path)
    parser.add_argument("--releases-file", type=Path)
    parser.add_argument("--libraries", default="all", help="Comma-separated stack members or all.")
    parser.add_argument("stack", choices=("graphics", "others"))
    parser.add_argument("operation", nargs="?", default="build", choices=OPERATIONS)
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve()
        config = NATIVE_BUILD.load_config(root / "config" / "native-builds.yml")
        if args.operation == "build":
            tags, releases = [], []
        else:
            tags = _fixture(args.tags_file, lambda: NATIVE_RELEASE._remote_tags(args.remote))
            if args.releases_file:
                releases = _fixture(args.releases_file, list)
            else:
                if not args.repository:
                    raise NativeStackError("repository is required when no releases fixture is supplied")
                releases = NATIVE_RELEASE._remote_releases(args.repository)
        outcome = plan_stack(
            config,
            args.stack,
            args.operation,
            args.libraries,
            lambda library: NATIVE_RELEASE.metadata(root, library),
            tags,
            releases,
        )
        print(json.dumps(outcome, indent=2, sort_keys=True))
        return 2 if outcome["recoveries"] else 0
    except (NativeStackError, NATIVE_RELEASE.NativeReleaseError, NATIVE_BUILD.NativeBuildError) as error:
        print(f"native-stack: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
