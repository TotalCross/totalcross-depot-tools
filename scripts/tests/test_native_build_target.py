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
        self.assertIn("gn_image: totalcross/skia-linux-amd64:v2.0.4", workflow)
        self.assertIn("gn_docker_platform: linux/amd64", workflow)
        self.assertIn("--platform ${{ matrix.gn_docker_platform }}", workflow)
        self.assertIn("-t ${{ matrix.gn_image }}", workflow)

    def test_skia_linux_images_provide_gles2_headers(self) -> None:
        for image in ("skia-linux-amd64", "linux-arm32v7"):
            dockerfile = (ROOT / "docker" / image / "Dockerfile").read_text(encoding="utf-8")
            self.assertIn("libgles2-mesa-dev", dockerfile)

    def test_skia_ccache_uses_complete_snapshots_and_partial_fallbacks(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "build-skia.yml").read_text(encoding="utf-8")
        self.assertEqual(5, workflow.count("uses: actions/cache/restore@v5"))
        self.assertEqual(10, workflow.count("uses: actions/cache/save@v5"))
        self.assertNotIn("key: skia-ccache-${{", workflow)
        self.assertIn(
            "key: skia-ccache-v1-${{ runner.os }}-windows-${{ matrix.arch }}-complete-${{ github.sha }}",
            workflow,
        )
        self.assertIn(
            "skia-ccache-v1-${{ runner.os }}-windows-${{ matrix.arch }}-complete-\n"
            "            skia-ccache-v1-${{ runner.os }}-windows-${{ matrix.arch }}-partial-",
            workflow,
        )
        windows_build = workflow.split("build-windows:", 1)[1].split("package-release-assets:", 1)[0]
        self.assertIn("SKIA_SKIP_DEPS_SYNC: 1", windows_build)
        self.assertIn("${{ github.run_id }}-${{ github.run_attempt }}", workflow)

    def test_skia_prepares_platform_source_archives_before_native_depot_tools(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "build-skia.yml").read_text(encoding="utf-8")
        fetch_source = (ROOT / "skia" / "scripts" / "fetch-source.sh").read_text(encoding="utf-8")
        windows_preparation = workflow.split("prepare-skia-sources-windows:", 1)[1].split(
            "prepare-skia-sources-macos:", 1
        )[0]
        self.assertIn("prepare-skia-sources-linux:", workflow)
        self.assertIn("prepare-skia-sources-windows:", workflow)
        self.assertIn("prepare-skia-sources-macos:", workflow)
        self.assertEqual(3, workflow.count("git hash-object --stdin"))
        self.assertIn("tar --dereference", windows_preparation)
        self.assertIn("SKIA_SOURCE_ARCHIVE_FORMAT=3", fetch_source)
        self.assertIn("needs: prepare-skia-sources-windows", workflow)
        self.assertIn("needs: prepare-skia-sources-macos", workflow)
        self.assertIn("key: ${{ needs.prepare-skia-sources-windows.outputs.cache-key }}", workflow)
        self.assertIn("key: ${{ needs.prepare-skia-sources-macos.outputs.cache-key }}", workflow)
        self.assertIn("target: macos-arm64", workflow)
        self.assertIn("target: ios-arm64", workflow)
        self.assertIn("target: ios-simulator-arm64", workflow)
        apple_build = workflow.split("build-apple:", 1)[1].split("package-apple-artifacts:", 1)[0]
        self.assertIn("SKIA_SKIP_DEPS_SYNC: 1", apple_build)
        self.assertIn("package-apple-artifacts:", workflow)
        self.assertIn("- package-apple-artifacts", workflow)

    def test_skia_windows_sdk_compat_uses_links_instead_of_copying(self) -> None:
        common = ROOT / "skia" / "scripts" / "common.sh"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "sdk"
            compat = root / "compat"
            for path in ("Include", "Lib", "UnionMetadata", "References", "bin/10.0.1"):
                (source / path).mkdir(parents=True)
            (source / "Include" / "windows.h").write_text("header", encoding="utf-8")
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; create_windows_sdk_compat "$2" "$3"; '
                    'test -L "$3/Include"; test -L "$3/Lib"; test -L "$3/bin/10.0.1"; '
                    'test -f "$3/bin/SetEnv.cmd"; test "$(cat "$3/Include/windows.h")" = header',
                    "bash",
                    str(common),
                    str(source),
                    str(compat),
                ],
                check=True,
                cwd=ROOT,
            )
        common_source = common.read_text(encoding="utf-8")
        compat_function = common_source.split("create_windows_sdk_compat()", 1)[1].split(
            "prepare_windows_toolchain_compat()", 1
        )[0]
        self.assertNotIn("cp -R", compat_function)

    def test_composite_action_delegates_to_the_low_level_executor(self) -> None:
        action = (ROOT / ".github" / "actions" / "build-native-library" / "action.yml").read_text()
        self.assertIn("scripts/build-cmake-multi.sh", action)
        self.assertNotIn("build_command=$(cat", action)


if __name__ == "__main__":
    unittest.main()
