#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

"""Configure-time integrity and compatibility tests for FindSkia.cmake."""

from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest


MODULE_DIR = pathlib.Path(__file__).resolve().parents[1]

BOOLEAN_FIELDS = (
    "SKIA_BUILD_ENABLE_GPU",
    "SKIA_BUILD_USE_GL",
    "SKIA_BUILD_USE_EGL",
    "SKIA_BUILD_USE_METAL",
    "SKIA_BUILD_USE_VULKAN",
    "SKIA_BUILD_USE_OPENCL",
    "SKIA_BUILD_USE_WEBGL",
    "SKIA_BUILD_USE_ANGLE",
    "SKIA_BUILD_USE_DAWN",
    "SKIA_BUILD_USE_DIRECT3D",
    "SKIA_BUILD_USE_VMA",
    "SKIA_BUILD_USE_X11",
    "SKIA_BUILD_USE_FONTHOST_MAC",
    "SKIA_BUILD_USE_FREETYPE",
    "SKIA_BUILD_USE_SYSTEM_FREETYPE2",
    "SKIA_BUILD_USE_FONTCONFIG",
    "SKIA_BUILD_ENABLE_FONTMGR_FONTCONFIG",
    "SKIA_BUILD_ENABLE_FONTMGR_ANDROID",
    "SKIA_BUILD_ENABLE_FONTMGR_WIN",
    "SKIA_BUILD_ENABLE_FONTMGR_WIN_GDI",
    "SKIA_BUILD_USE_HARFBUZZ",
    "SKIA_BUILD_USE_SYSTEM_HARFBUZZ",
    "SKIA_BUILD_USE_EXPAT",
    "SKIA_BUILD_USE_SYSTEM_EXPAT",
    "SKIA_BUILD_USE_ICU",
    "SKIA_BUILD_USE_SYSTEM_ICU",
    "SKIA_BUILD_USE_ZLIB",
    "SKIA_BUILD_USE_SYSTEM_ZLIB",
    "SKIA_BUILD_USE_LIBPNG_DECODE",
    "SKIA_BUILD_USE_LIBPNG_ENCODE",
    "SKIA_BUILD_USE_SYSTEM_LIBPNG",
    "SKIA_BUILD_USE_REPOSITORY_ZLIB",
    "SKIA_BUILD_USE_REPOSITORY_LIBPNG",
)


class FindSkiaTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.dependency = self.root / "depot" / "skia"
        self.module_dir = self.dependency / "cmake"
        self.module_dir.mkdir(parents=True)
        shutil.copy2(MODULE_DIR / "FindSkia.cmake", self.module_dir)
        shutil.copy2(MODULE_DIR / "SkiaLinkDependencies.cmake", self.module_dir)
        (self.dependency / "artifacts.json").write_text(
            json.dumps({"defaults": {"machine_build_config": {"required": False}}}),
            encoding="utf-8",
        )
        self.managed_root = self.dependency / "local"
        self.external_root = self.root / "external-skia"
        self.project = self.root / "project"
        self.project.mkdir()
        (self.project / "CMakeLists.txt").write_text(
            "\n".join(
                [
                    "cmake_minimum_required(VERSION 3.16)",
                    "project(skia_find_test NONE)",
                    f'list(PREPEND CMAKE_MODULE_PATH "{self.module_dir.as_posix()}")',
                    "find_package(Skia REQUIRED)",
                    "get_target_property(test_links Skia::Skia INTERFACE_LINK_LIBRARIES)",
                    "get_target_property(test_definitions Skia::Skia INTERFACE_COMPILE_DEFINITIONS)",
                    'file(WRITE "${CMAKE_BINARY_DIR}/result.txt" "links=${test_links}\\ndefinitions=${test_definitions}\\n")',
                    "",
                ]
            ),
            encoding="utf-8",
        )
        self.write_fake_dependency_modules()

    def write_fake_dependency_modules(self) -> None:
        for dependency_name, target_name in (("zlib-ng", "ZLIB::ZLIB"), ("libpng", "PNG::PNG")):
            module = self.root / "depot" / dependency_name / "cmake"
            module.mkdir(parents=True)
            package = "ZLIB" if dependency_name == "zlib-ng" else "PNG"
            (module / f"Find{package}.cmake").write_text(
                "\n".join(
                    [
                        f"set({package}_FOUND TRUE)",
                        f"if(NOT TARGET {target_name})",
                        f"  add_library({target_name} INTERFACE IMPORTED)",
                        "endif()",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

    def create_layout(self, root: pathlib.Path) -> pathlib.Path:
        for relative in (
            "include/config/SkUserConfig.h",
            "include/core/SkCanvas.h",
            "include/utils/SkRandom.h",
            "include/effects/SkImageSource.h",
            "include/gpu/GrContext.h",
            "src/gpu/gl/GrGLDefines.h",
        ):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("// test fixture\n", encoding="utf-8")
        library = root / "out" / "Release" / "macos" / "arm64" / "libskia.a"
        library.parent.mkdir(parents=True, exist_ok=True)
        library.write_bytes(b"skia-find-package-fixture")
        return library

    def write_metadata(
        self,
        library: pathlib.Path,
        *,
        version: int = 1,
        platform: str = "macos",
        architecture: str = "arm64",
        sha256: str | None = None,
        features: dict[str, bool] | None = None,
    ) -> pathlib.Path:
        values = {name: False for name in BOOLEAN_FIELDS}
        values.update(features or {})
        digest = sha256 or hashlib.sha256(library.read_bytes()).hexdigest()
        lines = [
            "# generated test metadata",
            f"set(SKIA_BUILD_CONFIG_VERSION {version})",
            'set(SKIA_BUILD_UPSTREAM_REVISION "158dc9d7")',
            f'set(SKIA_BUILD_PLATFORM "{platform}")',
            f'set(SKIA_BUILD_ARCHITECTURE "{architecture}")',
            f'set(SKIA_BUILD_LIBRARY_SHA256 "{digest}")',
        ]
        lines.extend(f"set({name} {'ON' if value else 'OFF'})" for name, value in values.items())
        lines.extend(
            [
                'set(SKIA_BUILD_TARGET_OS "mac")',
                'set(SKIA_BUILD_TARGET_CPU "arm64")',
                'set(SKIA_BUILD_GL_STANDARD "gl")',
                'set(SKIA_BUILD_NDK_API "")',
                "",
            ]
        )
        metadata = library.with_name("SkiaBuildConfig.cmake")
        metadata.write_text("\n".join(lines), encoding="utf-8")
        return metadata

    def configure(
        self,
        *,
        skia_dir: pathlib.Path | None = None,
        library: pathlib.Path | None = None,
        require_metadata: bool = False,
    ) -> tuple[subprocess.CompletedProcess[str], pathlib.Path]:
        build = self.root / f"build-{len(list(self.root.glob('build-*')))}"
        command = [
            "cmake",
            "-S",
            str(self.project),
            "-B",
            str(build),
            "-DCMAKE_OSX_ARCHITECTURES=arm64",
        ]
        if skia_dir is not None:
            command.append(f"-DSKIA_DIR={skia_dir}")
        if library is not None:
            command.append(f"-DSKIA_LIBRARY={library}")
        if require_metadata:
            command.append("-DSKIA_REQUIRE_BUILD_CONFIG=ON")
        result = subprocess.run(command, check=False, capture_output=True, text=True)
        return result, build

    def test_metadata_drives_metal_gl_links_and_definitions(self) -> None:
        library = self.create_layout(self.managed_root)
        self.write_metadata(
            library,
            features={
                "SKIA_BUILD_ENABLE_GPU": True,
                "SKIA_BUILD_USE_GL": True,
                "SKIA_BUILD_USE_METAL": True,
                "SKIA_BUILD_USE_VULKAN": True,
                "SKIA_BUILD_USE_ZLIB": True,
                "SKIA_BUILD_USE_REPOSITORY_ZLIB": True,
                "SKIA_BUILD_USE_LIBPNG_DECODE": True,
                "SKIA_BUILD_USE_SYSTEM_LIBPNG": True,
                "SKIA_BUILD_USE_REPOSITORY_LIBPNG": True,
            },
        )

        result, build = self.configure(require_metadata=True)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        interface = (build / "result.txt").read_text(encoding="utf-8")
        self.assertIn("Metal.framework", interface)
        self.assertIn("Foundation.framework", interface)
        self.assertIn("OpenGL.framework", interface)
        self.assertIn("PNG::PNG;ZLIB::ZLIB", interface)
        self.assertIn("definitions=SK_BUILD_FOR_MAC;SK_GL;SK_METAL;SK_VULKAN", interface)

    def test_metal_off_removes_metal_requirements(self) -> None:
        library = self.create_layout(self.managed_root)
        self.write_metadata(library, features={"SKIA_BUILD_USE_GL": True})

        result, build = self.configure(require_metadata=True)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        interface = (build / "result.txt").read_text(encoding="utf-8")
        self.assertNotIn("Metal.framework", interface)
        self.assertNotIn("Foundation.framework", interface)
        self.assertIn("OpenGL.framework", interface)

    def test_missing_managed_metadata_fails_when_required(self) -> None:
        self.create_layout(self.managed_root)
        result, _ = self.configure(require_metadata=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing required", result.stdout + result.stderr)

    def test_unsupported_version_fails(self) -> None:
        library = self.create_layout(self.managed_root)
        self.write_metadata(library, version=2)
        result, _ = self.configure(require_metadata=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported Skia build-config version '2'", result.stdout + result.stderr)

    def test_unsupported_enabled_dependency_feature_fails(self) -> None:
        library = self.create_layout(self.managed_root)
        self.write_metadata(library, features={"SKIA_BUILD_USE_DAWN": True})
        result, _ = self.configure(require_metadata=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Dawn linkage is not supported", result.stdout + result.stderr)

    def test_platform_architecture_and_sha_mismatches_fail(self) -> None:
        cases = (
            ({"platform": "ios"}, "platform mismatch"),
            ({"architecture": "x86_64"}, "architecture mismatch"),
            ({"sha256": "0" * 64}, "SHA-256 mismatch"),
        )
        for index, (overrides, message) in enumerate(cases):
            with self.subTest(case=index):
                root = self.managed_root / str(index)
                library = self.create_layout(root)
                self.write_metadata(library, **overrides)
                result, _ = self.configure(skia_dir=root, require_metadata=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stdout + result.stderr)

    def test_external_library_without_metadata_uses_bounded_legacy_path(self) -> None:
        library = self.create_layout(self.external_root)

        result, build = self.configure(skia_dir=self.external_root, library=library)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("External Skia library has no SkiaBuildConfig.cmake", result.stdout + result.stderr)
        self.assertIn("legacy behavior is used", result.stdout + result.stderr)
        interface = (build / "result.txt").read_text(encoding="utf-8")
        self.assertIn("PNG::PNG;ZLIB::ZLIB", interface)


if __name__ == "__main__":
    unittest.main()
