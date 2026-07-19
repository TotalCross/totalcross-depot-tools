#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Resolve the repository's declarative native build configuration."""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "config" / "native-builds.yml"
OPERATIONS = ("build", "release", "force-release")
OVERRIDE_KEYS = {"android_api", "cmake_arguments", "image", "tests"}


class NativeBuildError(ValueError):
    """A compact configuration or command-line error."""


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _scalar(value: str) -> Any:
    value = value.strip()
    if value in ("{}", "[]"):
        return {} if value == "{}" else []
    if value in ("true", "false"):
        return value == "true"
    if value in ("null", "~"):
        return None
    if re.fullmatch(r"-?[0-9]+", value):
        return int(value)
    if (value.startswith("\"") and value.endswith("\"")) or (
        value.startswith("'") and value.endswith("'")
    ):
        return value[1:-1]
    return value


def parse_yaml(text: str) -> dict[str, Any]:
    """Parse the restricted mapping/list YAML used by native-builds.yml.

    The resolver deliberately uses only Python's standard library. The supported
    subset is sufficient for this checked-in policy file: indentation mappings,
    scalar lists, booleans, integers, strings, and empty mappings/lists.
    """

    lines = [
        line.rstrip()
        for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]

    def parse_block(index: int, indent: int) -> tuple[Any, int]:
        if index >= len(lines) or _indent(lines[index]) != indent:
            raise NativeBuildError("invalid YAML indentation")
        is_list = lines[index].lstrip().startswith("- ")
        result: Any = [] if is_list else {}
        while index < len(lines):
            line = lines[index]
            current_indent = _indent(line)
            if current_indent < indent:
                break
            if current_indent > indent:
                raise NativeBuildError("invalid YAML indentation")
            content = line[indent:]
            if is_list:
                if not content.startswith("- "):
                    raise NativeBuildError("cannot mix YAML lists and mappings")
                item = content[2:].strip()
                if not item:
                    index += 1
                    if index >= len(lines) or _indent(lines[index]) <= indent:
                        raise NativeBuildError("YAML list item requires a value")
                    value, index = parse_block(index, _indent(lines[index]))
                    result.append(value)
                    continue
                result.append(_scalar(item))
                index += 1
                continue
            if content.startswith("- ") or ":" not in content:
                raise NativeBuildError("expected a YAML mapping entry")
            key, raw_value = content.split(":", 1)
            key = key.strip()
            if not key or key in result:
                raise NativeBuildError("invalid or duplicate YAML mapping key")
            raw_value = raw_value.strip()
            index += 1
            if raw_value:
                result[key] = _scalar(raw_value)
                continue
            if index >= len(lines) or _indent(lines[index]) <= indent:
                result[key] = {}
                continue
            result[key], index = parse_block(index, _indent(lines[index]))
        return result, index

    if not lines:
        raise NativeBuildError("configuration is empty")
    result, next_index = parse_block(0, 0)
    if next_index != len(lines) or not isinstance(result, dict):
        raise NativeBuildError("configuration root must be a mapping")
    return result


def _mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise NativeBuildError(f"{label} must be a mapping")
    return value


def _list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise NativeBuildError(f"{label} must be a list")
    return value


def _require_keys(mapping: dict[str, Any], label: str, keys: Sequence[str]) -> None:
    missing = [key for key in keys if key not in mapping]
    if missing:
        raise NativeBuildError(f"{label} is missing {', '.join(missing)}")


def _reject_unknown_keys(mapping: dict[str, Any], label: str, allowed: set[str]) -> None:
    unknown = sorted(set(mapping) - allowed)
    if unknown:
        raise NativeBuildError(f"{label} has unknown keys: {', '.join(unknown)}")


def _dependency_order(config: dict[str, Any], roots: Sequence[str]) -> list[str]:
    libraries = _mapping(config["libraries"], "libraries")
    permanent: set[str] = set()
    active: set[str] = set()
    order: list[str] = []

    def visit(library: str) -> None:
        if library in permanent:
            return
        if library in active:
            raise NativeBuildError(f"dependency cycle includes {library}")
        active.add(library)
        dependencies = _mapping(
            libraries[library].get("dependencies", {}), f"libraries.{library}.dependencies"
        )
        for dependency in dependencies:
            visit(dependency)
        active.remove(library)
        permanent.add(library)
        order.append(library)

    for root in roots:
        visit(root)
    return order


