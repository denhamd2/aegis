#!/usr/bin/env python3
"""Skin brightness and sheen, over a skin mask.

  measure_skin.py <image> [<image> ...]

Why this exists
---------------
`gauntlet/refs/cody_roman_2k26.md` measures 2K26's in-ring wrestlers as
"an R>G>B skin mask, as linear luminance inside the ring area" and pins the
numbers the look is judged against:

  |      | Skin mean | Skin p95  |
  | 2K26 | 0.20-0.27 | 0.49-0.65 |
  | Ours | 0.28-0.36 | 0.76      |

That measurement was made by hand and no script was left behind, so every
later sweat and lighting round has had to re-derive it or argue from the
constants. This is it, written down.

What it measures
----------------
  skin %    Fraction of the frame the mask caught. A close-up from
            tools/probe/skin_shot.tscn is mostly skin; a wide ring shot is
            not, and a very low number means the mask found nothing and the
            rest of the row is noise.
  mean      Linear (Rec. 709 on linearised sRGB) luminance over the mask.
            How bright the man is.
  p95       The highlight. THIS is the sweat number: a film of water does
            not move the mean much, it adds a bright specular top end. 2K26
            sits at 0.49-0.65; ours read 0.76 before SWEAT_COAT was halved.
  p99       The hottest edge of the highlight, for spotting a blown patch
            that p95 averages away.
  spec %    Fraction of the mask brighter than 0.5 linear -- the actual area
            the sheen covers, which is what reads as "too sweaty" at normal
            viewing distance rather than any single percentile.

The mask is R>G>B with a floor, which is what the reference used: skin is
warm and ordered red-green-blue almost everywhere, and the mat, ropes and
crowd here are not. It is deliberately crude; it is a comparison tool, and
both sides of the comparison are measured the same way.
"""
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("needs numpy and pillow: pip install numpy pillow")

# Below this the pixel is in shadow and its channel order is noise.
FLOOR = 0.04
# How much redder than blue a pixel must be to count as skin.
WARMTH = 1.12


def linearise(srgb):
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def measure(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    lin = linearise(rgb)
    r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
    luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
    mask = (r > g) & (g > b) & (r > b * WARMTH) & (luma > FLOOR)
    if mask.sum() < 64:
        return {"skin": mask.mean(), "mean": 0.0, "p95": 0.0, "p99": 0.0, "spec": 0.0}
    skin = luma[mask]
    return {
        "skin": mask.mean(),
        "mean": skin.mean(),
        "p95": np.percentile(skin, 95),
        "p99": np.percentile(skin, 99),
        "spec": (skin > 0.5).mean(),
    }


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__.strip().splitlines()[2].strip())
    print("%-34s %6s %6s %6s %6s %6s" % ("image", "skin%", "mean", "p95", "p99", "spec%"))
    for path in argv[1:]:
        m = measure(path)
        print("%-34s %5.1f%% %6.3f %6.3f %6.3f %5.1f%%" % (
            path.split("/")[-1], m["skin"] * 100.0, m["mean"], m["p95"], m["p99"],
            m["spec"] * 100.0))
    print("\n2K26 in-ring reference (cody_roman_2k26.md): mean 0.20-0.27, p95 0.49-0.65")


if __name__ == "__main__":
    main(sys.argv)
