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


def main(prefix):
    beauty = np.asarray(Image.open(prefix + "_beauty.png").convert("RGB")) / 255.0
    lum = luminance(beauty)
    region = masks(Image.open(prefix + "_mask.png"))

    values = {}
    print(f"{prefix}  {beauty.shape[1]}x{beauty.shape[0]}")
    for name, mask in region.items():
        if mask.sum() == 0:
            print(f"  {name:14} NOT VISIBLE (0 px) — check the pose or camera")
            return 2
        values[name] = float(lum[mask].mean())
        print(f"  {name:14} L={values[name]:.3f}  ({int(mask.sum())} px)")

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
