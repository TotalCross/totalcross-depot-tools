#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Focused request-count tests for the shared GitHub Release transport."""

import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts" / "github-release.sh"


FAKE_CURL = r'''#!/usr/bin/env python3
import hashlib
import json
import os
import pathlib
import sys

args = sys.argv[1:]
output = pathlib.Path(args[args.index("-o") + 1])
url = args[-1]
state_path = pathlib.Path(os.environ["FAKE_CURL_STATE"])
state = json.loads(state_path.read_text()) if state_path.exists() else {"requests": []}
kind = "metadata" if "/releases/tags/" in url else ("api_asset" if "/releases/assets/" in url else "direct")
state["requests"].append({"kind": kind, "auth": "Authorization: Bearer fallback-token" in args})
scenario = os.environ["FAKE_CURL_SCENARIO"]
status = "200"
exit_code = 0
payload = b"artifact-content"
if scenario == "transient52" and kind == "direct" and sum(r["kind"] == "direct" for r in state["requests"]) == 1:
    status, exit_code, payload = "000", 52, b""
elif scenario in ("fallback", "reuse_metadata") and kind == "direct":
    status, exit_code, payload = "404", 22, b""
elif scenario == "terminal":
    status, exit_code, payload = "503", 22, b"partial"
elif kind == "metadata":
    assets = []
    for number, name in enumerate(("asset-a.tar.gz", "asset-b.tar.gz"), 1):
        digest = hashlib.sha256(b"artifact-content").hexdigest()
        assets.append({"name": name, "url": "https://api.test/releases/assets/%d" % number, "digest": "sha256:" + digest})
    payload = json.dumps({"assets": assets}).encode()
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(payload)
state_path.write_text(json.dumps(state))
sys.stdout.write(status)
raise SystemExit(exit_code)
'''


class GitHubReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.curl = self.root / "curl"
        self.curl.write_text(FAKE_CURL)
        self.curl.chmod(self.curl.stat().st_mode | stat.S_IXUSR)
        self.state = self.root / "state.json"
        self.cache = self.root / "cache"

    def tearDown(self):
        self.temp.cleanup()

    def run_download(self, scenario, asset="asset-a.tar.gz", output=None, extra_env=None):
        output = output or self.root / asset
        env = os.environ.copy()
        env.update({
            "FAKE_CURL_SCENARIO": scenario,
            "FAKE_CURL_STATE": str(self.state),
            "TOTALCROSS_DEPOT_CURL": str(self.curl),
            "TOTALCROSS_DEPOT_FETCH_CACHE_DIR": str(self.cache),
            "TOTALCROSS_DEPOT_FETCH_ATTEMPTS": "3",
            "TOTALCROSS_DEPOT_FETCH_RETRY_DELAY": "0",
            "TOTALCROSS_GITHUB_WEB_BASE_URL": "https://web.test",
            "TOTALCROSS_GITHUB_API_BASE_URL": "https://api.test",
        })
        if extra_env:
            env.update(extra_env)
        command = [
            "bash", "-c",
            'source "$1"; tc_github_release_download owner/repo tag "$2" "$3" EXPLICIT_TOKEN DEP_TOKEN',
            "test", str(HELPER), asset, str(output),
        ]
        return subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def requests(self):
        return json.loads(self.state.read_text())["requests"]

    def test_retries_curl_exit_52(self):
        result = self.run_download("transient52")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["direct", "direct"], [item["kind"] for item in self.requests()])

    def test_404_falls_back_without_retry_and_empty_token_falls_through(self):
        result = self.run_download(
            "fallback",
            extra_env={"EXPLICIT_TOKEN": "", "DEP_TOKEN": "", "GITHUB_TOKEN": "fallback-token"},
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["direct", "metadata", "api_asset"], [item["kind"] for item in self.requests()])
        self.assertTrue(all(item["auth"] for item in self.requests()))

    def test_public_api_fallback_and_metadata_reuse(self):
        first = self.run_download("reuse_metadata", "asset-a.tar.gz")
        second = self.run_download("reuse_metadata", "asset-b.tar.gz")
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertEqual(["direct", "metadata", "api_asset", "api_asset"], [item["kind"] for item in self.requests()])
        self.assertFalse(any(item["auth"] for item in self.requests()))

    def test_terminal_failure_is_bounded_and_preserves_output(self):
        output = self.root / "existing"
        output.write_text("keep")
        result = self.run_download("terminal", output=output)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("keep", output.read_text())
        self.assertEqual(6, len(self.requests()))


if __name__ == "__main__":
    unittest.main()
