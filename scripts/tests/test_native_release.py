# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Focused release-state contracts for scripts/native-release.py."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "native-release.py"
SPEC = importlib.util.spec_from_file_location("native_release", MODULE_PATH)
assert SPEC and SPEC.loader
NATIVE_RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE_RELEASE)


class NativeReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "zlib").mkdir()
        (self.root / "deps.yml").write_text(
            "dependencies:\n  zlib:\n    version: 1.3.1\n    release: zlib-1.3.1\n    path: zlib\n",
            encoding="utf-8",
        )
        (self.root / "zlib" / "manifest.yml").write_text(
            "name: zlib\nversion: 1.3.1\nrelease: zlib-1.3.1\nartifact:\n  archives:\n    - zlib-linux-x86_64.tar.gz\n    - zlib-macos-arm64.tar.gz\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def inspect(self, tags: list[str], releases: list[dict[str, object]], effective_tag: str | None = None) -> dict[str, object]:
        return NATIVE_RELEASE.inspect_release(
            NATIVE_RELEASE.metadata(self.root, "zlib"), tags, releases, effective_tag
        )

    def test_release_uses_configured_base_tag_when_missing(self) -> None:
        result = self.inspect([], [])
        self.assertEqual("build-required", result["status"])
        self.assertEqual("zlib-1.3.1", result["effective_release_tag"])

    def test_existing_non_draft_release_short_circuits(self) -> None:
        result = self.inspect(
            ["zlib-1.3.1"],
            [{"tag": "zlib-1.3.1", "draft": False, "url": "https://example.test/zlib", "assets": []}],
        )
        self.assertEqual("existing-release", result["status"])
        self.assertEqual("https://example.test/zlib", result["release_url"])

    def test_remote_release_query_uses_the_api_fields_available_in_current_gh(self) -> None:
        pages = [[{"tag_name": "zlib-1.3.1", "draft": False, "html_url": "https://example.test/zlib", "assets": [{"name": "zlib-linux-x86_64.tar.gz"}]}]]
        with mock.patch.object(NATIVE_RELEASE.subprocess, "check_output", return_value=json.dumps(pages)) as query:
            releases = NATIVE_RELEASE._remote_releases("TotalCross/totalcross-depot-tools")
        query.assert_called_once_with(
            ["gh", "api", "--paginate", "--slurp", "repos/TotalCross/totalcross-depot-tools/releases?per_page=100"],
            text=True,
        )
        self.assertEqual(
            [{"tag": "zlib-1.3.1", "draft": False, "url": "https://example.test/zlib", "assets": ["zlib-linux-x86_64.tar.gz"]}],
            releases,
        )

    def test_draft_and_tag_without_release_are_recovery_states(self) -> None:
        draft = self.inspect([], [{"tag": "zlib-1.3.1", "draft": True, "url": "https://example.test/draft"}])
        tag_only = self.inspect(["zlib-1.3.1"], [])
        self.assertEqual("draft_release", draft["reason"])
        self.assertEqual("tag_without_release", tag_only["reason"])

    def test_force_release_uses_highest_suffix_despite_gaps(self) -> None:
        self.assertEqual(
            "zlib-1.3.1-r5",
            NATIVE_RELEASE.next_force_tag("zlib-1.3.1", ["zlib-1.3.1", "zlib-1.3.1-r2", "zlib-1.3.1-r4"]),
        )

    def test_force_release_recheck_selects_next_suffix_after_concurrent_tag(self) -> None:
        initial = NATIVE_RELEASE.next_force_tag("zlib-1.3.1", ["zlib-1.3.1-r2"])
        rechecked = NATIVE_RELEASE.next_force_tag("zlib-1.3.1", ["zlib-1.3.1-r2", initial])
        self.assertEqual("zlib-1.3.1-r3", initial)
        self.assertEqual("zlib-1.3.1-r4", rechecked)

    def test_metadata_mismatch_and_committed_metadata_without_tag_are_diagnostic(self) -> None:
        (self.root / "deps.yml").write_text(
            (self.root / "deps.yml").read_text(encoding="utf-8").replace("zlib-1.3.1", "zlib-1.3.1-r2"),
            encoding="utf-8",
        )
        mismatch = self.inspect(
            ["zlib-1.3.1-r2"],
            [{"tag": "zlib-1.3.1-r2", "draft": False, "url": "https://example.test/zlib-r2"}],
        )
        (self.root / "zlib" / "manifest.yml").write_text(
            (self.root / "zlib" / "manifest.yml").read_text(encoding="utf-8").replace("zlib-1.3.1", "zlib-1.3.1-r2"),
            encoding="utf-8",
        )
        missing_tag = self.inspect([], [])
        self.assertEqual("metadata_mismatch", mismatch["reason"])
        self.assertEqual("metadata_commit_without_tag", missing_tag["reason"])

    def test_prepare_metadata_updates_manifest_and_bundle_pin(self) -> None:
        paths = NATIVE_RELEASE.prepare_metadata(self.root, "zlib", "zlib-1.3.1-r2")
        self.assertEqual([self.root / "deps.yml", self.root / "zlib" / "manifest.yml"], paths)
        self.assertEqual("zlib-1.3.1-r2", NATIVE_RELEASE.metadata(self.root, "zlib")["deps_release"])
        self.assertEqual("zlib-1.3.1-r2", NATIVE_RELEASE.metadata(self.root, "zlib")["manifest_release"])

    def test_asset_verification_fixture_reports_missing_and_unexpected(self) -> None:
        assets = self.root / "assets"
        assets.mkdir()
        (assets / "zlib-linux-x86_64.tar.gz").write_bytes(b"archive")
        (assets / "unexpected.tar.gz").write_bytes(b"archive")
        expected = set(NATIVE_RELEASE.expected_assets(self.root, "zlib"))
        actual = {path.name for path in assets.iterdir()}
        self.assertEqual({"zlib-macos-arm64.tar.gz"}, expected - actual)
        self.assertEqual({"unexpected.tar.gz"}, actual - expected)

    def test_skia_contract_rejects_undeclared_machine_config_and_diagnostics(self) -> None:
        skia = self.root / "skia"
        skia.mkdir()
        payload = {
            "release": {"assets": ["SkiaBuildConfig-linux-x86_64.cmake", "diagnostics.tar.gz", "SHA256SUMS"]},
            "metadata": {
                "machine-build-configs": {
                    "linux-x86_64": {"artifact_name": "SkiaBuildConfig-linux-x86_64.cmake"}
                }
            },
        }
        (skia / "manifest.yml").write_text(
            "artifact:\n  diagnostics: diagnostics.tar.gz\n", encoding="utf-8"
        )
        (skia / "artifacts.json").write_text(json.dumps(payload), encoding="utf-8")
        self.assertEqual(payload["release"]["assets"], NATIVE_RELEASE.validate_skia_asset_contract(self.root))

        for omitted in ("SkiaBuildConfig-linux-x86_64.cmake", "diagnostics.tar.gz"):
            with self.subTest(omitted=omitted):
                payload["release"]["assets"].remove(omitted)
                (skia / "artifacts.json").write_text(json.dumps(payload), encoding="utf-8")
                with self.assertRaisesRegex(NATIVE_RELEASE.NativeReleaseError, "omit"):
                    NATIVE_RELEASE.validate_skia_asset_contract(self.root)
                payload["release"]["assets"].append(omitted)

    def test_skia_summary_diagnostics_package_matches_release_contract(self) -> None:
        payload = json.loads((ROOT / "skia" / "artifacts.json").read_text(encoding="utf-8"))
        expected = set(NATIVE_RELEASE.expected_assets(ROOT, "skia"))
        diagnostics_name = next(name for name in expected if name.startswith("skia-build-diagnostics-"))
        with tempfile.TemporaryDirectory(dir=ROOT) as directory:
            assets = Path(directory)
            for name in expected - {diagnostics_name, "SHA256SUMS"}:
                (assets / name).write_bytes((name + "\n").encode("utf-8"))
            for target in payload["metadata"]["machine-build-configs"]:
                summary = assets / "diagnostics" / target / "build-summary.json"
                summary.parent.mkdir(parents=True, exist_ok=True)
                summary.write_text('{"status":"success"}\n', encoding="utf-8")

            subprocess.run(
                [str(ROOT / "skia" / "scripts" / "package-release-assets.sh"), str(assets)],
                cwd=ROOT,
                check=True,
            )

            actual = {path.name for path in assets.iterdir() if path.is_file()}
            self.assertEqual(11, len(payload["artifacts"]))
            self.assertEqual(11, len(payload["metadata"]["machine-build-configs"]))
            self.assertEqual(expected, actual)
            verification = subprocess.run(
                [
                    "python3",
                    str(MODULE_PATH),
                    "verify-assets",
                    "skia",
                    "--paths",
                    f"{assets.name}/*",
                ],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            verification_result = json.loads(verification.stdout)
            self.assertEqual([], verification_result["missing"])
            self.assertEqual([], verification_result["unexpected"])
            checksums = {
                line.split("  ", 1)[1]
                for line in (assets / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
            }
            self.assertEqual(expected - {"SHA256SUMS"}, checksums)
            with tarfile.open(assets / diagnostics_name, "r:gz") as archive:
                summaries = [name for name in archive.getnames() if name.endswith("/build-summary.json")]
            self.assertEqual(11, len(summaries))

    def test_fixture_files_are_valid_release_json(self) -> None:
        fixture = self.root / "releases.json"
        fixture.write_text(json.dumps([{"tag": "zlib-1.3.1", "draft": False}]), encoding="utf-8")
        self.assertEqual("zlib-1.3.1", json.loads(fixture.read_text(encoding="utf-8"))[0]["tag"])


if __name__ == "__main__":
    unittest.main()
