#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Temporary target adapter for the native dependency scaffold.

Replace this module with an adapter to config/native-builds.yml when that
configuration becomes the repository source of truth. Keep the public helpers so
the scaffold command line and structural validator do not need to change.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Target:
    """A published target and its archive-name suffix."""

    name: str
    archive_suffix: str


_TARGETS = (
    Target("android-arm64", "android-arm64-v8a"),
    Target("ios-arm64", "ios-arm64"),
    Target("ios-simulator-arm64", "ios-simulator-arm64"),
    Target("linux-aarch64", "linux-aarch64"),
    Target("linux-armv7l", "linux-armv7l"),
    Target("linux-x86_64", "linux-x86_64"),
    Target("macos-arm64", "macos-arm64"),
    Target("windows-arm64", "windows-arm64"),
    Target("windows-x64", "windows-x64"),
    Target("windows-x86", "windows-x86"),
)

TARGETS = {target.name: target for target in _TARGETS}
KNOWN_STACKS = frozenset(("graphics", "others"))


def target_names() -> tuple[str, ...]:
    """Return supported target names in deterministic display order."""

    return tuple(target.name for target in _TARGETS)


def archive_name(dependency: str, target: str) -> str:
    """Return the canonical archive filename for one dependency target."""

    return f"{dependency}-{TARGETS[target].archive_suffix}.tar.gz"
