#!/usr/bin/env python3
"""Channel-level triage for a character model's texture set.

Every texture fault in the Roman import was visible in per-channel statistics
and invisible to the eye at thumbnail size: an albedo whose blue was pinned to
255 across the whole image, packed data maps wired into albedo slots, and two
strand masks whose coverage differed by 4x while both looked like "some hair".
Running this before writing any material code turns a week of render-and-guess
into one table.

Usage:
    python3 inspect_textures.py game/assets/characters/<prefix>*.png
    python3 inspect_textures.py --coverage game/assets/characters/*_alpha.png

What the classifications mean:

  PACKED DATA MAP   R and B carry near-identical data and G differs. This is a
                    mask packed into green, not a colour. Wired into an albedo
                    slot it renders magenta by definition (R=B high, G low).
                    Rebuild as white RGB + green as alpha, tint at runtime.

  NORMAL MAP        B high and flat, R and G centred near 128. Belongs in the
                    normal slot; harmless, just confirming.

  DAMAGED CHANNEL   A channel pinned to a constant, or clipped at both ends
                    across a large share of the image. The head albedo had blue
                    at 255 across 100% and red clipped across ~40%; only green
                    survived, so the face had to be reconstructed from it.

  COLOUR            Ordinary albedo. Nothing to do.

Coverage mode answers the question that actually decides how a strand card
looks: what fraction of the mask is opaque enough to survive the threshold.
Compare a suspect mask against one that already reads correctly on the same
model -- a beard drawn by the same artist for the same head is the right
control, an arbitrary number is not.
"""

import argparse
import pathlib
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

# R and B means within this many levels of each other, with G further away,
# is the packed-mask signature. Wide enough to catch compressed sources.
PACKED_RB_TOLERANCE = 8.0
# A channel whose full range collapses to this few levels is pinned, not dark.
PINNED_RANGE = 2
# Share of an image sitting at 0 or 255 before a channel counts as clipped.
CLIP_SHARE = 0.15
# Thresholds coverage mode reports, spanning the useful scissor range.
COVERAGE_STEPS = (0.004, 0.06, 0.10, 0.16, 0.30, 0.50)


def channel_stats(image):
    """Mean, min, max and clipped share per channel, on a downscale.

    Downscaling to 512 keeps a 4096x2048 atlas from costing seconds while
    preserving every statistic here -- all of them are distribution-wide, and
    none depends on individual texels. Read the comment in the loop before
    changing how the downscale is done; the obvious way silently zeroes data.
    """
    rgba = image.convert("RGBA")
    out = {}
    for name in "RGBA":
        # Each channel is downscaled on its own, as a grayscale image. Resizing
        # the RGBA image as a unit zeroes RGB wherever alpha is 0, which is
        # exactly the case here: a packed mask's own alpha is often empty, and
        # resizing first reported every one of these atlases as pure black.
        # Channels are being read as data, not as colour, so they must not go
        # through anything that treats alpha as transparency.
        channel = rgba.getchannel(name)
        channel.thumbnail((512, 512))
        histogram = channel.histogram()
        total = sum(histogram) or 1
        values = [i for i, count in enumerate(histogram) if count]
        out[name] = {
            "mean": sum(i * c for i, c in enumerate(histogram)) / total,
            "min": values[0] if values else 0,
            "max": values[-1] if values else 0,
            "clipped": (histogram[0] + histogram[255]) / total,
        }
    return out


def classify(stats, has_alpha):
    """Name the fault, and say what it implies for the material."""
    r, g, b = stats["R"], stats["G"], stats["B"]
    findings = []

    for name in "RGB":
        channel = stats[name]
        if channel["max"] - channel["min"] <= PINNED_RANGE:
            findings.append(
                f"DAMAGED CHANNEL: {name} is pinned at {channel['max']} across the "
                f"whole image -- it carries no information"
            )
        elif channel["clipped"] > CLIP_SHARE:
            findings.append(
                f"DAMAGED CHANNEL: {name} is clipped at one or both ends across "
                f"{channel['clipped']:.0%} of the image"
            )

    packed = (
        abs(r["mean"] - b["mean"]) < PACKED_RB_TOLERANCE
        and abs(r["mean"] - g["mean"]) > PACKED_RB_TOLERANCE * 2
    )
    normal = b["mean"] > 200 and 100 < r["mean"] < 160 and 100 < g["mean"] < 160

    if normal:
        findings.append("NORMAL MAP: belongs in the normal slot, not albedo")
    elif packed:
        findings.append(
            "PACKED DATA MAP: R and B match, G differs -- the mask is in GREEN. "
            "As albedo this renders magenta. Rebuild white RGB + G as alpha."
        )
    elif has_alpha and stats["A"]["max"] > 0:
        findings.append("HAS ALPHA: check coverage with --coverage before trusting it")

    if not findings:
        findings.append("COLOUR: ordinary albedo, nothing to repair")
    return findings


def coverage(image):
    """Fraction of texels at or above each alpha threshold.

    This is the number that decides whether a strand card reads as hair. A
    scissor can only ever draw what clears its threshold, so a mask with 9.6%
    coverage against a working one's 32% will look sparse no matter what
    threshold is chosen -- and lowering it recovers almost nothing, because
    there is barely anything in between. Coverage says whether the fix is a
    threshold change, a gamma lift, or new mask data.
    """
    channel = image.convert("RGBA").getchannel("A")
    channel.thumbnail((1024, 1024))
    histogram = channel.histogram()
    total = sum(histogram) or 1
    return {
        step: sum(histogram[int(step * 255):]) / total for step in COVERAGE_STEPS
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="+", type=pathlib.Path)
    parser.add_argument("--coverage", action="store_true",
                        help="report alpha coverage per threshold instead of "
                             "channel classification; use it to compare a "
                             "suspect mask against one that already works")
    args = parser.parse_args()

    if args.coverage:
        header = " ".join(
            ("  >0   " if step < 0.01 else f">={step:<5.2f}") for step in COVERAGE_STEPS)
        print(f"{'texture':<44} {header}")
        for path in args.paths:
            with Image.open(path) as image:
                values = coverage(image)
            row = " ".join(f"{values[s]:<7.4f}" for s in COVERAGE_STEPS)
            print(f"{path.name:<44} {row}")
        print("\nCompare like with like: a mask drawn by the same artist for the")
        print("same head is the control. A large gap at >=0.50 with a small gap")
        print("at >0 means the strands exist but are too faint -- an alpha gamma")
        print("lifts them. A large gap at >0 too means the coverage genuinely is")
        print("not there, and no threshold, gamma or blend mode can add it;")
        print("interleaving shifted copies of the mask can, dilation cannot")
        print("(past a couple of texels dilation renders strands as a slab).")
        return

    for path in args.paths:
        with Image.open(path) as image:
            has_alpha = image.mode in ("RGBA", "LA") or "transparency" in image.info
            stats = channel_stats(image)
            size = image.size
        print(f"\n{path.name}  {size[0]}x{size[1]}")
        for name in "RGBA":
            channel = stats[name]
            print(f"  {name}  mean={channel['mean']:6.1f}  range={channel['min']:3d}-"
                  f"{channel['max']:3d}  clipped={channel['clipped']:.1%}")
        for finding in classify(stats, has_alpha):
            print(f"  -> {finding}")


if __name__ == "__main__":
    main()
