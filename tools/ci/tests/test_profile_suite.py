#!/usr/bin/env python3
"""Self-tests for tools/ci/profile_suite.py against JUnit fixtures."""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import sys
import tempfile
import os
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import profile_suite as prof  # noqa: E402

FIXTURE = """<?xml version="1.0" encoding="UTF-8" ?>
<testsuites id="2026-11-08" name="results.xml" tests="5" failures="1" skipped="0" flaky="0" time="30.0">
  <testsuite id="0" name="res://tests/test_fast.gd" package="res://tests/test_fast.gd" timestamp="2026-11-08T10:00:00" hostname="localhost" tests="3" failures="0" errors="0" skipped="0" flaky="0" time="2.0">
    <testcase name="test_one" classname="res://tests/test_fast.gd" time="0.5"/>
    <testcase name="test_two" classname="res://tests/test_fast.gd" time="1.0"/>
    <testcase name="test_three" classname="res://tests/test_fast.gd" time="0.5"/>
  </testsuite>
  <testsuite id="1" name="res://tests/test_slow.gd" package="res://tests/test_slow.gd" timestamp="2026-11-08T10:00:00" hostname="localhost" tests="2" failures="1" errors="0" skipped="0" flaky="0" time="28.0">
    <testcase name="test_match" classname="res://tests/test_slow.gd" time="1.0"/>
    <testcase name="test_long_match" classname="res://tests/test_slow.gd" time="2.0">
      <failure message="failed"/>
    </testcase>
  </testsuite>
</testsuites>
"""


class ProfileTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp(prefix="aegis-profile-"))
        self.addCleanup(shutil.rmtree, self.dir, True)
        self.report = self.dir / "results.xml"
        self.report.write_text(FIXTURE, encoding="utf-8")

    def test_totals_and_fixed_setup(self) -> None:
        data = prof.analyse(self.report)
        self.assertEqual(len(data["suites"]), 2)
        self.assertEqual(data["total_cases"], 5)
        self.assertAlmostEqual(data["total_suite_time"], 30.0)
        self.assertAlmostEqual(data["total_case_time"], 5.0)
        self.assertAlmostEqual(data["fixed_overhead"], 25.0)
        self.assertEqual(data["failed_suites"], 1)

    def test_suites_are_sorted_by_time(self) -> None:
        data = prof.analyse(self.report)
        self.assertEqual(data["suites"][0]["name"], "res://tests/test_slow.gd")
        self.assertAlmostEqual(data["suites"][0]["fixed_overhead"], 25.0)

    def test_slowest_cases_are_sorted(self) -> None:
        data = prof.analyse(self.report, top=2)
        self.assertEqual([c["name"] for c in data["slowest_cases"]],
                         ["test_long_match", "test_two"])

    def test_it_finds_the_newest_report_in_a_directory(self) -> None:
        root = self.dir / "reports"
        older = root / "report_1" / "results.xml"
        newer = root / "report_2" / "results.xml"
        for path, body in ((older, FIXTURE), (newer, FIXTURE)):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(body, encoding="utf-8")
        os.utime(older, (1000, 1000))
        os.utime(newer, (2000, 2000))
        self.assertEqual(prof.find_report(root), newer)

    def test_a_bare_testsuite_root_is_read(self) -> None:
        single = self.dir / "single.xml"
        single.write_text(
            '<testsuite name="only" tests="1" time="3.0">'
            '<testcase name="one" time="1.0"/></testsuite>', encoding="utf-8")
        data = prof.analyse(single)
        self.assertEqual(len(data["suites"]), 1)
        self.assertAlmostEqual(data["fixed_overhead"], 2.0)

    def _main(self, *argv: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = prof.main([str(a) for a in argv])
        return code, out.getvalue()

    def test_cli_prints_tables_and_writes_json(self) -> None:
        out = self.dir / "profile.json"
        code, text = self._main("--report", self.report, "--output", out)
        self.assertEqual(code, 0)
        self.assertIn("Most fixed setup", text)
        self.assertIn("test_long_match", text)
        data = json.loads(out.read_text(encoding="utf-8"))
        self.assertEqual(data["total_cases"], 5)

    def test_cli_json_mode(self) -> None:
        code, text = self._main("--report", self.report, "--json")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(text)["total_suite_time"], 30.0)

    def test_a_missing_report_passes_unless_required(self) -> None:
        missing = self.dir / "nope"
        code, _ = self._main("--report", missing)
        self.assertEqual(code, 0)
        code, _ = self._main("--report", missing, "--require")
        self.assertEqual(code, 1)

    def test_fail_over_gates_a_slow_suite(self) -> None:
        code, _ = self._main("--report", self.report, "--fail-over", "10")
        self.assertEqual(code, 1)
        code, _ = self._main("--report", self.report, "--fail-over", "60")
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
