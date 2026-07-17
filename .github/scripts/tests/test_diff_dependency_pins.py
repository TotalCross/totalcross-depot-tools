# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).parents[1] / "diff-dependency-pins.py"
SPEC = importlib.util.spec_from_file_location("diff_dependency_pins", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)
FIXTURES = Path(__file__).parent / "fixtures" / "dependency-pins"


class DependencyPinDiffTests(unittest.TestCase):
    def report(self, name):
        return MODULE.build_report(
            MODULE.read_document(str(FIXTURES / name / "before.yml")),
            MODULE.read_document(str(FIXTURES / name / "after.yml")),
        )

    def test_mbedtls_has_no_consumers(self):
        self.assertEqual(self.report("mbedtls")["affected_consumers"], [])

    def test_zlib_ng_routes_exact_consumers(self):
        self.assertEqual(self.report("zlib-ng")["affected_consumers"], ["libpng", "minizip-ng", "skia"])

    def test_libpng_routes_skia(self):
        self.assertEqual(self.report("libpng")["affected_consumers"], ["skia"])

    def test_multiple_changes_are_sorted_and_merged(self):
        self.assertEqual(self.report("multiple")["affected_consumers"], ["libpng", "minizip", "minizip-ng", "skia"])

    def test_formatting_only_change_is_ignored(self):
        self.assertEqual(self.report("formatting")["changed_dependencies"], [])
