#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Focused request-count tests for the shared GitHub Release transport."""

import hashlib
import http.server
import json
import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import threading
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
fail_http = "--fail" in args or "--fail-with-body" in args or any(
    arg.startswith("-") and not arg.startswith("--") and "f" in arg[1:] for arg in args
)
request = {
    "kind": kind,
    "auth": "Authorization: Bearer fallback-token" in args,
    "fail_http": fail_http,
}
state["requests"].append(request)
scenario = os.environ["FAKE_CURL_SCENARIO"]
status = "200"
exit_code = 0
payload = b"artifact-content"
if scenario == "transient52" and kind == "direct" and sum(r["kind"] == "direct" for r in state["requests"]) == 1:
    status, exit_code, payload = "000", 52, b""
elif scenario in ("fallback", "reuse_metadata") and kind == "direct":
    status, payload = "404", b"not found"
elif scenario == "terminal":
    status, payload = "503", b"partial"
elif scenario in ("direct_mismatch_api_success", "direct_and_api_mismatch") and kind == "direct":
    payload = b"wrong-direct-content"
elif scenario == "direct_and_api_mismatch" and kind == "api_asset":
    payload = b"wrong-api-content"
elif kind == "metadata":
    assets = []
    for number, name in enumerate(("asset-a.tar.gz", "asset-b.tar.gz"), 1):
        digest = hashlib.sha256(b"artifact-content").hexdigest()
        assets.append({"name": name, "url": "https://api.test/releases/assets/%d" % number, "digest": "sha256:" + digest})
    payload = json.dumps({"assets": assets}).encode()
if exit_code == 0 and fail_http and status.startswith(("4", "5")):
    exit_code = 22
request.update({"http_status": status, "exit_code": exit_code})
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
        digest = hashlib.sha256(b"artifact-content").hexdigest()
        self.checksums = self.root / "checksums.json"
        self.checksums.write_text(json.dumps({
            "schema": 1,
            "repositories": {"owner/repo": {"tag": {"asset-a.tar.gz": digest, "asset-b.tar.gz": digest}}},
        }))

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
            "TOTALCROSS_DEPOT_CHECKSUMS_FILE": str(self.checksums),
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
        self.assertTrue(self.requests()[0]["fail_http"])
        self.assertEqual(22, self.requests()[0]["exit_code"])
        self.assertNotIn("checksum mismatch", result.stderr)

    def test_fake_curl_allows_http_error_without_fail_option(self):
        output = self.root / "http-error"
        env = os.environ.copy()
        env.update({"FAKE_CURL_SCENARIO": "fallback", "FAKE_CURL_STATE": str(self.state)})
        result = subprocess.run(
            [str(self.curl), "-w", "%{http_code}", "-o", str(output), "https://web.test/direct"],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("404", result.stdout)
        self.assertEqual(b"not found", output.read_bytes())
        self.assertFalse(self.requests()[0]["fail_http"])

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

    def test_direct_checksum_mismatch_uses_api_artifact_once(self):
        result = self.run_download("direct_mismatch_api_success")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(b"artifact-content", (self.root / "asset-a.tar.gz").read_bytes())
        self.assertEqual(["direct", "metadata", "api_asset"], [item["kind"] for item in self.requests()])
        self.assertIn("fallback after direct checksum mismatch", result.stderr)

    def test_direct_and_api_checksum_mismatch_preserves_output(self):
        output = self.root / "existing-checksum"
        output.write_text("keep")
        result = self.run_download("direct_and_api_mismatch", output=output)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("keep", output.read_text())
        self.assertIn("checksum mismatch", result.stderr)
        self.assertEqual(["direct", "metadata", "api_asset"], [item["kind"] for item in self.requests()])

    @unittest.skipUnless(shutil.which("curl"), "real curl is required")
    def test_real_curl_404_falls_back_to_asset_api(self):
        requests = []
        artifact = b"artifact-content"
        digest = hashlib.sha256(artifact).hexdigest()

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                if self.path == "/owner/repo/releases/download/tag/asset-a.tar.gz":
                    status, content_type, payload = 404, "text/plain", b"not found"
                elif self.path == "/repos/owner/repo/releases/tags/tag":
                    asset_url = "http://127.0.0.1:%d/releases/assets/1" % self.server.server_port
                    metadata = {"assets": [{
                        "name": "asset-a.tar.gz",
                        "url": asset_url,
                        "digest": "sha256:" + digest,
                    }]}
                    status, content_type, payload = 200, "application/json", json.dumps(metadata).encode()
                elif self.path == "/releases/assets/1":
                    status, content_type, payload = 200, "application/octet-stream", artifact
                else:
                    status, content_type, payload = 500, "text/plain", b"unexpected request"
                self.send_response(status)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def log_message(self, format_, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever)
        thread.daemon = True
        thread.start()
        try:
            output = self.root / "real-curl-artifact"
            env = os.environ.copy()
            env.pop("TOTALCROSS_DEPOT_CURL", None)
            base_url = "http://127.0.0.1:%d" % server.server_port
            env.update({
                "TOTALCROSS_DEPOT_FETCH_CACHE_DIR": str(self.cache),
                "TOTALCROSS_DEPOT_FETCH_ATTEMPTS": "3",
                "TOTALCROSS_DEPOT_FETCH_RETRY_DELAY": "0",
                "TOTALCROSS_DEPOT_CHECKSUMS_FILE": str(self.checksums),
                "TOTALCROSS_GITHUB_WEB_BASE_URL": base_url,
                "TOTALCROSS_GITHUB_API_BASE_URL": base_url,
                "NO_PROXY": "127.0.0.1,localhost",
                "no_proxy": "127.0.0.1,localhost",
            })
            command = [
                "bash", "-c",
                'source "$1"; tc_github_release_download owner/repo tag asset-a.tar.gz "$2"',
                "test", str(HELPER), str(output),
            ]
            result = subprocess.run(
                command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(artifact, output.read_bytes())
        self.assertEqual([
            "/owner/repo/releases/download/tag/asset-a.tar.gz",
            "/repos/owner/repo/releases/tags/tag",
            "/releases/assets/1",
        ], requests)
        self.assertIn("curl exit 22, http 404", result.stderr)


if __name__ == "__main__":
    unittest.main()