def validate_config(config: dict[str, Any]) -> None:
    _require_keys(config, "configuration", ("schema", "defaults", "platforms", "targets", "libraries", "stacks"))
    _reject_unknown_keys(config, "configuration", {"schema", "defaults", "platforms", "targets", "libraries", "stacks"})
    if config["schema"] != 1:
        raise NativeBuildError("schema must be 1")
    defaults = _mapping(config["defaults"], "defaults")
    _require_keys(defaults, "defaults", ("configuration", "cmake_generator"))
    _reject_unknown_keys(defaults, "defaults", {"configuration", "cmake_generator"})
    platforms = _mapping(config["platforms"], "platforms")
    targets = _mapping(config["targets"], "targets")
    libraries = _mapping(config["libraries"], "libraries")
    stacks = _mapping(config["stacks"], "stacks")

    for name, platform in platforms.items():
        platform = _mapping(platform, f"platforms.{name}")
        _require_keys(platform, f"platforms.{name}", ("runner",))
        _reject_unknown_keys(
            platform,
            f"platforms.{name}",
            {
                "runner",
                "ndk_version",
                "default_api",
                "use_legacy_toolchain",
                "image_registry",
                "image_version",
                "generator",
                "runtime_policy",
                "expected_runtime",
            },
        )
    _require_keys(platforms, "platforms", ("android", "linux", "windows", "apple", "web"))
    _require_keys(platforms["android"], "platforms.android", ("ndk_version", "default_api", "use_legacy_toolchain"))
    _require_keys(platforms["linux"], "platforms.linux", ("image_registry", "image_version"))
    _require_keys(platforms["windows"], "platforms.windows", ("generator", "runtime_policy", "expected_runtime"))

    for name, target in targets.items():
        target = _mapping(target, f"targets.{name}")
        _require_keys(target, f"targets.{name}", ("platform", "arch"))
        _reject_unknown_keys(
            target,
            f"targets.{name}",
            {"platform", "artifact_platform", "arch", "build_dir_name", "runner", "image", "docker_platform", "qemu", "cmake_platform", "generator", "sysroot"},
        )
        if target["platform"] not in platforms:
            raise NativeBuildError(f"targets.{name} references unknown platform {target['platform']}")
        if target["platform"] == "linux":
            _require_keys(target, f"targets.{name}", ("image", "docker_platform"))
            if ":" in str(target["image"]):
                raise NativeBuildError(f"targets.{name}.image must not embed a tag")
        if target["platform"] == "windows":
            _require_keys(target, f"targets.{name}", ("cmake_platform",))

    for name, library in libraries.items():
        library = _mapping(library, f"libraries.{name}")
        _require_keys(library, f"libraries.{name}", ("build_system", "targets"))
        _reject_unknown_keys(
            library,
            f"libraries.{name}",
            {"build_system", "package_script", "targets", "dependencies", "target_overrides", "tests", "cmake_arguments", "long_running", "preserve_target_parallelism", "apple_xcframework"},
        )
        if library["build_system"] not in ("cmake", "gn", "custom"):
            raise NativeBuildError(f"libraries.{name}.build_system is unsupported")
        if library["build_system"] == "cmake" and not library.get("package_script"):
            raise NativeBuildError(f"libraries.{name} is missing package_script")
        library_targets = _list(library["targets"], f"libraries.{name}.targets")
        if not library_targets:
            raise NativeBuildError(f"libraries.{name}.targets must not be empty")
        if len(library_targets) != len(set(library_targets)):
            raise NativeBuildError(f"libraries.{name}.targets contains duplicates")
        for target in library_targets:
            if target not in targets:
                raise NativeBuildError(f"libraries.{name} references unknown target {target}")
        dependencies = _mapping(library.get("dependencies", {}), f"libraries.{name}.dependencies")
        for dependency, details in dependencies.items():
            if dependency not in libraries:
                raise NativeBuildError(f"libraries.{name} references unknown dependency {dependency}")
            details = _mapping(details, f"libraries.{name}.dependencies.{dependency}")
            _reject_unknown_keys(details, f"libraries.{name}.dependencies.{dependency}", {"cmake_variable"})
        arguments = _list(library.get("cmake_arguments", []), f"libraries.{name}.cmake_arguments")
        if not all(isinstance(argument, str) for argument in arguments):
            raise NativeBuildError(f"libraries.{name}.cmake_arguments must contain strings")
        apple_xcframework = _mapping(
            library.get("apple_xcframework", {}), f"libraries.{name}.apple_xcframework"
        )
        if apple_xcframework:
            _reject_unknown_keys(
                apple_xcframework,
                f"libraries.{name}.apple_xcframework",
                {"libraries", "merge"},
            )
            xcframework_libraries = _list(
                apple_xcframework.get("libraries", []),
                f"libraries.{name}.apple_xcframework.libraries",
            )
            if not xcframework_libraries or not all(
                isinstance(item, str) and item for item in xcframework_libraries
            ):
                raise NativeBuildError(f"libraries.{name}.apple_xcframework.libraries is invalid")
            if "merge" in apple_xcframework and not isinstance(apple_xcframework["merge"], bool):
                raise NativeBuildError(f"libraries.{name}.apple_xcframework.merge is invalid")
        overrides = _mapping(library.get("target_overrides", {}), f"libraries.{name}.target_overrides")
        for target, override in overrides.items():
            if target not in targets or target not in library_targets:
                raise NativeBuildError(f"libraries.{name}.target_overrides references unsupported target {target}")
            override = _mapping(override, f"libraries.{name}.target_overrides.{target}")
            if not override:
                raise NativeBuildError(f"libraries.{name}.target_overrides.{target} is incomplete")
            unknown = sorted(set(override) - OVERRIDE_KEYS)
            if unknown:
                raise NativeBuildError(f"libraries.{name}.target_overrides.{target} has unknown keys")
            if "android_api" in override:
                if targets[target]["platform"] != "android" or not isinstance(override["android_api"], int):
                    raise NativeBuildError(f"libraries.{name}.target_overrides.{target}.android_api is invalid")
            if "cmake_arguments" in override:
                override_arguments = _list(
                    override["cmake_arguments"],
                    f"libraries.{name}.target_overrides.{target}.cmake_arguments",
                )
                if not all(isinstance(argument, str) for argument in override_arguments):
                    raise NativeBuildError(f"libraries.{name}.target_overrides.{target}.cmake_arguments is invalid")
            if "image" in override and ":" in str(override["image"]):
                raise NativeBuildError(f"libraries.{name}.target_overrides.{target}.image must not embed a tag")

    for name, stack in stacks.items():
        stack = _mapping(stack, f"stacks.{name}")
        _require_keys(stack, f"stacks.{name}", ("libraries",))
        _reject_unknown_keys(stack, f"stacks.{name}", {"libraries"})
        members = _list(stack["libraries"], f"stacks.{name}.libraries")
        if len(members) != len(set(members)):
            raise NativeBuildError(f"stacks.{name}.libraries contains duplicates")
        for member in members:
            if member not in libraries:
                raise NativeBuildError(f"stacks.{name} references unknown library {member}")

    _dependency_order(config, list(libraries))


