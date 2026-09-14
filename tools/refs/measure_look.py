#!/usr/bin/env python3
"""Placement-free look comparison: the luminance DISTRIBUTION and the colour
spread of a whole frame.

  measure_look.py <image> [<image> ...]

Why this exists alongside measure_frame.py
------------------------------------------
measure_frame.py reads named RECTANGLES, which is the right tool once you
know where the mat and the wrestlers are. It is the wrong tool for "does our
arena look like a televised one", because the answer does not live in any
one region -- it lives in how the whole frame is distributed. Hand-placing
rectangles on a reference photo also produces soft numbers: the first attempt
at this measured a "mat" patch on an AEW still at sd 0.234, which is a
rectangle straddling three different things.

What it measures, and what each number means
--------------------------------------------
  p50/p90/p99   Luminance percentiles (Rec. 709 on linearised sRGB). A
                broadcast arena is mostly dark with a small very bright
                fraction, so p50 sits near black and p99 near clipping.
  bright>0.5    Fraction of frame that is a light source or lit by one.
  dark<0.01     Fraction that is essentially black. THIS is the number that
                separates an arena from a lit box, and it is the one ours
                was furthest from: 38-50% on every AEW reference against
                1.9% on our own frame. Beams, haze and rim light have
                nothing to read against without it.
  mean sat      How coloured the frame is overall. The AEW look is saturated
                magenta/purple/blue wash almost everywhere.
  coloured      Fraction of pixels with saturation above 0.25.

Measured on gauntlet/refs/lighting/ (see that directory's lighting.md).
"""
import argparse
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover - tooling, not gameplay
    print("measure_look.py needs pillow and numpy: pip install pillow numpy",
          file=sys.stderr)
    raise SystemExit(1)

## The reference set this was calibrated against.
REFS = "gauntlet/refs/lighting"


def _linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def measure(path):
    im = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    r, g, b = _linear(im[..., 0]), _linear(im[..., 1]), _linear(im[..., 2])
    luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
    high = im.max(axis=2)
    low = im.min(axis=2)
    sat = np.where(high > 0, (high - low) / np.maximum(high, 1), 0.0)
    return {
        "p50": float(np.percentile(luma, 50)),
        "p90": float(np.percentile(luma, 90)),
        "p99": float(np.percentile(luma, 99)),
        "bright": float((luma > 0.5).mean()),
        "dark": float((luma < 0.01).mean()),
        "sat": float(sat.mean()),
        "coloured": float((sat > 0.25).mean()),
    }


def report(path, label=None):
    m = measure(path)
    print("%-30s  p50 %.4f  p90 %.4f  p99 %.4f  bright>0.5 %5.2f%%  "
          "dark<0.01 %5.2f%%  mean sat %.3f  coloured %5.1f%%"
          % (label or os.path.basename(path), m["p50"], m["p90"], m["p99"],
             100 * m["bright"], 100 * m["dark"], m["sat"],
             100 * m["coloured"]))
    return m


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("images", nargs="*", help="frames to measure")
    ap.add_argument("--refs", action="store_true",
                    help="also measure everything in %s" % REFS)
    args = ap.parse_args()

    if args.refs or not args.images:
        root = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(
                os.path.abspath(__file__)))), REFS)
        if os.path.isdir(root):
            print("=== %s ===" % REFS)
            for name in sorted(os.listdir(root)):
                if name.lower().endswith((".jpg", ".jpeg", ".png")):
                    report(os.path.join(root, name))
        if args.images:
            print()
    if args.images:
        print("=== measured ===")
        for path in args.images:
            report(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
