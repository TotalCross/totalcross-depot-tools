#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Inspect, select, prepare, and verify native dependency releases.

The helper has no mutation outside ``prepare-metadata``. CI supplies GitHub
release and tag snapshots; tests use JSON fixtures so release decisions stay
deterministic without contacting GitHub.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
CHECKSUMS_PATH = Path("scripts/native-artifact-checksums.json")
TAG_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


class NativeReleaseError(ValueError):
    """A compact release-state error."""


def _read_indented_value(path: Path, section: str, key: str) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = next((index for index, line in enumerate(lines) if line == f"  {section}:"), None)
    if start is None:
        raise NativeReleaseError(f"{path} has no {section} dependency")
    for line in lines[start + 1 :]:
        if re.match(r"^  \S.*:$", line):
            break
        match = re.match(rf"^    {re.escape(key)}:\s*(\S.*?)\s*$", line)
        if match:
            return match.group(1)
    raise NativeReleaseError(f"{path} has no {key} for {section}")


def _read_top_level_value(path: Path, key: str) -> str:
    match = next(
        (
            match
            for line in path.read_text(encoding="utf-8").splitlines()
            if (match := re.match(rf"^{re.escape(key)}:\s*(\S.*?)\s*$", line))
        ),
        None,
    )
    if not match:
        raise NativeReleaseError(f"{path} has no {key} field")
    return match.group(1)


def _replace_scalar(path: Path, key: str, value: str) -> None:
    source = path.read_text(encoding="utf-8")
    updated, count = re.subn(rf"^{re.escape(key)}:\s*\S.*$", f"{key}: {value}", source, count=1, flags=re.MULTILINE)
    if count != 1:
        raise NativeReleaseError(f"{path} has no {key} field")
    path.write_text(updated, encoding="utf-8")


def _replace_dependency_release(path: Path, library: str, tag: str) -> None:
    source = path.read_text(encoding="utf-8")
    pattern = rf"(^  {re.escape(library)}:\n(?:    .*\n)*?    release: )[^\n]+$"
    updated, count = re.subn(pattern, rf"\g<1>{tag}", source, count=1, flags=re.MULTILINE)
    if count != 1:
        raise NativeReleaseError(f"{path} has no release pin for {library}")
    path.write_text(updated, encoding="utf-8")


