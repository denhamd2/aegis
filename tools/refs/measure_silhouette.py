#!/usr/bin/env python3
"""Read VISUAL_BAR.md's silhouette-separation numbers off one of our frames.

Usage:
    measure_silhouette.py <prefix>       # reads <prefix>_beauty.png + _mask.png

`game/tools/refs/capture_silhouette.gd` writes the pair. The mask paints the
mat and each wrestler a flat key colour; this averages the beauty frame inside
each key and reports the same three pairings VISUAL_BAR.md tabulates off
`frames/wide_standoff_broadcast_angle.jpg`.

Why this exists alongside measure_frame.py's --region: a rectangle drawn over
a wrestler also catches mat, rope and shadow, so a per-subject average taken
that way is not the same measurement the reference table holds. The mask makes
the two comparable.

It also prints the mat's own luminance, which is the part that turned out to
matter: the reference mat renders at 0.46, and a wrestler cannot sit 0.24-0.31
*below* a mat that renders darker than that. The separation the bar asks for is
bounded by the mat, so the mat's number has to be read at the same time.
"""

import sys

import numpy as np
from PIL import Image

# VISUAL_BAR.md, measured off frames/wide_standoff_broadcast_angle.jpg.
# The mat entry is an exposure anchor rather than a bar: the reference number
# is a single reading off one broadcast frame, so it gets a tolerance instead
# of being asked for to three decimal places. It matters because the wrestler
# deltas below are absolute luminances, and comparing those across two
# differently-exposed images only means anything once the brightest shared
# surface is matched.
REFERENCE = {
    "mat luminance": (0.43, 0.49),
    "mat <-> wrestler": (0.24, 0.31),
    "wrestler <-> wrestler": (0.00, 0.07),
}

KEYS = {"mat": (0, 0, 255), "wrestler_a": (255, 0, 0), "wrestler_b": (0, 255, 0)}
# PNG round-trip is lossless, but the unshaded key still antialiases at silhouette
# edges; requiring the keyed channel to dominate keeps edge pixels out.
DOMINANCE = 160

# A standing man is taller than he is wide. Measured at this framing: wrestler
# A's keyed region is 76 x 175 px (h/w 2.3) and B's is 95 x 187 (h/w 2.0).
#
# This is here because a key once caught something that was not a wrestler and
# nothing noticed for a whole round. MatchHUD's VITALITY_GREEN is
# Color(0.24, 0.72, 0.28) = (61, 184, 71), whose green channel clears
# DOMINANCE while red and blue stay under half of it -- so the two health bars
# and the momentum strip keyed as wrestler B. 8,358 px of flat UI against
# 7,828 px of actual man, reading 0.357 against his real 0.186. mat<->B was
# reported at 0.139 against a true 0.227 and A<->B at 0.131 against 0.042.
#
# The pixel COUNT did not catch it, and that is the lesson: the count was
# stable across runs, which was read as proof the key was clean. A stable
# contaminant is stable. The SHAPE catches it -- the contaminated region was
# 1202 x 424, an aspect ratio of 0.35, which is not a man however many pixels
# he is. A generous floor, because the gate only has to separate a figure from
# a full-width band.
MIN_SUBJECT_ASPECT = 1.2


def linearise(srgb):
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    lin = linearise(rgb)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def masks(mask_img):
    px = np.asarray(mask_img.convert("RGB")).astype(int)
    out = {}
    for name, key in KEYS.items():
        channel = int(np.argmax(key))
        others = [i for i in range(3) if i != channel]
        out[name] = (px[..., channel] > DOMINANCE) & np.all(
            px[..., others] < DOMINANCE // 2, axis=-1
        )
    return out


def bbox(mask):
    """(x0, y0, w, h) of the keyed region, or None if nothing is keyed."""
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(
        ys.max() - ys.min() + 1)


def main(prefix):
    beauty = np.asarray(Image.open(prefix + "_beauty.png").convert("RGB")) / 255.0
    lum = luminance(beauty)
    region = masks(Image.open(prefix + "_mask.png"))

    values = {}
    contaminated = []
    print(f"{prefix}  {beauty.shape[1]}x{beauty.shape[0]}")
    for name, mask in region.items():
        if mask.sum() == 0:
            print(f"  {name:14} NOT VISIBLE (0 px) — check the pose or camera")
            return 2
        values[name] = float(lum[mask].mean())
        box = bbox(mask)
        print(f"  {name:14} L={values[name]:.3f}  ({int(mask.sum())} px)"
              f"  box {box[2]}x{box[3]} at ({box[0]},{box[1]})")
        # The mat is a floor and is legitimately wider than it is tall; only
        # the two subjects have to be man-shaped.
        if name.startswith("wrestler") and box[3] < MIN_SUBJECT_ASPECT * box[2]:
            contaminated.append(
                f"{name}: {box[2]}x{box[3]} (h/w {box[3] / box[2]:.2f}) is not "
                "a standing figure — something else in the frame is passing "
                "this key")

    if contaminated:
        print()
        for line in contaminated:
            print(f"  CONTAMINATED  {line}")
        print("\n  Every number below is an average over that region, so none "
              "of them mean\n  what they say. Find what is keying and take it "
              "out of the frame.")
        return 3

    def verdict(label, value):
        lo, hi = REFERENCE[label]
        if value < lo:
            return f"BELOW reference {lo:.2f}-{hi:.2f}"
        if value > hi:
            return f"ABOVE reference {lo:.2f}-{hi:.2f}"
        return f"inside reference {lo:.2f}-{hi:.2f}"

    print()
    print(f"  mat luminance          {values['mat']:.3f}   "
          f"{verdict('mat luminance', values['mat'])}")
    for who in ("wrestler_a", "wrestler_b"):
        d = abs(values["mat"] - values[who])
        print(f"  mat <-> {who:12} {d:.3f}   {verdict('mat <-> wrestler', d)}")
    d = abs(values["wrestler_a"] - values["wrestler_b"])
    print(f"  wrestler <-> wrestler  {d:.3f}   {verdict('wrestler <-> wrestler', d)}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
