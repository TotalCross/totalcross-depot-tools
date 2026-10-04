# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts" / "dependency-release.sh"


class DependencyReleaseHelperTest(unittest.TestCase):
    def run_lookup(self, deps_file: pathlib.Path, dependency: str):
        script = (
            f'source "{HELPER}"; '
            f'tc_dependency_release_from_deps "{deps_file}" "{dependency}"'
        )
        return subprocess.run(
            ["bash", "-c", script],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_reads_release_pin(self):
        result = self.run_lookup(ROOT / "deps.yml", "qrcodegen")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "qrcodegen-20250123-r2")

    def test_missing_dependency_returns_empty_output(self):
        result = self.run_lookup(ROOT / "deps.yml", "does-not-exist")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def test_missing_file_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_lookup(pathlib.Path(directory) / "missing.yml", "zlib")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
