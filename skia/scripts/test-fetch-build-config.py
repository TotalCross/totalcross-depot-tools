#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

"""Focused paired-install tests for fetch.sh and SkiaBuildConfig.cmake."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import unittest


SKIA_ROOT = pathlib.Path(__file__).resolve().parents[1]
FETCH = SKIA_ROOT / "fetch.sh"


def build_config(
    library: bytes,
    *,
    version: int = 1,
    platform: str = "macos",
    architecture: str = "arm64",
    sha256: str | None = None,
) -> str:
    digest = sha256 or hashlib.sha256(library).hexdigest()
    return "\n".join(
        [
            "# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.",
            "# SPDX-License-Identifier: MIT",
            f"set(SKIA_BUILD_CONFIG_VERSION {version})",
            f'set(SKIA_BUILD_PLATFORM "{platform}")',
            f'set(SKIA_BUILD_ARCHITECTURE "{architecture}")',
            f'set(SKIA_BUILD_LIBRARY_SHA256 "{digest}")',
            "",
        ]
    )


class FetchBuildConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.source_library = self.root / "source-libskia.a"
        self.source_config = self.root / "source-SkiaBuildConfig.cmake"
        self.target_library = self.root / "install" / "libskia.a"
        self.target_config = self.root / "install" / "SkiaBuildConfig.cmake"
        self.manifest = self.root / "artifacts.json"

    def write_manifest(self) -> None:
        library_target = os.path.relpath(self.target_library, SKIA_ROOT)
        config_target = os.path.relpath(self.target_config, SKIA_ROOT)
        self.manifest.write_text(
            json.dumps(
                {
                    "artifacts": {
                        "macos-arm64": {
                            "artifact_name": "libskia-macos-arm64.a",
                            "target_path": library_target,
                        }
                    },
                    "defaults": {"source": {}, "dev_bundle": {}},
                    "metadata": {
                        "machine-build-configs": {
                            "macos-arm64": {
                                "artifact_name": "SkiaBuildConfig-macos-arm64.cmake",
                                "target_path": config_target,
                            }
                        }
                    },
                }
            ),
            encoding="utf-8",
        )

    def run_fetch(self, include_config: bool = True) -> subprocess.CompletedProcess[str]:
        command = [
            str(FETCH),
            "--platform",
            "macos",
            "--arch",
            "arm64",
            "--manifest",
            str(self.manifest),
            "--source",
            str(self.source_library),
        ]
        if include_config:
            command.extend(["--build-config", str(self.source_config)])
        return subprocess.run(command, check=False, capture_output=True, text=True)

    def test_installs_validated_pair_without_dev_bundle(self) -> None:
        library = b"new-skia-library"
        self.source_library.write_bytes(library)
        self.source_config.write_text(build_config(library), encoding="utf-8")
        self.write_manifest()

        result = self.run_fetch()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target_library.read_bytes(), library)
        self.assertEqual(self.target_config.read_text(encoding="utf-8"), build_config(library))

    def test_source_override_without_metadata_uses_legacy_path(self) -> None:
        library = b"source-without-contract"
        self.source_library.write_bytes(library)
        self.write_manifest()

        result = self.run_fetch(include_config=False)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("legacy Skia artifact without machine build metadata", result.stderr)
        self.assertEqual(self.target_library.read_bytes(), library)
        self.assertFalse(self.target_config.exists())

    def test_invalid_new_pair_preserves_installed_pair(self) -> None:
        old_library = b"old-valid-library"
        old_config = build_config(old_library)
        self.target_library.parent.mkdir(parents=True)
        self.target_library.write_bytes(old_library)
        self.target_config.write_text(old_config, encoding="utf-8")

        new_library = b"new-invalid-library"
        self.source_library.write_bytes(new_library)
        self.source_config.write_text(build_config(new_library, sha256="0" * 64), encoding="utf-8")
        self.write_manifest()

        result = self.run_fetch()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("library SHA-256 mismatch", result.stderr)
        self.assertEqual(self.target_library.read_bytes(), old_library)
        self.assertEqual(self.target_config.read_text(encoding="utf-8"), old_config)

    def test_unknown_metadata_version_fails(self) -> None:
        library = b"unsupported-contract"
        self.source_library.write_bytes(library)
        self.source_config.write_text(build_config(library, version=2), encoding="utf-8")
        self.write_manifest()

        result = self.run_fetch()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported Skia build-config version 2", result.stderr)
        self.assertFalse(self.target_library.exists())


if __name__ == "__main__":
    unittest.main()
