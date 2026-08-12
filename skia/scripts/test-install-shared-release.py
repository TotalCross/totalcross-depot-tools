#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Request-count coverage for release-wide Skia installation."""

import hashlib
import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
FETCH = ROOT / "fetch.sh"


FAKE_CURL = r'''#!/usr/bin/env python3
import os
import pathlib
import sys
import urllib.parse

args = sys.argv[1:]
output = pathlib.Path(args[args.index("-o") + 1])
name = pathlib.Path(urllib.parse.urlparse(args[-1]).path).name
counter = pathlib.Path(os.environ["FAKE_CURL_COUNTER"])
count = int(counter.read_text()) if counter.exists() else 0
counter.write_text(str(count + 1))
output.write_bytes((pathlib.Path(os.environ["FAKE_ASSET_DIR"]) / name).read_bytes())
sys.stdout.write("200")
'''


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SharedSkiaInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.assets = self.root / "assets"
        self.assets.mkdir()
        dev = self.assets / "dev.zip"
        with zipfile.ZipFile(str(dev), "w") as archive:
            archive.writestr("modules/skia/include/core/SkCanvas.h", "canvas")
            archive.writestr("modules/skia/src/gpu/gl/GrGLDefines.h", "gl")
        first = self.assets / "build-one.md"
        second = self.assets / "build-two.md"
        first.write_text("one")
        second.write_text("two")
        manifest = {
            "defaults": {
                "source": {"repo": "owner/repo", "tag": "skia-test"},
                "dev_bundle": {"artifact_name": dev.name, "sha256": sha256(dev)},
            },
            "metadata": {
                "build-manifests": {
                    "one": {"artifact_name": first.name, "target_path": "local/out/one/build_config_manifest.md", "sha256": sha256(first)},
                    "two": {"artifact_name": second.name, "target_path": "local/out/two/build_config_manifest.md", "sha256": sha256(second)},
                }
            },
        }
        self.manifest = self.root / "artifacts.json"
        self.manifest.write_text(json.dumps(manifest))
        self.curl = self.root / "curl"
        self.curl.write_text(FAKE_CURL)
        self.curl.chmod(self.curl.stat().st_mode | stat.S_IXUSR)
        self.counter = self.root / "requests"
        self.local = self.root / "local"

    def tearDown(self):
        self.temp.cleanup()

    def run_install(self):
        env = os.environ.copy()
        env.update({
            "FAKE_ASSET_DIR": str(self.assets),
            "FAKE_CURL_COUNTER": str(self.counter),
            "SKIA_LOCAL_ROOT": str(self.local),
            "TOTALCROSS_DEPOT_CURL": str(self.curl),
            "TOTALCROSS_DEPOT_FETCH_CACHE_DIR": str(self.root / "cache"),
            "TOTALCROSS_DEPOT_FETCH_RETRY_DELAY": "0",
        })
        return subprocess.run(
            ["bash", str(FETCH), "--install-shared", "--manifest", str(self.manifest), "--base-url", "https://assets.test"],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def test_shared_content_downloads_once_and_reuses_marker(self):
        first = self.run_install()
        second = self.run_install()
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertEqual(3, int(self.counter.read_text()))
        self.assertIn("Reusing shared Skia", second.stdout)
        self.assertTrue((self.local / "include" / "core" / "SkCanvas.h").is_file())
        self.assertTrue((self.local / "out" / "one" / "build_config_manifest.md").is_file())


if __name__ == "__main__":
    unittest.main()
