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
import selectors
import subprocess
import sys
import time
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")
TIMEOUT = float(os.environ.get("BEECHLAWN_TEST_TIMEOUT_SECONDS", "45"))
# Full matches preserve a 60 Hz gameplay step. Asset startup is bounded
# separately so a cold load cannot consume the simulation budget. Selection
# checks construct ten complete scenes and retain their own single deadline.
LONG_TEST_TIMEOUTS = {"eleven_v_eleven_match_soak.gd": 120.0, "full_presentation_match_soak.gd": 180.0,
                     "ball_selection_smoke.gd": 90.0}  # Eight full match/intro/replay assemblies.
DEFAULT_TESTS = [
    "wet_weather_smoke.gd",
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


def monitor_process(process, timeout, live=False, startup_timeout=None):
    """Detect a failed GDScript immediately: assert() need not exit SceneTree."""
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    started = time.monotonic()
    awaiting_ready = startup_timeout is not None
    deadline = started + (startup_timeout if awaiting_ready else timeout)
    hard_deadline = started + timeout + (startup_timeout or 0)
    output = bytearray()
    status = 'complete'
    fatal = (b'SCRIPT ERROR:', b'Assertion failed', b'ERROR: Failed to load', b'SHADER ERROR:', b'ERROR: Shader compilation failed', b'ERROR: Condition', b'ERROR: AnimationPlayer has no current animation')
    try:
        while True:
            if time.monotonic() >= deadline:
                if status == 'complete':
                    status = 'timeout'
                    stop_process_group(process)
                break
            ready = selector.select(min(.25, max(0, deadline-time.monotonic())))
            if not ready:
                continue
            chunk = os.read(process.stdout.fileno(), 65536)
            if not chunk:
                break
            output.extend(chunk)
            if live:
                print(chunk.decode(errors="replace"), end="", flush=True)
            if awaiting_ready and b'BEECHLAWN_MATCH_READY actors=22 officials=1 ' in output:
                awaiting_ready = False
                deadline = min(hard_deadline, time.monotonic()+timeout)
                if live:
                    print(f'[ready] startup={time.monotonic()-started:.1f}s; simulation deadline {timeout:g}s',flush=True)
            if status == 'complete' and any(marker in output for marker in fatal):
                status = 'error'
                stop_process_group(process)
                deadline = time.monotonic() + 1
        process.wait(timeout=3)
        if status == 'complete' and awaiting_ready:
            output.extend(b'\nERROR: Match never reached its ready marker\n')
            status = 'error'
    finally:
        selector.close()
        process.stdout.close()
    return output.decode(errors='replace'), status


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
        if name in {"eleven_v_eleven_match_soak.gd", "full_presentation_match_soak.gd"}:
            # Replay with six 60 Hz simulation steps per draw, independent of
            # host wall-clock throughput. Keep gameplay dt and chance gates.
            command[2:2] = ["--fixed-fps", "60"]
        venue = os.environ.get("BEECHLAWN_TEST_VENUE", "kilmore_drive")
        if venue not in {"kilmore_drive", "rovers_arena"}:
            raise ValueError("Unknown test venue: " + venue)
        command += ["--", "--venue=" + venue]
        timeout = TIMEOUT if "BEECHLAWN_TEST_TIMEOUT_SECONDS" in os.environ else LONG_TEST_TIMEOUTS.get(name, TIMEOUT)
        print(f"\n[smoke] {name} (timeout {timeout:g}s)", flush=True)
        if name in {"eleven_v_eleven_match_soak.gd", "full_presentation_match_soak.gd"}:
            print("[replay] fixed render cadence 60 Hz; gameplay dt 1/60 s", flush=True)
        started = time.monotonic()
        process = subprocess.Popen(
            command,
            cwd=PROJECT,
            start_new_session=(os.name == "posix"),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
        )
        live = name in LONG_TEST_TIMEOUTS
        # Cold asset loading has a separate hard bound. It cannot consume or
        # extend the unchanged simulation budget; repeated ready lines cannot
        # renew either deadline. Explicit timeout overrides retain old semantics.
        startup_timeout = 90 if name in {'eleven_v_eleven_match_soak.gd','full_presentation_match_soak.gd'} and 'BEECHLAWN_TEST_TIMEOUT_SECONDS' not in os.environ else None
        output, state = monitor_process(process, timeout, live=live, startup_timeout=startup_timeout)
        if state == 'timeout':
            if output:
                print("\n".join(output.splitlines()[-60:]))
            print(f"[timeout] {name} exceeded {timeout:g}s; process group terminated", file=sys.stderr)
            return 124
        if state == 'error':
            print(output[-8000:])
            print(f"[failed] {name} reported a script/assertion failure; stopped immediately", file=sys.stderr)
            return 1
        if output and not live:
            print(output, end="" if output.endswith("\n") else "\n")
        result = process.returncode
        if result != 0:
            print(f"[failed] {name} exited {result}", file=sys.stderr)
            return result or 1
        failure_markers = ("SCRIPT ERROR:", "Assertion failed", "ERROR: Failed to load", "SHADER ERROR:", "ERROR: Shader compilation failed")
        if any(marker in output for marker in failure_markers):
            print(f"[failed] {name} reported a Godot script/load error", file=sys.stderr)
            return 1
        print(f"[passed] {name} ({time.monotonic()-started:.1f}s)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
