#!/usr/bin/env python3
"""Measure a frame the way VISUAL_BAR.md's first two priorities are worded.

ARCHITECTURE.md's reference-driven-tuning rule says a visual claim must
trace to something measured under gauntlet/refs/. "Silhouette readability at
match-camera distance" was not measurable that way -- it was a phrase a
critic had to judge by eye, which is exactly the kind of claim the rule
exists to stop. This turns it into a number that can be taken off a
reference still and off one of our own captures with the same code.

Two measurements, both renderer-independent (they read albedo/value, not
shading quality -- see ARCHITECTURE.md on llvmpipe captures):

  separation  Relative luminance (Rec. 709, on linearised sRGB) of named
              regions, and the pairwise gaps between them. A wrestler is
              legible against the mat when that gap is large.
  void        Fraction of the frame that is flat, featureless background --
              pixels below a luminance floor. A real arena frame has very
              dark regions, but they are *textured*; a modelled-nothing
              background has zero variance.

Usage:
  measure_frame.py <image> --region name=x0,y0,x1,y1 [--region ...]
  measure_frame.py <image> --void
"""
import argparse
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover - tooling, not gameplay
    print("measure_frame.py needs pillow and numpy: pip install pillow numpy",
          file=sys.stderr)
    raise SystemExit(1)

# A pixel at or below this luminance reads as background rather than as
# anything modelled. Set just above the arena Environment's own background
# colour (0.02 sRGB grey -> ~0.0021 linear) so the empty hall counts as void.
VOID_LUMA = 0.0025
# Below this, a region is flat enough that nothing in it is legible at all.
VOID_FLATNESS = 0.002


def _linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(pixels):
    lin = _linear(pixels)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0


def region_luma(frame, box):
    x0, y0, x1, y1 = box
    lum = luminance(frame[y0:y1, x0:x1])
    return float(lum.mean()), float(lum.std())


def void_fraction(frame):
    """Share of the frame that is both dark and flat."""
    lum = luminance(frame)
    dark = lum < VOID_LUMA
    return float(dark.mean()), float(lum.std())


def _parse_region(text):
    name, _, box = text.partition("=")
    coords = tuple(int(v) for v in box.split(","))
    if len(coords) != 4:
        raise argparse.ArgumentTypeError(f"region {name!r} needs x0,y0,x1,y1")
    return name, coords


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image")
    parser.add_argument("--region", type=_parse_region, action="append", default=[],
                        help="name=x0,y0,x1,y1 (repeatable)")
    parser.add_argument("--void", action="store_true",
                        help="report the flat-background fraction of the frame")
    args = parser.parse_args()

    frame = load(args.image)
    h, w = frame.shape[:2]
    print(f"{args.image}  {w}x{h}")

    measured = {}
    for name, box in args.region:
        mean, sd = region_luma(frame, box)
        measured[name] = mean
        print(f"  {name:22s} L={mean:.3f}  sd={sd:.3f}")

    names = list(measured)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            print(f"  dL {a} <-> {b}: {abs(measured[a] - measured[b]):.3f}")

    if args.void:
        fraction, sd = void_fraction(frame)
        flat = " (flat: nothing modelled there)" if sd < VOID_FLATNESS else ""
        print(f"  void_fraction          {fraction:.3f}  frame_sd={sd:.3f}{flat}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
