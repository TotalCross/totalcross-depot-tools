#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Create and structurally validate native dependency scaffolds."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import stat
import sys
from dataclasses import dataclass
from typing import Any

from native_dependency_targets import KNOWN_STACKS, TARGETS, archive_name, target_names

COPYRIGHT = "SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda."
LICENSE = "SPDX-License-Identifier: MIT"
HASH_HEADER = f"# {COPYRIGHT}\n# {LICENSE}\n"
MD_HEADER = f"<!--\n{COPYRIGHT}\n{LICENSE}\n-->\n"
PLACEHOLDER = "TC_DEPOT_SCAFFOLD_TODO"
NAME_RE = re.compile(r"[a-z0-9][a-z0-9-]*\Z")
PACKAGE_RE = re.compile(r"[A-Za-z][A-Za-z0-9]*\Z")
TARGET_RE = re.compile(r"[A-Za-z][A-Za-z0-9]*(?:::[A-Za-z][A-Za-z0-9]*)+\Z")


@dataclass(frozen=True)
class Spec:
    name: str
    package: str
    version: str
    source_url: str
    source_tag: str
    imported_target: str
    library_name: str
    stack: str
    targets: tuple[str, ...]

    @property
    def auto_fetch(self) -> str:
        return f"tcvm_auto_fetch_{self.name.replace('-', '_')}"


def wrapper(spec: Spec, target: str) -> str:
    return f"""#!/usr/bin/env bash
{HASH_HEADER}set -euo pipefail

repo_root="$(cd "$(dirname "{'$'}{{BASH_SOURCE[0]}}")/../.." && pwd)"
exec "{'$'}{{repo_root}}/scripts/build-native-target.sh" {spec.name} {target} "$@"
"""


def manifest(spec: Spec) -> str:
    targets = "\n".join(f"  - {target}" for target in spec.targets)
    archives = "\n".join(f"    - {archive_name(spec.name, target)}" for target in spec.targets)
    return f"""{HASH_HEADER}name: {spec.name}
version: {spec.version}
release: {spec.name}-{spec.version}
build_system: cmake
stack: {spec.stack}
source:
  type: git
  url: {spec.source_url}
  tag: {spec.source_tag}
cmake:
  package: {spec.package}
  imported_target: {spec.imported_target}
artifact:
  include:
    - {PLACEHOLDER}_header.h
  libraries:
    - {spec.library_name}
  archives:
{archives}
dependencies: []
targets:
{targets}
"""


def cmake(spec: Spec) -> str:
    return f"""{HASH_HEADER}cmake_minimum_required(VERSION 3.16)
include("{'$'}{{CMAKE_CURRENT_LIST_DIR}}/../cmake/TotalCrossWindowsStaticRuntime.cmake")
project(totalcross-{spec.name}-static VERSION {spec.version} LANGUAGES C)
include(FetchContent)
include(GNUInstallDirs)
set({spec.package.upper()}_SOURCE_DIR "" CACHE PATH "Existing upstream source directory")
# {PLACEHOLDER}: declare source, build static target, and install files.
message(FATAL_ERROR "Complete {spec.name}/CMakeLists.txt before building")
"""


def fetch(spec: Spec) -> str:
    return f"""#!/usr/bin/env bash
{HASH_HEADER}set -euo pipefail
# {PLACEHOLDER}: implement --platform, --arch, --release-tag, --github-repo,
# --github-token-env, and --dest. Stage local/<platform>/<arch>.
echo "{spec.name}/fetch.sh scaffold is incomplete" >&2
exit 2
"""


def package(spec: Spec) -> str:
    return f"""#!/usr/bin/env bash
{HASH_HEADER}set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <build-dir> <install-dir> <platform>/<arch>" >&2
  exit 2
fi
# {PLACEHOLDER}: stage include/lib/manifest.txt and create declared archive.
exit 2
"""


def auto_fetch_module(spec: Spec) -> str:
    upper = spec.package.upper()
    return f"""{HASH_HEADER}get_filename_component(TCVM_{upper}_AUTOFETCH_DIR "{'$'}{{CMAKE_CURRENT_LIST_FILE}}" DIRECTORY)
function({spec.auto_fetch})
  # {PLACEHOLDER}: resolve deps.yml pin and fetch missing staged artifact.
  message(FATAL_ERROR "Complete AutoFetch{spec.package}.cmake before consumption")
endfunction()
"""


def find_module(spec: Spec) -> str:
    return f"""{HASH_HEADER}# {PLACEHOLDER}: resolve only depot-tools artifacts with NO_DEFAULT_PATH.
set({spec.package}_FOUND FALSE)
message(FATAL_ERROR "Complete Find{spec.package}.cmake before consumption")
"""


