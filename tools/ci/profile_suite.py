#!/usr/bin/env python3
"""Profile where the gdUnit4 suite spends its time.

Why this exists
---------------
The quality plan (ID 7) asks for the suite to be profiled before it is
trimmed. CI already writes a JUnit report (`game/reports/**/results.xml` from
gdUnit4's XML reporter); this reads it and answers two questions:

* which suites cost the most wall time, and
* how much of a suite's time is *fixed overhead* -- suite time minus the sum
  of its cases' own times. That difference is setup and teardown: the scene
  instantiations, fixture loads and `before_test()` work that runs whether or
  not a test does anything. A suite with a large fixed share is where shared
  setup pays; a suite whose time is in its cases is doing real work.

It reads a report rather than running Godot, so it works on CI output and on a
Mac run alike, and never invents timings.

Usage
-----
    python3 tools/ci/profile_suite.py
    python3 tools/ci/profile_suite.py --report game/reports/report_412
    python3 tools/ci/profile_suite.py --json --output "$RUNNER_TEMP/profile.json"
    python3 tools/ci/profile_suite.py --fail-over 900   # gate a slow suite

The default report directory is `game/reports`; the newest `results.xml`
under it is used. A missing report is not an error unless `--require` is
given, so the step can run with `if: always()` without masking test failures.
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

DEFAULT_REPORT_DIR = Path("game/reports")


def _local(tag: str) -> str:
    """Tag name without an XML namespace."""
    return tag.rsplit("}", 1)[-1]


def find_report(path: Path) -> Path | None:
    """The report file at `path`, or the newest `results.xml` under it."""
    if path.is_file():
        return path
    if not path.is_dir():
        return None
    reports = sorted(
        path.rglob("results.xml"),
        key=lambda p: (p.stat().st_mtime, str(p)),
    )
    return reports[-1] if reports else None


def _seconds(value: str | None) -> float:
    try:
        return max(float(value or 0.0), 0.0)
    except ValueError:
        return 0.0


def _suites(root: ET.Element) -> list[ET.Element]:
    """Top-level `<testsuite>` elements, without double-counting nesting."""
    if _local(root.tag) == "testsuite":
        return [root]
    return [child for child in root if _local(child.tag) == "testsuite"]


def parse(report: Path) -> dict:
    tree = ET.parse(report)
    root = tree.getroot()
    suites: list[dict] = []
    for suite in _suites(root):
        cases = [
            {
                "name": case.get("name", ""),
                "suite": suite.get("name", suite.get("package", "")),
                "time": _seconds(case.get("time")),
            }
            for case in suite
            if _local(case.tag) == "testcase"
        ]
        case_time = sum(case["time"] for case in cases)
        total = _seconds(suite.get("time"))
        suites.append({
            "name": suite.get("name") or suite.get("package") or "<unnamed>",
            "package": suite.get("package", ""),
            "time": total,
            "case_time": case_time,
            "fixed_overhead": max(total - case_time, 0.0),
            "cases": len(cases),
            "failures": int(suite.get("failures", 0) or 0),
            "errors": int(suite.get("errors", 0) or 0),
            "skipped": int(suite.get("skipped", 0) or 0),
        })

    suite_time = sum(s["time"] for s in suites)
    case_time = sum(s["case_time"] for s in suites)
    return {
        "report": str(report),
        "suites": suites,
        "total_suite_time": suite_time,
        "total_case_time": case_time,
        "fixed_overhead": max(suite_time - case_time, 0.0),
        "total_cases": sum(s["cases"] for s in suites),
        "failed_suites": sum(1 for s in suites if s["failures"] or s["errors"]),
    }


def _collect_cases(report: Path) -> list[dict]:
    """Every `<testcase>` with its owning suite, sorted by time."""
    root = ET.parse(report).getroot()
    cases: list[dict] = []
    for suite in _suites(root):
        name = suite.get("name") or suite.get("package") or "<unnamed>"
        for case in suite:
            if _local(case.tag) == "testcase":
                cases.append({
                    "name": case.get("name", ""),
                    "suite": name,
                    "time": _seconds(case.get("time")),
                })
    return sorted(cases, key=lambda c: c["time"], reverse=True)


def analyse(report: Path, top: int = 15) -> dict:
    data = parse(report)
    data["slowest_cases"] = _collect_cases(report)[:top]
    data["suites"] = sorted(data["suites"], key=lambda s: s["time"], reverse=True)
    return data


def _share(part: float, whole: float) -> str:
    return f"{100.0 * part / whole:5.1f}%" if whole > 0.0 else "    -"


def print_report(data: dict, top: int) -> None:
    total = data["total_suite_time"]
    print(f"Profile: {data['report']}")
    print(f"Suites: {len(data['suites'])} | cases: {data['total_cases']} | "
          f"suite time: {total:.1f} s | case time: {data['total_case_time']:.1f} s | "
          f"fixed setup: {data['fixed_overhead']:.1f} s "
          f"({_share(data['fixed_overhead'], total).strip()})")
    if data["failed_suites"]:
        print(f"Suites with failures/errors: {data['failed_suites']}")

    print("\nSlowest suites:")
    print(f"  {'#':>3}  {'time':>9}  {'share':>6}  {'cases':>5}  "
          f"{'ms/case':>8}  {'setup':>7}  suite")
    for index, suite in enumerate(data["suites"][:top], 1):
        per_case = (1000.0 * suite["time"] / suite["cases"]) if suite["cases"] else 0.0
        print(f"  {index:>3}  {suite['time']:>8.2f}s  {_share(suite['time'], total):>6}  "
              f"{suite['cases']:>5}  {per_case:>8.1f}  "
              f"{suite['fixed_overhead']:>6.2f}s  {suite['package'] or suite['name']}")

    setup = sorted(data["suites"], key=lambda s: s["fixed_overhead"], reverse=True)
    if any(s["fixed_overhead"] > 0.0 for s in setup):
        print("\nMost fixed setup (suite time minus its cases):")
        print(f"  {'#':>3}  {'setup':>9}  {'share':>6}  {'time':>9}  suite")
        for index, suite in enumerate(setup[:top], 1):
            if suite["fixed_overhead"] <= 0.0:
                break
            print(f"  {index:>3}  {suite['fixed_overhead']:>8.2f}s  "
                  f"{_share(suite['fixed_overhead'], suite['time']):>6}  "
                  f"{suite['time']:>8.2f}s  {suite['package'] or suite['name']}")

    if data["slowest_cases"]:
        print("\nSlowest cases:")
        for index, case in enumerate(data["slowest_cases"], 1):
            print(f"  {index:>3}  {case['time']:>8.2f}s  {case['suite']}::{case['name']}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT_DIR,
                        help="results.xml, or a directory to search (default: game/reports)")
    parser.add_argument("--top", type=int, default=15, help="rows per table (default 15)")
    parser.add_argument("--json", action="store_true", help="print JSON instead of tables")
    parser.add_argument("--output", type=Path, help="also write the JSON report here")
    parser.add_argument("--require", action="store_true",
                        help="fail when no report exists (default: say so and pass)")
    parser.add_argument("--fail-over", type=float, default=0.0, metavar="SECONDS",
                        help="exit 1 when total suite time exceeds this")
    args = parser.parse_args(argv)

    path = find_report(args.report)
    if path is None:
        message = f"no gdUnit JUnit report found under {args.report}"
        if args.require:
            print(f"error: {message}", file=sys.stderr)
            return 1
        print(message)
        return 0

    data = analyse(path, args.top)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(data, indent=2))
    else:
        print_report(data, args.top)

    if args.fail_over > 0.0 and data["total_suite_time"] > args.fail_over:
        print(f"error: suite time {data['total_suite_time']:.1f}s exceeds "
              f"--fail-over {args.fail_over:.1f}s", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
