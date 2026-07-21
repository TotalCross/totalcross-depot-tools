# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Focused tests for the shared native target executor contract."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXECUTOR = ROOT / "scripts" / "build-native-target.sh"
FETCHER = ROOT / "scripts" / "fetch-native-dependencies.sh"


def dry_run(library: str, target: str, *options: str) -> dict[str, object]:
    with tempfile.TemporaryDirectory() as directory:
        completed = subprocess.run(
            [str(EXECUTOR), library, target, "--build-dir", directory, "--dry-run", *options],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
    return json.loads(completed.stdout)


def cmake_args(result: dict[str, object]) -> str:
    command = result["command"]
    return command[command.index("--cmake-args") + 1]


class NativeBuildTargetTests(unittest.TestCase):
    def test_dependency_and_apple_arguments_are_resolved(self) -> None:
        result = dry_run("minizip", "macos-arm64")
        arguments = cmake_args(result)
        self.assertIn(f"-DZLIB_DIR={ROOT}/zlib/local/macos/arm64", arguments)
        self.assertIn("-DCMAKE_OSX_ARCHITECTURES=arm64", arguments)

    def test_linux_container_dependencies_use_the_mounted_workspace_path(self) -> None:
        result = dry_run("minizip", "linux-x86_64")
        arguments = cmake_args(result)
        self.assertIn("-DZLIB_DIR=/sources/zlib/local/linux/x86_64", arguments)

    def test_tested_library_arguments_are_preserved(self) -> None:
        result = dry_run("sljit", "macos-arm64")
        command = result["command"]
        self.assertIn("-DBUILD_TESTING=ON", cmake_args(result))
        self.assertEqual("true", command[command.index("--run-tests") + 1])

    def test_android_override_and_dependency_override_are_resolved_without_an_ndk(self) -> None:
        result = dry_run("minizip", "android-arm64", "--dependency-dir", "zlib=/tmp/zlib")
        arguments = cmake_args(result)
        self.assertIn("-DANDROID_PLATFORM=android-24", arguments)
        self.assertIn("-DZLIB_DIR=/tmp/zlib", arguments)

    def test_all_platform_dependency_and_windows_policy_are_resolved(self) -> None:
        libpng = cmake_args(dry_run("libpng", "macos-arm64"))
        windows = cmake_args(dry_run("zlib", "windows-x64"))
        self.assertIn(f"-DZLIB_DIR={ROOT}/zlib-ng/local/macos/arm64", libpng)
        self.assertIn("-A", windows)
        self.assertIn("x64", windows)
        self.assertIn("-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded", windows)

    def test_windows_python_output_is_normalized_before_shell_resolution(self) -> None:
        executor = EXECUTOR.read_text(encoding="utf-8")
        fetcher = FETCHER.read_text(encoding="utf-8")
        self.assertIn('key="${key%$\'\\r\'}"', executor)
        self.assertIn('dependency="${dependency%$\'\\r\'}"', executor)
        self.assertIn('dependency_name="${dependency_name%$\'\\r\'}"', fetcher)

    def test_skia_armv7_generates_gn_in_an_amd64_container(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "build-skia.yml").read_text(encoding="utf-8")
        self.assertIn("gn_image: totalcross/skia-linux-amd64:v2.0.3", workflow)
        self.assertIn("gn_docker_platform: linux/amd64", workflow)
        self.assertIn("--platform ${{ matrix.gn_docker_platform }}", workflow)
        self.assertIn("-t ${{ matrix.gn_image }}", workflow)

    def test_composite_action_delegates_to_the_low_level_executor(self) -> None:
        action = (ROOT / ".github" / "actions" / "build-native-library" / "action.yml").read_text()
        self.assertIn("scripts/build-cmake-multi.sh", action)
        self.assertNotIn("build_command=$(cat", action)


if __name__ == "__main__":
    unittest.main()