def readme(spec: Spec) -> str:
    targets = "\n".join(f"- {target}" for target in spec.targets)
    return f"""{MD_HEADER}
# {spec.package}

This directory will wrap {spec.name} at {spec.source_url}, revision {spec.source_tag}.

## Published targets

{targets}

## Build, fetch, and consume

Run scripts/build-<target>.sh for a published target. Fetch artifacts into
local/<platform>/<arch>, include cmake/AutoFetch{spec.package}.cmake, call
{spec.auto_fetch}, find_package({spec.package} REQUIRED), and link
{spec.imported_target}.

## Completion work

{PLACEHOLDER}: identify upstream license and notices, implement build/package/
fetch/CMake/workflow behavior, add central configuration, validate a real
consumer, and update deps.yml only in the release operation. This scaffold never
publishes a release or updates deps.yml by itself.
"""


def workflow(spec: Spec) -> str:
    return f"""{HASH_HEADER}name: {spec.package}
on:
  workflow_dispatch:
    inputs:
      operation:
        description: Build or publish {spec.name}
        required: true
        default: build
        type: choice
        options: [build, release, force-release]
permissions:
  contents: write
jobs:
  operation:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v6
      - run: |
          echo "{PLACEHOLDER}: delegate to shared operation tooling" >&2
          exit 2
"""


def files(spec: Spec) -> dict[Path, tuple[str, bool]]:
    root = Path(spec.name)
    result = {
        root / "README.md": (readme(spec), False),
        root / "manifest.yml": (manifest(spec), False),
        root / "CMakeLists.txt": (cmake(spec), False),
        root / "fetch.sh": (fetch(spec), True),
        root / "cmake" / f"AutoFetch{spec.package}.cmake": (auto_fetch_module(spec), False),
        root / "cmake" / f"Find{spec.package}.cmake": (find_module(spec), False),
        root / "scripts" / "package-artifact.sh": (package(spec), True),
        Path(".github/workflows") / f"{spec.name}.yml": (workflow(spec), False),
    }
    for target in spec.targets:
        result[root / "scripts" / f"build-{target}.sh"] = (wrapper(spec, target), True)
    return result


def executable(path: Path) -> None:
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def spec_from(args: argparse.Namespace) -> Spec:
    if not NAME_RE.fullmatch(args.name):
        raise ValueError("--name must use lowercase letters, digits, and hyphens")
    if not PACKAGE_RE.fullmatch(args.package):
        raise ValueError("--package must be an alphanumeric CMake package name")
    if not TARGET_RE.fullmatch(args.imported_target) or args.imported_target.split("::", 1)[0] != args.package:
        raise ValueError("--imported-target must match Package::Target")
    if not re.fullmatch(r"\S+", args.version):
        raise ValueError("--version must be non-empty and contain no whitespace")
    if not re.fullmatch(r"https://\S+", args.source_url):
        raise ValueError("--source-url must be an https URL")
    if not re.fullmatch(r"\S+", args.source_tag):
        raise ValueError("--source-tag must be non-empty and contain no whitespace")
    if not re.fullmatch(r"[A-Za-z0-9_.+-]+", args.library_name):
        raise ValueError("--library-name contains unsupported characters")
    if len(set(args.targets)) != len(args.targets):
        raise ValueError("--targets must not contain duplicates")
    return Spec(args.name, args.package, args.version, args.source_url, args.source_tag,
                args.imported_target, args.library_name, args.stack, tuple(args.targets))


def create(spec: Spec, root: Path, dry_run: bool = False) -> int:
    generated = files(spec)
    dependency = root / spec.name
    workflow_path = root / ".github/workflows" / f"{spec.name}.yml"
    candidates = [dependency, workflow_path, *(root / path for path in generated)]
    present = sorted({path for path in candidates if path.exists()})
    if present:
        for path in present:
            print(f"{path.relative_to(root)}: refusing to overwrite existing path", file=sys.stderr)
        return 1
    for relative_path, (content, is_script) in generated.items():
        if dry_run:
            print(relative_path)
            continue
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        if is_script:
            executable(path)
        print(relative_path)
    if dry_run:
        print("Dry run; no files created.")
    else:
        print("Scaffold created; resolve all TC_DEPOT_SCAFFOLD_TODO markers before check can pass.")
    return 0


