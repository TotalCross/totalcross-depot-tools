#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Adapter from the native dependency scaffold to central build policy."""

from __future__ import annotations

from dataclasses import dataclass
import importlib.util
from pathlib import Path
import sys


@dataclass(frozen=True)
class Target:
    """A published target and its archive-name suffix."""

    name: str
    archive_suffix: str


def central_configuration() -> dict[str, object]:
    """Load the resolver without changing its command-line public interface."""
    script = Path(__file__).resolve().parents[1] / "scripts" / "native-build.py"
    spec = importlib.util.spec_from_file_location("native_build_for_scaffold", script)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load scripts/native-build.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module.load_config()


def configured_targets() -> tuple[Target, ...]:
    config = central_configuration()
    targets = config["targets"]
    return tuple(
        Target(
            name,
            f"{target.get('artifact_platform', target['platform'])}-{target['arch']}",
        )
        for name, target in targets.items()
    )


CONFIGURATION = central_configuration()
_TARGETS = configured_targets()

TARGETS = {target.name: target for target in _TARGETS}
KNOWN_STACKS = frozenset(CONFIGURATION["stacks"])


def target_names() -> tuple[str, ...]:
    """Return supported target names in deterministic display order."""

    return tuple(target.name for target in _TARGETS)


def archive_name(dependency: str, target: str) -> str:
    """Return the canonical archive filename for one dependency target."""

    return f"{dependency}-{TARGETS[target].archive_suffix}.tar.gz"