def load_config(path: Path = CONFIG_PATH) -> dict[str, Any]:
    try:
        config = parse_yaml(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise NativeBuildError(f"cannot read configuration: {error}") from error
    validate_config(config)
    return config


def resolve(config: dict[str, Any], library_name: str, target_name: str) -> dict[str, Any]:
    libraries = config["libraries"]
    targets = config["targets"]
    if library_name not in libraries:
        raise NativeBuildError(f"unknown library {library_name}")
    if target_name not in targets:
        raise NativeBuildError(f"unknown target {target_name}")
    library = libraries[library_name]
    if target_name not in library["targets"]:
        raise NativeBuildError(f"library {library_name} does not publish {target_name}")
    target = copy.deepcopy(targets[target_name])
    platform_name = target["platform"]
    platform = copy.deepcopy(config["platforms"][platform_name])
    override = copy.deepcopy(library.get("target_overrides", {}).get(target_name, {}))
    result: dict[str, Any] = {
        "library": library_name,
        "source_dir": library_name,
        "target": target_name,
        "platform": target.get("artifact_platform", platform_name),
        "platform_family": platform_name,
        "arch": target["arch"],
        "build_dir_name": target.get("build_dir_name", target_name),
        "runner": target.get("runner", platform["runner"]),
        "build_system": library["build_system"],
        "configuration": config["defaults"]["configuration"],
        "generator": target.get("generator", platform.get("generator", config["defaults"]["cmake_generator"])),
        "package_script": library.get("package_script"),
        "tests": override.get("tests", library.get("tests", False)),
        "dependencies": copy.deepcopy(library.get("dependencies", {})),
        "cmake_arguments": list(library.get("cmake_arguments", [])) + list(override.get("cmake_arguments", [])),
        "apple_xcframework": copy.deepcopy(library.get("apple_xcframework", {})),
    }
    if platform_name == "android":
        result.update(
            {
                "android_ndk_version": platform["ndk_version"],
                "android_api": override.get("android_api", platform["default_api"]),
                "android_abi": target["arch"],
                "android_use_legacy_toolchain": platform["use_legacy_toolchain"],
            }
        )
    if platform_name == "linux":
        image = override.get("image", target["image"])
        result.update(
            {
                "docker_image": f"{platform['image_registry']}/{image}:{platform['image_version']}",
                "docker_platform": target["docker_platform"],
                "qemu": bool(target.get("qemu", False)),
            }
        )
    if platform_name == "windows":
        result.update(
            {
                "cmake_platform": target["cmake_platform"],
                "windows_runtime_policy": platform["runtime_policy"],
                "windows_expected_runtime": platform["expected_runtime"],
            }
        )
    if platform_name == "apple":
        result["apple_sysroot"] = target.get("sysroot", "") or ""
    return result


def graph(config: dict[str, Any], stack_name: str) -> dict[str, Any]:
    stacks = config["stacks"]
    if stack_name not in stacks:
        raise NativeBuildError(f"unknown stack {stack_name}")
    members = stacks[stack_name]["libraries"]
    order = _dependency_order(config, members)
    edges = [
        {"from": dependency, "to": library}
        for library in order
        for dependency in config["libraries"][library].get("dependencies", {})
    ]
    return {"stack": stack_name, "libraries": list(members), "order": order, "edges": edges}


def plan(config: dict[str, Any], selector: str, operation: str) -> dict[str, Any]:
    if operation not in OPERATIONS:
        raise NativeBuildError(f"invalid operation {operation}")
    if selector in config["libraries"]:
        libraries = _dependency_order(config, [selector])
        kind = "library"
    elif selector in config["stacks"]:
        libraries = graph(config, selector)["order"]
        kind = "stack"
    else:
        raise NativeBuildError(f"unknown library or stack {selector}")
    return {
        "selector": selector,
        "kind": kind,
        "operation": operation,
        "libraries": libraries,
        "targets": {library: list(config["libraries"][library]["targets"]) for library in libraries},
    }


def _emit(value: Any, output_format: str) -> None:
    if output_format == "json":
        print(json.dumps(value, indent=2, sort_keys=True))
        return
    if output_format == "text":
        for key in sorted(value):
            encoded = json.dumps(value[key], sort_keys=True) if isinstance(value[key], (dict, list)) else str(value[key]).lower() if isinstance(value[key], bool) else value[key]
            print(f"{key}={encoded}")
        return
    if output_format == "github-output":
        for key in sorted(value):
            encoded = json.dumps(value[key], separators=(",", ":"), sort_keys=True) if isinstance(value[key], (dict, list)) else str(value[key]).lower() if isinstance(value[key], bool) else value[key]
            print(f"{key}={encoded}")
        return
    if output_format == "mermaid":
        print("graph TD")
        for edge in value["edges"]:
            print(f"  {edge['from'].replace('-', '_')} --> {edge['to'].replace('-', '_')}")
        return
    raise NativeBuildError(f"unsupported format {output_format}")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    subcommands.add_parser("validate")
    show = subcommands.add_parser("show")
    show.add_argument("library")
    show.add_argument("target")
    show.add_argument("--format", choices=("text", "json", "github-output"), default="text")
    list_targets = subcommands.add_parser("list-targets")
    list_targets.add_argument("library")
    list_targets.add_argument("--format", choices=("json",), default="json")
    graph_command = subcommands.add_parser("graph")
    graph_command.add_argument("stack")
    graph_command.add_argument("--format", choices=("json", "mermaid"), default="json")
    plan_command = subcommands.add_parser("plan")
    plan_command.add_argument("selector")
    plan_command.add_argument("--operation", required=True, choices=OPERATIONS)
    plan_command.add_argument("--format", choices=("json",), default="json")
    args = parser.parse_args(argv)
    try:
        config = load_config()
        if args.command == "validate":
            print("native-build configuration is valid")
        elif args.command == "show":
            _emit(resolve(config, args.library, args.target), args.format)
        elif args.command == "list-targets":
            if args.library not in config["libraries"]:
                raise NativeBuildError(f"unknown library {args.library}")
            _emit({"library": args.library, "targets": config["libraries"][args.library]["targets"]}, args.format)
        elif args.command == "graph":
            _emit(graph(config, args.stack), args.format)
        elif args.command == "plan":
            _emit(plan(config, args.selector, args.operation), args.format)
        return 0
    except NativeBuildError as error:
        print(f"native-build: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
