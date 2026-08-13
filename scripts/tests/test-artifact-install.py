#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Integration tests for provenance-aware native artifact installation."""

import json
import hashlib
import os
import pathlib
import stat
import subprocess
import tarfile
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
LIBPNG_FETCH = ROOT / "libpng" / "fetch.sh"
SQLITE_FETCH = ROOT / "sqlite3" / "fetch.sh"
INSTALL_HELPER = ROOT / "scripts" / "artifact-install.sh"


FAKE_CURL = r'''#!/usr/bin/env python3
import os
import pathlib
import sys

args = sys.argv[1:]
output = pathlib.Path(args[args.index("-o") + 1])
counter = pathlib.Path(os.environ["FAKE_CURL_COUNTER"])
count = int(counter.read_text()) if counter.exists() else 0
counter.write_text(str(count + 1))
if os.environ.get("FAKE_CURL_FAIL") == "1":
    output.write_bytes(b"partial")
    sys.stdout.write("503")
    raise SystemExit(22)
output.write_bytes(pathlib.Path(os.environ["FAKE_CURL_ARCHIVE"]).read_bytes())
sys.stdout.write("200")
'''


FAKE_MV = r'''#!/usr/bin/env python3
import os
import pathlib
import subprocess
import sys

counter = pathlib.Path(os.environ["FAKE_MV_COUNTER"])
count = int(counter.read_text()) if counter.exists() else 0
count += 1
counter.write_text(str(count))
if count == 2:
    raise SystemExit(1)
raise SystemExit(subprocess.call(["/bin/mv"] + sys.argv[1:]))
'''


class ArtifactInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.archive = self.root / "libpng.tar.gz"
        package = self.root / "package" / "libpng" / "linux" / "x86_64"
        (package / "include").mkdir(parents=True)
        (package / "lib").mkdir()
        for name in ("png.h", "pngconf.h", "pnglibconf.h"):
            (package / "include" / name).write_text(name)
        (package / "lib" / "libpng.a").write_bytes(b"library")
        with tarfile.open(str(self.archive), "w:gz") as handle:
            handle.add(str(self.root / "package" / "libpng"), arcname="libpng")
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.checksums = self.root / "checksums.json"
        self.checksums.write_text(json.dumps({
            "schema": 1,
            "repositories": {"TotalCross/totalcross-depot-tools": {
                "libpng-1.6.48-r3": {"libpng-linux-x86_64.tar.gz": digest},
                "libpng-1.6.48-r4": {"libpng-linux-x86_64.tar.gz": digest},
            }},
        }))
        self.curl = self.root / "curl"
        self.curl.write_text(FAKE_CURL)
        self.curl.chmod(self.curl.stat().st_mode | stat.S_IXUSR)
        self.counter = self.root / "curl-count"
        self.dest = self.root / "install"

    def tearDown(self):
        self.temp.cleanup()

    def fetch(self, tag="libpng-1.6.48-r3", extra_env=None):
        env = os.environ.copy()
        env.update({
            "FAKE_CURL_ARCHIVE": str(self.archive),
            "FAKE_CURL_COUNTER": str(self.counter),
            "TOTALCROSS_DEPOT_CURL": str(self.curl),
            "TOTALCROSS_DEPOT_FETCH_CACHE_DIR": str(self.root / "session"),
            "TOTALCROSS_DEPOT_FETCH_ATTEMPTS": "2",
            "TOTALCROSS_DEPOT_FETCH_RETRY_DELAY": "0",
            "TOTALCROSS_DEPOT_CHECKSUMS_FILE": str(self.checksums),
        })
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["bash", str(LIBPNG_FETCH), "--platform", "linux", "--arch", "x86_64", "--release-tag", tag, "--dest", str(self.dest)],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def request_count(self):
        return int(self.counter.read_text()) if self.counter.exists() else 0

    def test_valid_install_is_reused_and_stale_or_changed_identity_refetches(self):
        first = self.fetch()
        second = self.fetch()
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertEqual(1, self.request_count())
        target = self.dest / "linux" / "x86_64"
        (target / "include" / "pngconf.h").unlink()
        stale = self.fetch()
        self.assertEqual(0, stale.returncode, stale.stderr)
        self.assertEqual(2, self.request_count())
        changed = self.fetch(tag="libpng-1.6.48-r4")
        self.assertEqual(0, changed.returncode, changed.stderr)
        self.assertEqual(3, self.request_count())
        marker = json.loads((target / ".totalcross-artifact.json").read_text())
        self.assertEqual("libpng-1.6.48-r4", marker["release_tag"])

    def test_failed_forced_refresh_preserves_valid_install(self):
        self.assertEqual(0, self.fetch().returncode)
        target = self.dest / "linux" / "x86_64"
        marker_before = (target / ".totalcross-artifact.json").read_bytes()
        failed = self.fetch(extra_env={"TOTALCROSS_DEPOT_FORCE_REFETCH": "1", "FAKE_CURL_FAIL": "1"})
        self.assertNotEqual(0, failed.returncode)
        self.assertEqual(marker_before, (target / ".totalcross-artifact.json").read_bytes())
        self.assertTrue((target / "lib" / "libpng.a").is_file())

    def test_failed_tree_replacement_restores_previous_install(self):
        old = self.root / "old"
        new = self.root / "new"
        for tree, content in ((old, "old"), (new, "new")):
            (tree / "include").mkdir(parents=True)
            (tree / "include" / "required.h").write_text(content)
        marker = {
            "schema": 1,
            "dependency": "demo",
            "repository": "owner/repo",
            "release_tag": "old-tag",
            "asset": "old.tar.gz",
            "sha256": "1" * 64,
        }
        (old / ".totalcross-artifact.json").write_text(json.dumps(marker))
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        fake_mv = fake_bin / "mv"
        fake_mv.write_text(FAKE_MV)
        fake_mv.chmod(fake_mv.stat().st_mode | stat.S_IXUSR)
        counter = self.root / "mv-count"
        env = os.environ.copy()
        env.update({"PATH": str(fake_bin) + os.pathsep + env["PATH"], "FAKE_MV_COUNTER": str(counter)})
        command = [
            "bash", "-c",
            'source "$1"; tc_artifact_replace_tree "$2" "$3" demo owner/repo new-tag new.tar.gz "2"$(printf "2%.0s" {1..63}) include/required.h',
            "test", str(INSTALL_HELPER), str(new), str(old),
        ]
        result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("old", (old / "include" / "required.h").read_text())
        restored = json.loads((old / ".totalcross-artifact.json").read_text())
        self.assertEqual("old-tag", restored["release_tag"])

    def test_incomplete_tree_reports_missing_requirement(self):
        source = self.root / "incomplete"
        source.mkdir()
        destination = self.root / "missing-install"
        command = [
            "bash", "-c",
            'source "$1"; tc_artifact_replace_tree "$2" "$3" sqlite3 owner/repo tag asset.tar.gz "3"$(printf "3%.0s" {1..63}) include/sqlite3.h',
            "test", str(INSTALL_HELPER), str(source), str(destination),
        ]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("error: staged sqlite3 artifact is incomplete:", result.stderr)
        self.assertIn("missing include/sqlite3.h", result.stderr)
        self.assertFalse(destination.exists())

    def test_incomplete_tree_reports_missing_alternatives(self):
        source = self.root / "incomplete-alternatives"
        source.mkdir()
        destination = self.root / "missing-library-install"
        command = [
            "bash", "-c",
            'source "$1"; tc_artifact_replace_tree "$2" "$3" sqlite3 owner/repo tag asset.tar.gz "4"$(printf "4%.0s" {1..63}) "lib/libsqlite3.a|lib/sqlite3.lib"',
            "test", str(INSTALL_HELPER), str(source), str(destination),
        ]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("missing one of: lib/libsqlite3.a | lib/sqlite3.lib", result.stderr)
        self.assertFalse(destination.exists())


