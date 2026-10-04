# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


def read_bundle_releases():
    releases = {}
    current = None
    for line in (ROOT / "deps.yml").read_text(encoding="utf-8").splitlines():
        match = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line)
        if match:
            current = match.group(1)
            continue
        match = re.match(r"^    release:\s*(\S+)\s*$", line)
        if match and current:
            releases[current] = match.group(1)
    return releases


def read_manifest_release(path: pathlib.Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^release:\s*(\S+)\s*$", line)
        if match:
            return match.group(1)
    return None


class DependencyManifestReleaseTest(unittest.TestCase):
    def test_manifest_release_matches_bundle_pin(self):
        mismatches = []
        for dependency, release in sorted(read_bundle_releases().items()):
            manifest = ROOT / dependency / "manifest.yml"
            if not manifest.exists():
                continue
            manifest_release = read_manifest_release(manifest)
            if manifest_release != release:
                mismatches.append(
                    f"{dependency}: deps.yml={release}, manifest.yml={manifest_release}"
                )
        self.assertEqual(mismatches, [])


if __name__ == "__main__":
    unittest.main()
