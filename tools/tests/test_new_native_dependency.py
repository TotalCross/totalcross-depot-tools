#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Lifecycle tests for tools/new-native-dependency.py."""

from __future__ import annotations

import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOL = REPOSITORY_ROOT / "tools" / "new-native-dependency.py"


class NativeDependencyToolTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_tool(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(TOOL), "--root", str(self.root), *arguments],
            check=False,
            text=True,
            capture_output=True,
        )

    def create(self, *targets: str) -> subprocess.CompletedProcess[str]:
        return self.run_tool(
            "create",
            "--name", "example",
            "--package", "Example",
            "--version", "1.2.3",
            "--source-url", "https://github.com/example/example.git",
            "--source-tag", "v1.2.3",
            "--imported-target", "Example::Example",
            "--library-name", "example",
            "--stack", "others",
            "--targets", *targets,
        )

    @property
    def dependency(self) -> Path:
        return self.root / "example"

    @property
    def workflow(self) -> Path:
        return self.root / ".github" / "workflows" / "example.yml"

    def complete_placeholders(self) -> None:
        for path in [*self.dependency.rglob("*"), self.workflow]:
            if path.is_file():
                path.write_text(
                    path.read_text(encoding="utf-8").replace(
                        "TC_DEPOT_SCAFFOLD_TODO", "completed"
                    ),
                    encoding="utf-8",
                )

    def create_and_complete(self, *targets: str) -> None:
        result = self.create(*targets)
        self.assertEqual(0, result.returncode, result.stderr)
        self.complete_placeholders()

    def test_create_generates_requested_structure_only(self) -> None:
        result = self.create("linux-x86_64", "windows-x64")

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertTrue((self.dependency / "README.md").is_file())
        self.assertTrue((self.dependency / "manifest.yml").is_file())
        self.assertTrue((self.dependency / "CMakeLists.txt").is_file())
        self.assertTrue((self.dependency / "cmake" / "AutoFetchExample.cmake").is_file())
        self.assertTrue((self.dependency / "cmake" / "FindExample.cmake").is_file())
        self.assertTrue((self.dependency / "scripts" / "build-linux-x86_64.sh").is_file())
        self.assertTrue((self.dependency / "scripts" / "build-windows-x64.sh").is_file())
        self.assertFalse((self.dependency / "scripts" / "build-android-arm64.sh").exists())
        self.assertTrue(self.workflow.is_file())

    def test_generated_scripts_are_executable(self) -> None:
        result = self.create("linux-x86_64")

        self.assertEqual(0, result.returncode, result.stderr)
        for script in (
            self.dependency / "fetch.sh",
            self.dependency / "scripts" / "package-artifact.sh",
            self.dependency / "scripts" / "build-linux-x86_64.sh",
        ):
            self.assertTrue(script.stat().st_mode & stat.S_IXUSR, script)

    def test_create_refuses_existing_dependency(self) -> None:
        self.assertEqual(0, self.create("linux-x86_64").returncode)
        result = self.create("linux-x86_64")

        self.assertEqual(1, result.returncode)
        self.assertIn("refusing to overwrite", result.stderr)

    def test_create_rejects_invalid_name(self) -> None:
        result = self.run_tool(
            "create", "--name", "Example", "--package", "Example",
            "--version", "1.2.3", "--source-url", "https://example.invalid/a.git",
            "--source-tag", "v1", "--imported-target", "Example::Example",
            "--library-name", "example", "--stack", "others",
            "--targets", "linux-x86_64",
        )

        self.assertEqual(2, result.returncode)
        self.assertIn("--name", result.stderr)

    def test_create_rejects_invalid_package_and_imported_target(self) -> None:
        result = self.run_tool(
            "create", "--name", "example", "--package", "Example-Pkg",
            "--version", "1.2.3", "--source-url", "https://example.invalid/a.git",
            "--source-tag", "v1", "--imported-target", "Example-Pkg::Example",
            "--library-name", "example", "--stack", "others",
            "--targets", "linux-x86_64",
        )
        self.assertEqual(2, result.returncode)
        self.assertIn("--package", result.stderr)

        result = self.run_tool(
            "create", "--name", "example", "--package", "Example",
            "--version", "1.2.3", "--source-url", "https://example.invalid/a.git",
            "--source-tag", "v1", "--imported-target", "Wrong::Example",
            "--library-name", "example", "--stack", "others",
            "--targets", "linux-x86_64",
        )
        self.assertEqual(2, result.returncode)
        self.assertIn("--imported-target", result.stderr)

    def test_create_rejects_unknown_target(self) -> None:
        result = self.run_tool(
            "create", "--name", "example", "--package", "Example",
            "--version", "1.2.3", "--source-url", "https://example.invalid/a.git",
            "--source-tag", "v1", "--imported-target", "Example::Example",
            "--library-name", "example", "--stack", "others",
            "--targets", "unknown-target",
        )

        self.assertEqual(2, result.returncode)
        self.assertIn("unknown-target", result.stderr)

    def test_check_fails_for_placeholders_with_actionable_message(self) -> None:
        self.assertEqual(0, self.create("linux-x86_64").returncode)
        result = self.run_tool("check", "example")

        self.assertEqual(1, result.returncode)
        self.assertIn("manifest.yml: contains unresolved scaffold placeholder", result.stderr)

    def test_check_fails_when_required_file_is_missing(self) -> None:
        self.create_and_complete("linux-x86_64")
        (self.dependency / "README.md").unlink()

        result = self.run_tool("check", "example")

        self.assertEqual(1, result.returncode)
        self.assertIn("README.md: required path is missing", result.stderr)

    def test_check_fails_when_script_is_not_executable(self) -> None:
        self.create_and_complete("linux-x86_64")
        script = self.dependency / "fetch.sh"
        script.chmod(script.stat().st_mode & ~stat.S_IXUSR)

        result = self.run_tool("check", "example")

        self.assertEqual(1, result.returncode)
        self.assertIn("fetch.sh: script is not executable", result.stderr)

    def test_check_fails_when_manifest_and_scripts_diverge(self) -> None:
        self.create_and_complete("linux-x86_64")
        extra = self.dependency / "scripts" / "build-windows-x64.sh"
        extra.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
        os.chmod(extra, 0o755)

        result = self.run_tool("check", "example")

        self.assertEqual(1, result.returncode)
        self.assertIn("build-windows-x64.sh: build script has no declared target", result.stderr)

    def test_check_rejects_global_policy_in_wrapper(self) -> None:
        self.create_and_complete("windows-x64")
        wrapper = self.dependency / "scripts" / "build-windows-x64.sh"
        wrapper.write_text(
            wrapper.read_text(encoding="utf-8") + "\nset(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)\n",
            encoding="utf-8",
        )

        result = self.run_tool("check", "example")

        self.assertEqual(1, result.returncode)
        self.assertIn("wrapper must not define CMAKE_MSVC_RUNTIME_LIBRARY", result.stderr)

    def test_check_succeeds_after_placeholders_are_resolved_and_is_idempotent(self) -> None:
        self.create_and_complete("linux-x86_64", "windows-x64", "android-arm64")

        first = self.run_tool("check", "example")
        second = self.run_tool("check", str(self.dependency))

        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertIn("Dependency structure check passed", first.stdout)


if __name__ == "__main__":
    unittest.main()