def _insert_dependency(path: Path, library: str, version: str, tag: str) -> None:
    source = path.read_text(encoding="utf-8")
    entry = (
        f"  {library}:\n"
        f"    version: {version}\n"
        f"    release: {tag}\n"
        f"    path: {library}\n"
    )
    updated, count = re.subn(
        r"^(dependencies:[ \t]*\n)",
        rf"\g<1>{entry}",
        source,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise NativeReleaseError(f"{path} has no dependencies mapping")
    path.write_text(updated, encoding="utf-8")


def _manifest_path(root: Path, library: str) -> Path:
    path = root / library / "manifest.yml"
    if not path.is_file():
        raise NativeReleaseError(f"missing manifest for {library}: {path}")
    return path


def metadata(root: Path, library: str) -> dict[str, Any]:
    deps_path = root / "deps.yml"
    manifest_path = _manifest_path(root, library)
    manifest_version = _read_top_level_value(manifest_path, "version")
    manifest_release = _read_top_level_value(manifest_path, "release")
    deps_pinned = f"  {library}:" in deps_path.read_text(encoding="utf-8").splitlines()
    if deps_pinned:
        version = _read_indented_value(deps_path, library, "version")
        deps_release = _read_indented_value(deps_path, library, "release")
        if version != manifest_version:
            raise NativeReleaseError(
                f"{library} bundle version {version} does not match manifest version {manifest_version}"
            )
    else:
        version = manifest_version
        deps_release = manifest_release
    base_tag = f"{library}-{version}"
    if not deps_release.startswith(base_tag):
        raise NativeReleaseError(f"{library} release pin {deps_release} does not match source version {version}")
    return {
        "library": library,
        "version": version,
        "base_tag": base_tag,
        "deps_release": deps_release,
        "deps_pinned": deps_pinned,
        "manifest_release": manifest_release,
        "deps_path": str(deps_path),
        "manifest_path": str(manifest_path),
    }


def _load_json(path: Path | None, default: Any) -> Any:
    if path is None:
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise NativeReleaseError(f"cannot read fixture {path}: {error}") from error


def _remote_releases(repository: str) -> list[dict[str, Any]]:
    try:
        output = subprocess.check_output(
            ["gh", "api", "--paginate", "--slurp", f"repos/{repository}/releases?per_page=100"],
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise NativeReleaseError(f"unable to query GitHub releases: {error}") from error
    pages = json.loads(output)
    if not isinstance(pages, list) or not all(isinstance(page, list) for page in pages):
        raise NativeReleaseError("GitHub releases response has an unexpected shape")
    data = [item for page in pages for item in page]
    return [
        {
            "tag": item["tag_name"],
            "draft": item["draft"],
            "url": item.get("html_url", ""),
            "assets": [asset["name"] for asset in item.get("assets", [])],
        }
        for item in data
    ]


def _remote_tags(remote: str) -> list[str]:
    try:
        output = subprocess.check_output(["git", "ls-remote", "--tags", remote], text=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise NativeReleaseError(f"unable to query remote tags: {error}") from error
    return sorted({line.split("\t", 1)[1].removeprefix("refs/tags/").removesuffix("^{}") for line in output.splitlines() if "\trefs/tags/" in line})


def _matching_tags(base_tag: str, tags: Sequence[str]) -> list[str]:
    expression = re.compile(rf"^{re.escape(base_tag)}(?:-r[0-9]+)?$")
    return sorted(tag for tag in tags if expression.fullmatch(tag))


def next_force_tag(base_tag: str, tags: Sequence[str]) -> str:
    highest = 0
    for tag in _matching_tags(base_tag, tags):
        if tag == base_tag:
            highest = max(highest, 1)
        else:
            highest = max(highest, int(tag.rsplit("-r", 1)[1]))
    return base_tag if highest == 0 else f"{base_tag}-r{highest + 1}"


def inspect_release(info: dict[str, Any], tags: Sequence[str], releases: Sequence[dict[str, Any]], effective_tag: str | None = None) -> dict[str, Any]:
    tag = effective_tag or info["deps_release"]
    if not TAG_PATTERN.fullmatch(tag):
        raise NativeReleaseError(f"invalid effective release tag {tag}")
    release = next((item for item in releases if item.get("tag") == tag), None)
    tags_set = set(tags)
    result: dict[str, Any] = {**info, "effective_release_tag": tag, "tags": _matching_tags(info["base_tag"], tags)}
    if release and not release.get("draft", False):
        if (
            not info.get("deps_pinned", True)
            or info["deps_release"] != tag
            or info["manifest_release"] != tag
        ):
            return {**result, "status": "recovery-required", "reason": "metadata_mismatch", "release_url": release.get("url", "")}
        return {**result, "status": "existing-release", "release_url": release.get("url", ""), "assets": release.get("assets", [])}
    if release and release.get("draft", False):
        return {**result, "status": "recovery-required", "reason": "draft_release", "release_url": release.get("url", "")}
    if tag in tags_set:
        return {**result, "status": "recovery-required", "reason": "tag_without_release"}
    if (
        info.get("deps_pinned", True)
        and info["deps_release"] == tag
        and info["manifest_release"] == tag
        and tag != info["base_tag"]
    ):
        return {**result, "status": "recovery-required", "reason": "metadata_commit_without_tag"}
    return {**result, "status": "build-required", "release_url": ""}


def expected_assets(root: Path, library: str) -> list[str]:
    if library == "skia":
        return validate_skia_asset_contract(root)
    manifest = _manifest_path(root, library).read_text(encoding="utf-8").splitlines()
    archives: list[str] = []
    in_archives = False
    for line in manifest:
        if line == "  archives:":
            in_archives = True
            continue
        if in_archives and re.match(r"^  \S", line):
            break
        if in_archives:
            match = re.match(r"^    - (.+)$", line)
            if match:
                archives.append(match.group(1))
    if not archives:
        raise NativeReleaseError(f"{library} has no declared release archives")
    return archives


def validate_skia_asset_contract(root: Path) -> list[str]:
    artifacts_path = root / "skia" / "artifacts.json"
    manifest_path = root / "skia" / "manifest.yml"
    try:
        payload = json.loads(artifacts_path.read_text(encoding="utf-8"))
        assets = payload["release"]["assets"]
        machine_configs = payload["metadata"]["machine-build-configs"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise NativeReleaseError(f"invalid Skia artifact manifest: {error}") from error
    if not isinstance(assets, list) or not all(isinstance(asset, str) and asset for asset in assets):
        raise NativeReleaseError("Skia release assets must be non-empty strings")
    if len(assets) != len(set(assets)):
        raise NativeReleaseError("Skia release assets contain duplicate names")
    if not isinstance(machine_configs, dict) or not machine_configs:
        raise NativeReleaseError("Skia machine build configs must be a non-empty mapping")
    try:
        config_assets = {
            config["artifact_name"]
            for config in machine_configs.values()
            if isinstance(config, dict)
        }
    except (KeyError, TypeError) as error:
        raise NativeReleaseError(f"invalid Skia machine build config: {error}") from error
    if len(config_assets) != len(machine_configs):
        raise NativeReleaseError("Skia machine build configs must declare unique artifact names")
    missing_configs = sorted(config_assets - set(assets))
    if missing_configs:
        raise NativeReleaseError(
            "Skia release assets omit machine build configs: " + ", ".join(missing_configs)
        )
    try:
        diagnostics = next(
            match.group(1)
            for line in manifest_path.read_text(encoding="utf-8").splitlines()
            if (match := re.match(r"^  diagnostics:\s*(\S.*?)\s*$", line))
        )
    except (OSError, StopIteration) as error:
        raise NativeReleaseError("Skia manifest has no diagnostics release asset") from error
    if diagnostics not in assets:
        raise NativeReleaseError(f"Skia release assets omit diagnostics archive: {diagnostics}")
    if "SHA256SUMS" not in assets:
        raise NativeReleaseError("Skia release assets omit SHA256SUMS")
    return assets


def prepare_metadata(root: Path, library: str, tag: str) -> list[Path]:
    info = metadata(root, library)
    if not tag.startswith(info["base_tag"]) or not TAG_PATTERN.fullmatch(tag):
        raise NativeReleaseError(f"{tag} is not a valid {library} release tag")
    paths = [root / "deps.yml", _manifest_path(root, library)]
    if info["deps_pinned"]:
        _replace_dependency_release(paths[0], library, tag)
    else:
        _insert_dependency(paths[0], library, info["version"], tag)
    _replace_scalar(paths[1], "release", tag)
    if library == "skia":
        for relative in ("skia/manifest.json", "skia/artifacts.json"):
            path = root / relative
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["release"]["tag"] = tag
            if "defaults" in payload:
                payload["defaults"]["source"]["tag"] = tag
            path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
            paths.append(path)
        source = paths[1].read_text(encoding="utf-8")
        paths[1].write_text(re.sub(r"^(  tag: ).*$", rf"\g<1>{tag}", source, count=1, flags=re.MULTILINE), encoding="utf-8")
    return paths


def record_artifact_checksums(
    root: Path,
    repository: str,
    library: str,
    tag: str,
    patterns: Sequence[str],
) -> list[Path]:
    if not repository or "/" not in repository:
        raise NativeReleaseError("repository must use OWNER/REPO format")
    files = [path for pattern in patterns for path in root.glob(pattern) if path.is_file()]
    actual = {path.name: path for path in files}
    expected = set(expected_assets(root, library))
    if set(actual) != expected:
        missing = sorted(expected - set(actual))
        unexpected = sorted(set(actual) - expected)
        raise NativeReleaseError(
            "cannot record checksums; missing=%s unexpected=%s"
            % (",".join(missing) or "none", ",".join(unexpected) or "none")
        )
    digests = {
        name: hashlib.sha256(path.read_bytes()).hexdigest()
        for name, path in sorted(actual.items())
    }
    checksum_path = root / CHECKSUMS_PATH
    try:
        payload = json.loads(checksum_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        payload = {"schema": 1, "repositories": {}}
    if payload.get("schema") != 1 or not isinstance(payload.get("repositories"), dict):
        raise NativeReleaseError(f"invalid checksum manifest: {checksum_path}")
    payload["repositories"].setdefault(repository, {})[tag] = digests
    checksum_path.parent.mkdir(parents=True, exist_ok=True)
    checksum_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    paths = [checksum_path]

    if library == "skia":
        artifacts_path = root / "skia" / "artifacts.json"
        artifacts = json.loads(artifacts_path.read_text(encoding="utf-8"))
        for item in artifacts.get("artifacts", {}).values():
            item["sha256"] = digests[item["artifact_name"]]
        dev_bundle = artifacts.get("defaults", {}).get("dev_bundle", {})
        dev_bundle["sha256"] = digests[dev_bundle["artifact_name"]]
        for group in artifacts.get("metadata", {}).values():
            for item in group.values():
                item["sha256"] = digests[item["artifact_name"]]
        artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n", encoding="utf-8")
        paths.append(artifacts_path)
    return paths


def _emit(value: Any) -> None:
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--tags-file", type=Path)
    parser.add_argument("--releases-file", type=Path)
    commands = parser.add_subparsers(dest="command", required=True)
    inspect_command = commands.add_parser("inspect")
    inspect_command.add_argument("library")
    inspect_command.add_argument("--effective-tag")
    select_command = commands.add_parser("select-tag")
    select_command.add_argument("library")
    select_command.add_argument("--operation", required=True, choices=("release", "force-release"))
    prepare_command = commands.add_parser("prepare-metadata")
    prepare_command.add_argument("library")
    prepare_command.add_argument("--effective-tag", required=True)
    validate_command = commands.add_parser("validate-contract")
    validate_command.add_argument("library")
    verify_command = commands.add_parser("verify-assets")
    verify_command.add_argument("library")
    verify_command.add_argument("--paths", nargs="+", required=True)
    checksum_command = commands.add_parser("record-checksums")
    checksum_command.add_argument("library")
    checksum_command.add_argument("--effective-tag", required=True)
    checksum_command.add_argument("--paths", nargs="+", required=True)
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve()
        if args.tags_file:
            tags = _load_json(args.tags_file, [])
        elif args.command in ("prepare-metadata", "validate-contract", "verify-assets", "record-checksums"):
            tags = []
        else:
            tags = _remote_tags(args.remote)
        if args.releases_file:
            releases = _load_json(args.releases_file, [])
        elif args.command in ("prepare-metadata", "validate-contract", "verify-assets", "record-checksums"):
            releases = []
        else:
            if not args.repository:
                raise NativeReleaseError("repository is required when no releases fixture is supplied")
            releases = _remote_releases(args.repository)
        if not isinstance(tags, list) or not all(isinstance(tag, str) for tag in tags):
            raise NativeReleaseError("tags fixture must contain strings")
        if not isinstance(releases, list) or not all(isinstance(item, dict) for item in releases):
            raise NativeReleaseError("releases fixture must contain objects")
        if args.command == "inspect":
            _emit(inspect_release(metadata(root, args.library), tags, releases, args.effective_tag))
        elif args.command == "select-tag":
            info = metadata(root, args.library)
            if args.operation == "release":
                _emit(inspect_release(info, tags, releases))
            else:
                tag = next_force_tag(info["base_tag"], tags)
                _emit({**inspect_release(info, tags, releases, tag), "effective_release_tag": tag, "status": "build-required"})
        elif args.command == "prepare-metadata":
            _emit({"paths": [str(path.relative_to(root)) for path in prepare_metadata(root, args.library, args.effective_tag)], "effective_release_tag": args.effective_tag})
        elif args.command == "validate-contract":
            assets = expected_assets(root, args.library)
            _emit({"library": args.library, "assets": len(assets), "status": "valid"})
        elif args.command == "verify-assets":
            actual = {Path(path).name for raw in args.paths for path in root.glob(raw) if Path(path).is_file()}
            expected = set(expected_assets(root, args.library))
            result = {"expected": sorted(expected), "actual": sorted(actual), "missing": sorted(expected - actual), "unexpected": sorted(actual - expected)}
            _emit(result)
            if result["missing"] or result["unexpected"]:
                return 2
        else:
            if not args.repository:
                raise NativeReleaseError("repository is required to record checksums")
            paths = record_artifact_checksums(
                root, args.repository, args.library, args.effective_tag, args.paths
            )
            _emit({"paths": [str(path.relative_to(root)) for path in paths], "assets": len(expected_assets(root, args.library))})
        return 0
    except NativeReleaseError as error:
        print(f"native-release: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
