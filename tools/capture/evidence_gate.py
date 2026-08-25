#!/usr/bin/env python3
"""Evidence gate: validates a capture_manifest.json before any critic sees
the capture it describes. A round whose manifest fails this gate is void —
it never reaches a critic and never moves the ratchet, so a bad capture
costs nothing (per gauntlet/anchor/ARCHITECTURE.md).

Usage: evidence_gate.py <capture_manifest.json>
Exit code 0 = pass, 1 = fail (with reasons on stderr).
"""
import json
import sys

MIN_NON_BLACK_RATIO = 0.9


def check(manifest: dict) -> list[str]:
    failures = []

    expected = manifest.get("expected_frame_count")
    actual = manifest.get("actual_frame_count")
    if expected is None or actual is None:
        failures.append("manifest missing expected_frame_count/actual_frame_count")
    elif actual != expected:
        failures.append(f"frame count mismatch: expected {expected}, got {actual}")

    ratio = manifest.get("non_black_frame_ratio")
    if ratio is None:
        failures.append("manifest missing non_black_frame_ratio")
    elif ratio < MIN_NON_BLACK_RATIO:
        failures.append(f"non_black_frame_ratio {ratio} below minimum {MIN_NON_BLACK_RATIO}")

    if not manifest.get("hud_present", False):
        failures.append("hud_present is false")

    if not manifest.get("replay_end_state_hash"):
        failures.append("manifest missing replay_end_state_hash")

    return failures


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1

    with open(sys.argv[1]) as f:
        manifest = json.load(f)

    failures = check(manifest)
    if failures:
        print("EVIDENCE GATE: FAIL (round is void)", file=sys.stderr)
        for reason in failures:
            print(f"  - {reason}", file=sys.stderr)
        return 1

    print("EVIDENCE GATE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
