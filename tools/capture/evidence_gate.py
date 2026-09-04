#!/usr/bin/env python3
"""Evidence gate: validates a capture_manifest.json before any critic sees
the capture it describes. A round whose manifest fails this gate is void —
it never reaches a critic and never moves the ratchet, so a bad capture
costs nothing (per gauntlet/anchor/ARCHITECTURE.md).

Usage: evidence_gate.py [--visual] <capture_manifest.json>
Exit code 0 = pass, 1 = fail (with reasons on stderr).

--visual enforces ARCHITECTURE.md's renderer rule, which is about the
*pipeline*, not the rasteriser: a visual slice may only cite a capture
rendered through the rendering method the game ships (forward_plus). A
gl_compatibility capture has no SSAO, SSR, SDFGI or volumetric fog and
tonemaps differently, so its pixels are not the game's pixels and it is
void for a visual slice -- not a loss: the ratchet does not move and the
round is re-run on the right pipeline.

Whether a GPU or a CPU rasterised those pixels changes their speed, not
their values, so a software forward_plus capture passes --visual carrying a
recorded caveat. It does NOT support a performance claim: --performance
requires gpu_backed, because frame cost is precisely what a CPU rasteriser
gets wrong.

The earlier rule banned llvmpipe outright for visual slices. It conflated
those two defects, and the cost was measurable: priorities 2 and 3 of
VISUAL_BAR.md went unjudged for two full rounds because no admissible
capture could be produced at all.
"""
import argparse
import json
import sys

MIN_NON_BLACK_RATIO = 0.9

# The rendering method the game ships, per project.godot. A visual slice may
# only cite a capture rendered through it.
SHIPPING_PIPELINE = "forward_plus"


def check(manifest: dict, visual: bool = False,
          performance: bool = False) -> list[str]:
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
        pipeline = manifest.get("pipeline")
        if pipeline is None:
            failures.append(
                "manifest does not record a pipeline, so it cannot be judged "
                "against VISUAL_BAR.md — re-capture with a harness that "
                "records RenderingServer.get_current_rendering_method()"
            )
        elif pipeline != SHIPPING_PIPELINE:
            failures.append(
                f"capture rendered on {pipeline!r}, but the game ships "
                f"{SHIPPING_PIPELINE!r}: different tonemapping and no "
                "SSAO/SSR/SDFGI/volumetric fog, so these are not the game's "
                "pixels and this is void for a visual-quality slice"
            )

    if performance:
        if not manifest.get("gpu_backed", False):
            adapter = manifest.get("video_adapter", "unknown adapter")
            failures.append(
                f"software-rasterised capture ({adapter}) cannot support a "
                "performance claim — frame cost is exactly what a CPU "
                "rasteriser gets wrong"
            )

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest")
    parser.add_argument("--visual", action="store_true",
                        help="also require the shipping pipeline "
                             "(ring/materials/lighting slices)")
    parser.add_argument("--performance", action="store_true",
                        help="also require a GPU-backed capture "
                             "(any frame-cost claim)")
    args = parser.parse_args()

    with open(args.manifest) as f:
        manifest = json.load(f)

    failures = check(manifest, visual=args.visual,
                     performance=args.performance)
    if failures:
        print("EVIDENCE GATE: FAIL (round is void)", file=sys.stderr)
        for reason in failures:
            print(f"  - {reason}", file=sys.stderr)
        return 1

    pipeline = manifest.get("pipeline")
    if pipeline == SHIPPING_PIPELINE and manifest.get("gpu_backed"):
        print("EVIDENCE GATE: PASS (GPU-backed forward_plus — "
              "visual and performance claims may cite this)")
    elif pipeline == SHIPPING_PIPELINE:
        adapter = manifest.get("video_adapter", "unknown adapter")
        print(f"EVIDENCE GATE: PASS (forward_plus, software-rasterised on "
              f"{adapter} — visual slices may cite this; NO performance "
              f"claim may)")
    elif pipeline:
        print(f"EVIDENCE GATE: PASS ({pipeline} — timing/feel slices only)")
    else:
        print("EVIDENCE GATE: PASS (no pipeline recorded — "
              "timing/feel slices only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
