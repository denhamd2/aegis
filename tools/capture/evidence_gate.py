#!/usr/bin/env python3
"""Evidence gate: validates a capture_manifest.json before any critic sees
the capture it describes. A round whose manifest fails this gate is void —
it never reaches a critic and never moves the ratchet, so a bad capture
costs nothing (per gauntlet/anchor/ARCHITECTURE.md).

Usage: evidence_gate.py [--visual] <capture_manifest.json>
Exit code 0 = pass, 1 = fail (with reasons on stderr).

--visual additionally enforces ARCHITECTURE.md's renderer rule: "llvmpipe
captures are sufficient for timing and feel slices only. Ring/materials/
lighting critics need GPU-backed captures." That rule had nothing enforcing
it -- the manifest did not record which renderer produced the capture, so
"confirm the capture was GPU-backed" (VISUAL_BAR.md) rested entirely on
whoever ran it remembering how they ran it. A software-rendered capture is
void for a visual slice, not a loss: the ratchet does not move, and the
round is re-run on hardware that has a GPU.
"""
import argparse
import json
import sys

MIN_NON_BLACK_RATIO = 0.9


def check(manifest: dict, visual: bool = False) -> list[str]:
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

    if visual:
        if "gpu_backed" not in manifest:
            failures.append(
                "manifest does not record a renderer, so it cannot be judged "
                "against VISUAL_BAR.md — re-capture with a harness that does"
            )
        elif not manifest["gpu_backed"]:
            adapter = manifest.get("video_adapter", "unknown adapter")
            failures.append(
                f"software-rendered capture ({adapter}): "
                "ARCHITECTURE.md allows llvmpipe for timing and feel slices "
                "only, so this is void for a visual-quality slice"
            )

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest")
    parser.add_argument("--visual", action="store_true",
                        help="also require a GPU-backed capture "
                             "(ring/materials/lighting slices)")
    args = parser.parse_args()

    with open(args.manifest) as f:
        manifest = json.load(f)

    failures = check(manifest, visual=args.visual)
    if failures:
        print("EVIDENCE GATE: FAIL (round is void)", file=sys.stderr)
        for reason in failures:
            print(f"  - {reason}", file=sys.stderr)
        return 1

    if manifest.get("gpu_backed"):
        print("EVIDENCE GATE: PASS (GPU-backed — visual slices may cite this)")
    elif "gpu_backed" in manifest:
        print("EVIDENCE GATE: PASS (software render — timing/feel slices only)")
    else:
        print("EVIDENCE GATE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
