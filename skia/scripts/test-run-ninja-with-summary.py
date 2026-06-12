#!/usr/bin/env python3
import datetime as dt
import runpy
import tempfile
import unittest
from pathlib import Path


MODULE = runpy.run_path(str(Path(__file__).with_name("run-ninja-with-summary.py")))
normalized_diagnostic = MODULE["normalized_diagnostic"]
process_lines = MODULE["process_lines"]
should_print_line = MODULE["should_print_line"]


class NinjaSummaryTests(unittest.TestCase):
    def test_clang_diagnostic(self):
        diagnostic = normalized_diagnostic("src/foo.cc:12:7: fatal error: 'bar.h' file not found")
        self.assertEqual(diagnostic["file"], "src/foo.cc")
        self.assertEqual(diagnostic["line"], 12)
        self.assertEqual(diagnostic["column"], 7)
        self.assertEqual(diagnostic["severity"], "error")

    def test_msvc_diagnostic(self):
        diagnostic = normalized_diagnostic(r"C:\work\foo.cc(25,3): warning C4100: unused parameter")
        self.assertEqual(diagnostic["file"], r"C:\work\foo.cc")
        self.assertEqual(diagnostic["line"], 25)
        self.assertEqual(diagnostic["column"], 3)
        self.assertEqual(diagnostic["severity"], "warning")

    def test_summary_extracts_failed_target_and_linker_errors(self):
        lines = [
            "[1/3] compile ../../skia/src/foo.cc",
            "FAILED: obj/foo.o",
            "src/foo.cc:12:7: fatal error: 'bar.h' file not found",
            "ld: duplicate symbol _foo",
            "collect2: error: ld returned 1 exit status",
        ]
        now = dt.datetime.now(dt.timezone.utc)
        with tempfile.TemporaryDirectory() as tmp:
            summary = process_lines(
                lines,
                ["ninja", "-C", "out", "skia"],
                Path(tmp),
                Path(tmp) / "build-full.log",
                now,
                now,
                1,
            )

        self.assertEqual(summary["status"], "failure")
        self.assertEqual(summary["failed_targets"], ["obj/foo.o"])
        self.assertEqual(len(summary["errors"]), 2)
        self.assertEqual(len(summary["linker_diagnostics"]), 2)
        self.assertEqual(summary["contexts"][0]["trigger"], "FAILED: obj/foo.o")

    def test_console_filter_suppresses_non_failure_warnings(self):
        warning = "../../skia/include/private/SkTemplates.h:435:20: warning: 'result_of_t' is deprecated"
        note = "result_of.h:32:19: note: 'result_of_t' has been explicitly marked deprecated here"
        error = "src/foo.cc:12:7: fatal error: 'bar.h' file not found"

        self.assertFalse(should_print_line(warning, 0))
        self.assertFalse(should_print_line(note, 0))
        self.assertTrue(should_print_line(error, 0))
        self.assertTrue(should_print_line(warning, 3))


if __name__ == "__main__":
    unittest.main()
