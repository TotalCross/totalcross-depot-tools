# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Focused selective-stack planning contracts."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "native-stack.py"
SPEC = importlib.util.spec_from_file_location("native_stack", MODULE_PATH)
assert SPEC and SPEC.loader
NATIVE_STACK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE_STACK)
INVENTORY_SPEC = importlib.util.spec_from_file_location(
    "native_inventory", ROOT / "scripts" / "inventory-native-build-orchestration.py"
)
assert INVENTORY_SPEC and INVENTORY_SPEC.loader
NATIVE_INVENTORY = importlib.util.module_from_spec(INVENTORY_SPEC)
INVENTORY_SPEC.loader.exec_module(NATIVE_INVENTORY)


class NativeStackTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = NATIVE_STACK.NATIVE_BUILD.load_config()

    @staticmethod
    def release_info(library: str) -> dict[str, str]:
        tag = f"{library}-1"
        return {
            "library": library,
            "version": "1",
            "base_tag": tag,
            "deps_release": tag,
            "manifest_release": tag,
        }

    def plan(self, stack: str, operation: str, releases: list[dict[str, object]], requested: str = "all") -> dict[str, object]:
        tags = [str(item["tag"]) for item in releases]
        return NATIVE_STACK.plan_stack(
            self.config, stack, operation, requested, self.release_info, tags, releases
        )

    def existing(self, libraries: list[str]) -> list[dict[str, object]]:
        return [
            {"tag": f"{library}-1", "draft": False, "url": f"https://example.test/{library}"}
            for library in libraries
        ]

    def test_all_existing_releases_have_no_build_or_publication_jobs(self) -> None:
        members = self.config["stacks"]["graphics"]["libraries"]
        plan = self.plan("graphics", "release", self.existing(members))
        self.assertEqual([], plan["publication_order"])
        self.assertTrue(all(item["action"] == "external" for item in plan["libraries"]))

    def test_only_libpng_missing_fetches_external_zlib_ng(self) -> None:
        members = self.config["stacks"]["graphics"]["libraries"]
        plan = self.plan("graphics", "release", self.existing([item for item in members if item != "libpng"]))
        libpng = next(item for item in plan["libraries"] if item["library"] == "libpng")
        self.assertEqual(["libpng"], plan["publication_order"])
        self.assertEqual("build-and-release", libpng["action"])
        self.assertEqual("external", libpng["dependencies"][0]["source"])
        self.assertEqual("zlib-ng", libpng["dependencies"][0]["library"])

    def test_missing_dependency_and_consumer_build_once_in_topological_order(self) -> None:
        plan = self.plan("graphics", "release", [], requested="minizip")
        self.assertEqual(["zlib", "minizip"], plan["publication_order"])
        minizip = next(item for item in plan["libraries"] if item["library"] == "minizip")
        self.assertEqual("local", minizip["dependencies"][0]["source"])

    def test_one_missing_others_library_does_not_select_unrelated_members(self) -> None:
        members = self.config["stacks"]["others"]["libraries"]
        plan = self.plan("others", "release", self.existing([item for item in members if item != "sljit"]))
        self.assertEqual(["sljit"], plan["publication_order"])

    def test_force_release_selects_every_graphics_member_and_next_tags(self) -> None:
        plan = self.plan("graphics", "force-release", self.existing(self.config["stacks"]["graphics"]["libraries"]))
        self.assertEqual(plan["order"], plan["publication_order"])
        self.assertTrue(all(item["effective_release_tag"].endswith("-r2") for item in plan["libraries"]))

    def test_lanes_group_selected_cmake_libraries_by_target_and_runner(self) -> None:
        plan = self.plan("graphics", "build", [], requested="zlib,minizip")
        linux_x64 = next(lane for lane in plan["lanes"] if lane["target"] == "linux-x86_64")
        self.assertEqual(["zlib", "minizip"], linux_x64["libraries"])

    def test_unpublished_stack_member_can_plan_build_from_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / "sdl2" / "manifest.yml"
            manifest.parent.mkdir()
            manifest.write_text("version: 2.32.8\nrelease: sdl2-2.32.8\n", encoding="utf-8")
            plan = NATIVE_STACK.plan_stack(
                self.config,
                "others",
                "build",
                "sdl2",
                lambda library: NATIVE_STACK._build_metadata(root, library),
                [],
                [],
            )
        self.assertEqual(["sdl2"], plan["publication_order"])
        self.assertEqual("build", plan["libraries"][0]["action"])
        self.assertEqual("2.32.8", plan["libraries"][0]["version"])

    def test_unpublished_stack_member_can_plan_initial_release(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "deps.yml").write_text("dependencies:\n", encoding="utf-8")
            manifest = root / "sdl2" / "manifest.yml"
            manifest.parent.mkdir()
            manifest.write_text("version: 2.32.8\nrelease: sdl2-2.32.8\n", encoding="utf-8")
            plan = NATIVE_STACK.plan_stack(
                self.config,
                "others",
                "release",
                "sdl2",
                lambda library: NATIVE_STACK.NATIVE_RELEASE.metadata(root, library),
                [],
                [],
            )
        self.assertEqual(["sdl2"], plan["publication_order"])
        self.assertEqual("build-and-release", plan["libraries"][0]["action"])

    def test_recovery_state_is_reported_without_selecting_publication(self) -> None:
        plan = self.plan("graphics", "release", [{"tag": "libpng-1", "draft": True, "url": "https://example.test/draft"}], requested="libpng")
        self.assertEqual([{"library": "libpng", "reason": "draft_release"}], plan["recoveries"])
        self.assertNotIn("libpng", plan["publication_order"])

    def test_skia_topology_preserves_target_parallelism_and_actual_dependencies(self) -> None:
        plan = self.plan("graphics", "build", [])
        topology = plan["skia_topology"]
        self.assertIsNotNone(topology)
        targets = topology["skia_targets"]
        self.assertEqual(set(self.config["libraries"]["skia"]["targets"]), {node["target"] for node in targets})
        target_ids = {node["id"] for node in targets}
        self.assertTrue(all(not target_ids.intersection(node["needs"]) for node in targets))
        self.assertEqual(["prepare-skia-sources"], next(node for node in targets if node["target"] == "wasm")["needs"])
        self.assertEqual("lane:windows-x64", next(node for node in targets if node["target"] == "windows-x64")["continued_lane"])
        baseline = NATIVE_INVENTORY.inventory()["skia_parallelism"]["jobs"]
        self.assertEqual(set(baseline), set(topology["baseline_job_families"]))
        self.assertEqual(
            ["prepare-skia-sources"],
            topology["baseline_job_families"]["prepare-skia-sources-windows"],
        )
        skia_dependencies = next(item for item in plan["libraries"] if item["library"] == "skia")["dependencies"]
        self.assertEqual({"zlib-ng", "libpng"}, {item["library"] for item in skia_dependencies})

    def test_skia_topology_rejects_accidental_target_serialization(self) -> None:
        plan = self.plan("graphics", "build", [])
        topology = plan["skia_topology"]
        topology["skia_targets"][1]["needs"].append(topology["skia_targets"][0]["id"])
        with self.assertRaisesRegex(NATIVE_STACK.NativeStackError, "depends on another Skia target"):
            NATIVE_STACK.validate_skia_topology(self.config, topology)


if __name__ == "__main__":
    unittest.main()
