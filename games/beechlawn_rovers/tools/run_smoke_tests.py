#!/usr/bin/env python3
"""Run the Beechlawn smoke checks serially with a hard per-test timeout.

Usage:
  python3 tools/run_smoke_tests.py
  python3 tools/run_smoke_tests.py milestone1_smoke.gd passing_smoke.gd

Set BEECHLAWN_TEST_TIMEOUT_SECONDS or GODOT_BIN to override defaults. A timed
out test and its child processes are terminated so a stalled headless Godot
instance cannot leave the command chain running indefinitely.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")
TIMEOUT = float(os.environ.get("BEECHLAWN_TEST_TIMEOUT_SECONDS", "45"))
# The full match permits 300 simulated seconds including stoppages at 6x speed:
# its 50-second wall-clock ceiling before CPU overhead exceeds the short tests.
LONG_TEST_TIMEOUTS = {"eleven_v_eleven_match_soak.gd": 75.0}
DEFAULT_TESTS = [
    "footballer_animation_tree_smoke.gd",
    "milestone1_smoke.gd",
    "football_kick_contact_integration_smoke.gd",
    "football_receive_contact_smoke.gd",
    "football_shot_contact_integration_smoke.gd",
]


def stop_process_group(process: subprocess.Popen[str]) -> None:
    if os.name == "posix":
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=3)
            return
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    else:
        process.kill()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass


def main() -> int:
    names = sys.argv[1:] or DEFAULT_TESTS
    for name in names:
        if Path(name).name != name or not name.endswith(".gd"):
            print(f"Expected a smoke-test filename, got: {name}", file=sys.stderr)
            return 2
        test_path = PROJECT / "tests" / name
        if not test_path.is_file():
            print(f"Smoke test not found: {test_path}", file=sys.stderr)
            return 2
        command = [GODOT, "--headless", "--path", str(PROJECT), "--script", f"res://tests/{name}"]
        timeout = TIMEOUT if "BEECHLAWN_TEST_TIMEOUT_SECONDS" in os.environ else LONG_TEST_TIMEOUTS.get(name, TIMEOUT)
        print(f"\n[smoke] {name} (timeout {timeout:g}s)", flush=True)
        process = subprocess.Popen(
            command,
            cwd=PROJECT,
            start_new_session=(os.name == "posix"),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
        )
        try:
            output, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            stop_process_group(process)
            output, _ = process.communicate()
            if output:
                print("\n".join(output.splitlines()[-60:]))
            print(f"[timeout] {name} exceeded {timeout:g}s; process group terminated", file=sys.stderr)
            return 124
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        result = process.returncode
        if result != 0:
            print(f"[failed] {name} exited {result}", file=sys.stderr)
            return result or 1
        failure_markers = ("SCRIPT ERROR:", "Assertion failed", "ERROR: Failed to load")
        if any(marker in output for marker in failure_markers):
            print(f"[failed] {name} reported a Godot script/load error", file=sys.stderr)
            return 1
        print(f"[passed] {name}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