class SQLiteCompatibleOverrideTests(unittest.TestCase):
    REPOSITORY = "example/sqlite-overrides"
    RELEASE_TAG = "sqlite3-see-compatible"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.archive = self.root / "sqlite3-linux-x86_64.tar.gz"
        package = self.root / "package" / "sqlite3" / "see" / "linux" / "x86_64"
        (package / "include").mkdir(parents=True)
        (package / "lib").mkdir()
        (package / "include" / "sqlite3.h").write_text("sqlite3 header")
        (package / "lib" / "libsqlite3.a").write_bytes(b"sqlite3 library")
        with tarfile.open(str(self.archive), "w:gz") as handle:
            handle.add(str(self.root / "package" / "sqlite3"), arcname="sqlite3")
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.checksums = self.root / "checksums.json"
        self.checksums.write_text(json.dumps({
            "schema": 1,
            "repositories": {self.REPOSITORY: {
                self.RELEASE_TAG: {self.archive.name: digest},
            }},
        }))
        self.curl = self.root / "curl"
        self.curl.write_text(FAKE_CURL)
        self.curl.chmod(self.curl.stat().st_mode | stat.S_IXUSR)
        self.counter = self.root / "curl-count"
        self.dest = self.root / "install"

    def tearDown(self):
        self.temp.cleanup()

    def fetch(self):
        env = os.environ.copy()
        env.update({
            "FAKE_CURL_ARCHIVE": str(self.archive),
            "FAKE_CURL_COUNTER": str(self.counter),
            "TOTALCROSS_DEPOT_CURL": str(self.curl),
            "TOTALCROSS_DEPOT_FETCH_CACHE_DIR": str(self.root / "session"),
            "TOTALCROSS_DEPOT_FETCH_ATTEMPTS": "2",
            "TOTALCROSS_DEPOT_FETCH_RETRY_DELAY": "0",
            "TOTALCROSS_DEPOT_CHECKSUMS_FILE": str(self.checksums),
        })
        return subprocess.run(
            [
                "bash", str(SQLITE_FETCH),
                "--platform", "linux",
                "--arch", "x86_64",
                "--release-tag", self.RELEASE_TAG,
                "--github-repo", self.REPOSITORY,
                "--dest", str(self.dest),
            ],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def request_count(self):
        return int(self.counter.read_text()) if self.counter.exists() else 0

    def test_override_without_sqlite3ext_is_installed_and_reused(self):
        first = self.fetch()
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(1, self.request_count())

        installs = list(self.dest.glob("*/linux/x86_64"))
        self.assertEqual(1, len(installs))
        target = installs[0]
        self.assertTrue((target / "include" / "sqlite3.h").is_file())
        self.assertFalse((target / "include" / "sqlite3ext.h").exists())
        self.assertTrue((target / "lib" / "libsqlite3.a").is_file())
        marker = json.loads((target / ".totalcross-artifact.json").read_text())
        self.assertEqual(self.REPOSITORY, marker["repository"])
        self.assertEqual(self.RELEASE_TAG, marker["release_tag"])

        second = self.fetch()
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertIn("Reusing SQLite3 linux/x86_64", second.stdout)
        self.assertEqual(1, self.request_count())


if __name__ == "__main__":
    unittest.main()
