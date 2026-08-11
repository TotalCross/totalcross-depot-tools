#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

"""Focused tests for generate-build-config.py."""

from __future__ import annotations

import hashlib
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("generate-build-config.py")

BOOLEAN_NAMES = (
    "skia_enable_gpu",
    "skia_use_gl",
    "skia_use_egl",
    "skia_use_metal",
    "skia_use_vulkan",
    "skia_use_opencl",
    "skia_use_webgl",
    "skia_use_angle",
    "skia_use_dawn",
    "skia_use_direct3d",
    "skia_use_vma",
    "skia_use_x11",
    "skia_use_fonthost_mac",
    "skia_use_freetype",
    "skia_use_system_freetype2",
    "skia_use_fontconfig",
    "skia_enable_fontmgr_fontconfig",
    "skia_enable_fontmgr_android",
    "skia_enable_fontmgr_win",
    "skia_enable_fontmgr_win_gdi",
    "skia_use_harfbuzz",
    "skia_use_system_harfbuzz",
    "skia_use_expat",
    "skia_use_system_expat",
    "skia_use_icu",
    "skia_use_system_icu",
    "skia_use_zlib",
    "skia_use_system_zlib",
    "skia_use_libpng_decode",
    "skia_use_libpng_encode",
    "skia_use_system_libpng",
)


def effective_args(**overrides: str) -> str:
    values = {name: "false" for name in BOOLEAN_NAMES}
    values.update(
        {
            "target_os": '"mac"',
            "target_cpu": '"arm64"',
            "skia_gl_standard": '"gl"',
            "ndk_api": "23",
        }
    )
    values.update(overrides)
    return "\n".join(f"{name} = {value}" for name, value in sorted(values.items())) + "\n"


class GenerateBuildConfigTests(unittest.TestCase):
    def run_generator(
        self,
        gn_args: str,
        *,
        repository_zlib: str = "false",
        repository_libpng: str = "false",
    ) -> tuple[subprocess.CompletedProcess[str], pathlib.Path, pathlib.Path]:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = pathlib.Path(temporary.name)
        args_path = root / "gn-args.txt"
        library_path = root / "libskia.a"
        output_path = root / "SkiaBuildConfig.cmake"
        args_path.write_text(gn_args, encoding="utf-8")
        library_path.write_bytes(b"deterministic-skia-archive")
        result = subprocess.run(
            [
                str(SCRIPT),
                "--gn-args-file",
                str(args_path),
                "--library",
                str(library_path),
                "--platform",
                "macos",
                "--architecture",
                "arm64",
                "--revision",
                "158dc9d7",
                "--repository-zlib",
                repository_zlib,
                "--repository-libpng",
                repository_libpng,
                "--output",
                str(output_path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        return result, output_path, library_path

    def test_emits_deterministic_sha_bound_metadata(self) -> None:
        result, output, library = self.run_generator(
            effective_args(
                skia_enable_gpu="true",
                skia_use_gl="true",
                skia_use_metal="true",
                skia_use_system_zlib="true",
                skia_use_system_libpng="true",
            ),
            repository_zlib="true",
            repository_libpng="true",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        first = output.read_bytes()
        expected_sha = hashlib.sha256(library.read_bytes()).hexdigest()
        self.assertIn(b"set(SKIA_BUILD_CONFIG_VERSION 1)", first)
        self.assertIn(f'set(SKIA_BUILD_LIBRARY_SHA256 "{expected_sha}")'.encode(), first)
        self.assertIn(b"set(SKIA_BUILD_USE_METAL ON)", first)
        self.assertIn(b"set(SKIA_BUILD_USE_REPOSITORY_ZLIB ON)", first)
        self.assertIn(b"set(SKIA_BUILD_USE_REPOSITORY_LIBPNG ON)", first)

        result, output, _ = self.run_generator(
            effective_args(
                skia_enable_gpu="true",
                skia_use_gl="true",
                skia_use_metal="true",
                skia_use_system_zlib="true",
                skia_use_system_libpng="true",
            ),
            repository_zlib="true",
            repository_libpng="true",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_bytes(), first)

    def test_backend_change_changes_metadata(self) -> None:
        enabled, enabled_output, _ = self.run_generator(effective_args(skia_use_metal="true"))
        self.assertEqual(enabled.returncode, 0, enabled.stderr)
        enabled_content = enabled_output.read_text(encoding="utf-8")

        disabled, disabled_output, _ = self.run_generator(effective_args(skia_use_metal="false"))
        self.assertEqual(disabled.returncode, 0, disabled.stderr)
        disabled_content = disabled_output.read_text(encoding="utf-8")

        self.assertNotEqual(enabled_content, disabled_content)
        self.assertIn("set(SKIA_BUILD_USE_METAL ON)", enabled_content)
        self.assertIn("set(SKIA_BUILD_USE_METAL OFF)", disabled_content)

    def test_missing_required_effective_value_fails(self) -> None:
        result, output, _ = self.run_generator(effective_args().replace("skia_use_vulkan = false\n", ""))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())
        self.assertIn("missing required value skia_use_vulkan", result.stderr)

    def test_missing_inactive_target_local_value_is_classified_off(self) -> None:
        args = effective_args().replace("skia_use_system_freetype2 = false\n", "")
        args = args.replace("skia_use_system_harfbuzz = false\n", "")
        args = args.replace("skia_use_system_expat = false\n", "")
        args = args.replace("skia_use_system_icu = false\n", "")
        result, output, _ = self.run_generator(args)
        self.assertEqual(result.returncode, 0, result.stderr)
        content = output.read_text(encoding="utf-8")
        self.assertIn("set(SKIA_BUILD_USE_SYSTEM_FREETYPE2 OFF)", content)
        self.assertIn("set(SKIA_BUILD_USE_SYSTEM_HARFBUZZ OFF)", content)
        self.assertIn("set(SKIA_BUILD_USE_SYSTEM_EXPAT OFF)", content)
        self.assertIn("set(SKIA_BUILD_USE_SYSTEM_ICU OFF)", content)

    def test_repository_selection_must_match_effective_configuration(self) -> None:
        result, output, _ = self.run_generator(
            effective_args(skia_use_system_libpng="true"),
            repository_zlib="false",
            repository_libpng="false",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())
        self.assertIn("repository libpng selection does not match", result.stderr)


if __name__ == "__main__":
    unittest.main()
