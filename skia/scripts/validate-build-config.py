#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

"""Validate a SkiaBuildConfig.cmake and its bound static library."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import sys


SUPPORTED_VERSION = "1"
SET_RE = re.compile(
    r'^set\(([A-Za-z_][A-Za-z0-9_]*)\s+(?:"([A-Za-z0-9_.:+/-]*)"|([^\s()]+))\)$'
)


def read_fields(path: pathlib.Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = SET_RE.fullmatch(line)
        if not match:
            raise ValueError(f"unsupported statement in {path.name}: {line}")
        name, quoted, unquoted = match.groups()
        if name in fields:
            raise ValueError(f"duplicate metadata field {name}")
        fields[name] = quoted if quoted is not None else unquoted
    return fields


def require(fields: dict[str, str], name: str) -> str:
    value = fields.get(name)
    if value is None or value == "":
        raise ValueError(f"metadata is missing required field {name}")
    return value


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate(args: argparse.Namespace) -> None:
    fields = read_fields(args.build_config)
    version = require(fields, "SKIA_BUILD_CONFIG_VERSION")
    if version != SUPPORTED_VERSION:
        raise ValueError(
            f"unsupported Skia build-config version {version}; expected {SUPPORTED_VERSION}"
        )

    metadata_platform = require(fields, "SKIA_BUILD_PLATFORM")
    if metadata_platform != args.platform:
        raise ValueError(
            f"Skia build-config platform mismatch: expected {args.platform}, got {metadata_platform}"
        )

    metadata_arch = require(fields, "SKIA_BUILD_ARCHITECTURE")
    if metadata_arch != args.architecture:
        raise ValueError(
            f"Skia build-config architecture mismatch: expected {args.architecture}, got {metadata_arch}"
        )

    expected_sha = require(fields, "SKIA_BUILD_LIBRARY_SHA256")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        raise ValueError("SKIA_BUILD_LIBRARY_SHA256 must be 64 lowercase hexadecimal characters")
    actual_sha = sha256(args.library)
    if actual_sha != expected_sha:
        raise ValueError(
            f"Skia library SHA-256 mismatch: metadata has {expected_sha}, library has {actual_sha}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-config", type=pathlib.Path, required=True)
    parser.add_argument("--library", type=pathlib.Path, required=True)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--architecture", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate(args)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