def parse_manifest(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {}
    parent: str | None = None
    child: str | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith(" "):
            match = re.fullmatch(r"([A-Za-z_]+):(?:\s*(.*))?", line)
            if not match:
                raise ValueError(f"invalid top-level syntax: {line}")
            key, value = match.groups()
            parent, child = key, None
            result[key] = {} if value in (None, "") else ([] if value == "[]" else value)
        elif line.startswith("  - "):
            if not isinstance(result.get(parent), list):
                result[parent] = []
            result[parent].append(line[4:].strip())
        elif line.startswith("  ") and not line.startswith("    "):
            match = re.fullmatch(r"  ([A-Za-z_]+):(?:\s*(.*))?", line)
            if not match or not isinstance(result.get(parent), dict):
                raise ValueError(f"invalid nested syntax: {line}")
            child, value = match.groups()
            result[parent][child] = [] if value in (None, "", "[]") else value
        elif line.startswith("    - ") and isinstance(result.get(parent), dict) and child:
            result[parent][child].append(line[6:].strip())
        else:
            raise ValueError(f"unsupported indentation: {line}")
    return result


def display(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def has_spdx(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="replace")
    return COPYRIGHT in text and LICENSE in text


def check(dependency_arg: str, root: Path) -> int:
    supplied = Path(dependency_arg)
    dependency = supplied.resolve() if supplied.is_absolute() else (root / supplied).resolve()
    name = dependency.name
    errors: list[str] = []

    def fail(path: Path, message: str) -> None:
        errors.append(f"{display(path, root)}: {message}")

    if not dependency.is_dir():
        fail(dependency, "dependency directory is missing")
        print("\n".join(errors), file=sys.stderr)
        return 1
    manifest_path = dependency / "manifest.yml"
    required = [dependency / "README.md", manifest_path, dependency / "CMakeLists.txt",
                dependency / "fetch.sh", dependency / "cmake", dependency / "scripts",
                dependency / "scripts/package-artifact.sh"]
    for path in required:
        if not path.exists():
            fail(path, "required path is missing")
    data: dict[str, Any] = {}
    if manifest_path.is_file():
        try:
            data = parse_manifest(manifest_path)
        except ValueError as error:
            fail(manifest_path, f"invalid manifest syntax: {error}")

    package, targets, artifact = "", [], {}
    if data:
        for field in ("name", "version", "release", "build_system", "stack", "source", "cmake", "artifact", "targets"):
            if field not in data:
                fail(manifest_path, f"missing required field {field}")
        version = data.get("version")
        if data.get("name") != name:
            fail(manifest_path, "name must match dependency directory")
        if not isinstance(version, str) or not version:
            fail(manifest_path, "version must be non-empty")
        if not isinstance(data.get("release"), str) or not data["release"].startswith(f"{name}-{version or ''}"):
            fail(manifest_path, "release must begin with name-version")
        if data.get("build_system") != "cmake":
            fail(manifest_path, "build_system must be cmake")
        if data.get("stack") not in KNOWN_STACKS:
            fail(manifest_path, "stack is unknown")
        source = data.get("source")
        if not isinstance(source, dict) or not all(source.get(key) for key in ("type", "url", "tag")):
            fail(manifest_path, "source requires type, url, and tag")
        cmake_data = data.get("cmake")
        if isinstance(cmake_data, dict):
            package = str(cmake_data.get("package", ""))
            imported = str(cmake_data.get("imported_target", ""))
            if not PACKAGE_RE.fullmatch(package):
                fail(manifest_path, "cmake.package is invalid")
            if not TARGET_RE.fullmatch(imported) or imported.split("::", 1)[0] != package:
                fail(manifest_path, "cmake.imported_target must match Package::Target")
        else:
            fail(manifest_path, "cmake requires package and imported_target")
        if isinstance(data.get("artifact"), dict):
            artifact = data["artifact"]
            for field in ("include", "libraries", "archives"):
                if not isinstance(artifact.get(field), list) or not artifact[field]:
                    fail(manifest_path, f"artifact.{field} must be a non-empty list")
        else:
            fail(manifest_path, "artifact requires include, libraries, and archives")
        if isinstance(data.get("targets"), list) and data["targets"]:
            targets = [str(target) for target in data["targets"]]
            for target in targets:
                if target not in TARGETS:
                    fail(manifest_path, f"unknown target {target}")
            if len(set(targets)) != len(targets):
                fail(manifest_path, "targets must not contain duplicates")
            expected_archives = {archive_name(name, target) for target in targets if target in TARGETS}
            if set(artifact.get("archives", [])) != expected_archives:
                fail(manifest_path, "artifact.archives must match declared targets")
        else:
            fail(manifest_path, "targets must be a non-empty list")

    workflow_path = root / ".github/workflows" / f"{name}.yml"
    if not workflow_path.exists():
        fail(workflow_path, "single dependency workflow is missing")
    for legacy in (root / ".github/workflows" / f"build-{name}.yml", root / ".github/workflows" / f"release-{name}.yml"):
        if legacy.exists():
            fail(legacy, "split build/release workflow is not allowed")
    modules = [dependency / "cmake" / f"AutoFetch{package}.cmake", dependency / "cmake" / f"Find{package}.cmake"] if package else []
    for path in modules:
        if not path.exists():
            fail(path, "required CMake module is missing")
    for path in [*(path for path in required if path.is_file()), workflow_path, *modules]:
        if path.is_file() and not has_spdx(path):
            fail(path, "missing valid SPDX copyright and MIT license header")

    for path in dependency.rglob("*"):
        if path.is_dir() and path.name in ("build", "dist", "local"):
            fail(path, "generated directory must not exist in a scaffold")
    for path in dependency.rglob("*"):
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            if PLACEHOLDER in text:
                fail(path, "contains unresolved scaffold placeholder")
            if path.suffix == ".sh":
                if not os.access(path, os.X_OK):
                    fail(path, "script is not executable")
                if not has_spdx(path):
                    fail(path, "missing valid SPDX copyright and MIT license header")
    if workflow_path.is_file() and PLACEHOLDER in workflow_path.read_text(encoding="utf-8", errors="replace"):
        fail(workflow_path, "contains unresolved scaffold placeholder")

    wrappers = sorted((dependency / "scripts").glob("build-*.sh")) if (dependency / "scripts").is_dir() else []
    expected_wrappers = {f"build-{target}.sh" for target in targets}
    for target in targets:
        wrapper_path = dependency / "scripts" / f"build-{target}.sh"
        if not wrapper_path.exists():
            fail(wrapper_path, "target has no matching build script")
    for path in wrappers:
        if path.name not in expected_wrappers:
            fail(path, "build script has no declared target")
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern, description in (
            (r"android-ndk-r\d+|ANDROID_NDK[^\n]*\d+\.\d+", "literal Android NDK version"),
            (r"\bANDROID_PLATFORM\b", "ANDROID_PLATFORM"),
            (r"\bCMAKE_MSVC_RUNTIME_LIBRARY\b", "CMAKE_MSVC_RUNTIME_LIBRARY"),
            (r"Visual Studio|CMAKE_GENERATOR[^\n]*Visual", "Visual Studio generator"),
            (r"(?:docker\.io|ghcr\.io|FROM\s+\S+:\S+|image:\s*\S+:\S+)", "Docker image tag"),
        ):
            if re.search(pattern, text, re.IGNORECASE):
                fail(path, f"wrapper must not define {description}")

    if any(target.startswith("windows-") for target in targets):
        cmake_path = dependency / "CMakeLists.txt"
        if cmake_path.is_file():
            text = cmake_path.read_text(encoding="utf-8", errors="replace")
            runtime = text.find("TotalCrossWindowsStaticRuntime.cmake")
            project = re.search(r"(?m)^\s*project\s*\(", text)
            if runtime < 0:
                fail(cmake_path, "Windows target requires TotalCrossWindowsStaticRuntime.cmake")
            elif project and runtime > project.start():
                fail(cmake_path, "Windows static runtime policy must precede project()")

    if errors:
        print("\n".join(sorted(set(errors))), file=sys.stderr)
        return 1
    print(f"Dependency structure check passed: {display(dependency, root)}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--root", type=Path, default=Path.cwd(), help="repository root (default: current directory)")
    commands = result.add_subparsers(dest="command", required=True)
    create_parser = commands.add_parser("create", help="create an intentionally incomplete dependency scaffold")
    create_parser.add_argument("--name", required=True)
    create_parser.add_argument("--package", required=True)
    create_parser.add_argument("--version", required=True)
    create_parser.add_argument("--source-url", required=True)
    create_parser.add_argument("--source-tag", required=True)
    create_parser.add_argument("--imported-target", required=True)
    create_parser.add_argument("--library-name", required=True)
    create_parser.add_argument("--stack", choices=sorted(KNOWN_STACKS), required=True)
    create_parser.add_argument("--targets", nargs="+", choices=target_names(), required=True)
    create_parser.add_argument("--dry-run", action="store_true", help="print generated paths without creating files")
    check_parser = commands.add_parser("check", help="validate one dependency scaffold")
    check_parser.add_argument("dependency", help="dependency name or absolute path")
    return result


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = args.root.resolve()
    if args.command == "create":
        try:
            return create(spec_from(args), root, args.dry_run)
        except ValueError as error:
            print(str(error), file=sys.stderr)
            return 2
    return check(args.dependency, root)


if __name__ == "__main__":
    raise SystemExit(main())
