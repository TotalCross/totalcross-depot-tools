# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Focused contract tests for scripts/native-build.py."""

from __future__ import annotations

import copy
import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "native-build.py"
SPEC = importlib.util.spec_from_file_location("native_build", MODULE_PATH)
assert SPEC and SPEC.loader
NATIVE_BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE_BUILD)


class NativeBuildConfigurationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = NATIVE_BUILD.load_config()

    def test_linux_images_share_one_platform_version(self) -> None:
        version = self.config["platforms"]["linux"]["image_version"]
        resolved = [
            NATIVE_BUILD.resolve(self.config, "zlib", target)["docker_image"]
            for target in ("linux-x86_64", "linux-armv7l", "linux-aarch64")
        ]
        self.assertEqual("v2.0.2", version)
        self.assertTrue(all(image.endswith(f":{version}") for image in resolved))
        self.assertEqual(3, len(set(resolved)))

    def test_android_api_default_and_minizip_override(self) -> None:
        self.assertEqual(23, NATIVE_BUILD.resolve(self.config, "zlib", "android-arm64")["android_api"])
        self.assertEqual(23, NATIVE_BUILD.resolve(self.config, "libpng", "android-arm64")["android_api"])
        self.assertEqual(24, NATIVE_BUILD.resolve(self.config, "minizip", "android-arm64")["android_api"])

    def test_windows_policy_is_central(self) -> None:
        resolved = NATIVE_BUILD.resolve(self.config, "zlib", "windows-x64")
        self.assertEqual("Visual Studio 17 2022", resolved["generator"])
        self.assertEqual("MultiThreaded", resolved["windows_expected_runtime"])
        self.assertEqual("cmake/TotalCrossWindowsStaticRuntime.cmake", resolved["windows_runtime_policy"])

    def test_unknown_target_fails_compactly(self) -> None:
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "unknown target missing-target"):
            NATIVE_BUILD.resolve(self.config, "zlib", "missing-target")

    def test_unsupported_library_target_pair_is_rejected(self) -> None:
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "does not publish windows-x64"):
            NATIVE_BUILD.resolve(self.config, "qrcode", "windows-x64")

    def test_dependency_cycle_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.config)
        invalid["libraries"]["zlib"]["dependencies"] = {"minizip": {"cmake_variable": "MINIZIP_DIR"}}
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "dependency cycle"):
            NATIVE_BUILD.validate_config(invalid)

    def test_duplicate_stack_member_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.config)
        invalid["stacks"]["others"]["libraries"].append("sqlite3")
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "contains duplicates"):
            NATIVE_BUILD.validate_config(invalid)

    def test_incomplete_target_override_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.config)
        invalid["libraries"]["zlib"]["target_overrides"] = {"android-arm64": {}}
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "is incomplete"):
            NATIVE_BUILD.validate_config(invalid)

    def test_target_override_cannot_embed_a_complete_image_tag(self) -> None:
        invalid = copy.deepcopy(self.config)
        invalid["libraries"]["zlib"]["target_overrides"] = {
            "linux-x86_64": {"image": "totalcross/linux-amd64:v2.0.2"}
        }
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "must not embed a tag"):
            NATIVE_BUILD.validate_config(invalid)

    def test_invalid_operation_is_rejected(self) -> None:
        with self.assertRaisesRegex(NATIVE_BUILD.NativeBuildError, "invalid operation publish"):
            NATIVE_BUILD.plan(self.config, "zlib", "publish")

    def test_apple_xcframework_policy_is_resolved(self) -> None:
        resolved = NATIVE_BUILD.resolve(self.config, "mbedtls", "ios-arm64")
        self.assertEqual(
            ["libmbedtls.a", "libmbedx509.a", "libmbedcrypto.a"],
            resolved["apple_xcframework"]["libraries"],
        )
        self.assertTrue(resolved["apple_xcframework"]["merge"])

    def test_graph_has_only_real_dependency_edges_in_order(self) -> None:
        graph = NATIVE_BUILD.graph(self.config, "graphics")
        order = graph["order"]
        self.assertLess(order.index("zlib"), order.index("minizip"))
        self.assertLess(order.index("zlib-ng"), order.index("minizip-ng"))
        self.assertLess(order.index("zlib-ng"), order.index("libpng"))
        self.assertLess(order.index("libpng"), order.index("skia"))
        self.assertNotIn({"from": "zlib", "to": "libjpeg"}, graph["edges"])

    def test_others_stack_and_library_plan_do_not_create_dependencies(self) -> None:
        self.assertIn("sqlite3", self.config["stacks"]["others"]["libraries"])
        self.assertIn("sljit", self.config["stacks"]["others"]["libraries"])
        self.assertEqual(["qrcode"], NATIVE_BUILD.plan(self.config, "qrcode", "build")["libraries"])


if __name__ == "__main__":
    unittest.main()
