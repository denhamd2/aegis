#!/usr/bin/env python3
"""Builds alpha-masked hair/beard textures for the Roman Reigns model.

The supplied model's hair and beard meshes are alpha cards, and the export
wired their *packed data* maps in as base colour. Those maps -- hair_rai,
hair_rai_4 and combinations_rai -- are not albedo at all: R and B carry
identical data (mean 122.4 each in hair_rai) and the **green channel is the
strand opacity mask**. Fed to a renderer as albedo with no alpha, R=B high
against low G is literally the definition of magenta, which is why every hair
card on the model renders as a solid magenta blob.

There is no hair colour texture anywhere in the asset -- not embedded in the
.glb (14 images, all accounted for) and not among the loose PNGs. So the
colour has to come from a tint, and what these files supply is the mask.

This writes, for each source atlas, an RGBA PNG with white RGB and the source's
green channel as alpha. White RGB means the material's albedo_color does the
tinting, so hair colour stays a one-line change in roman_model.gd rather than
something baked into a 2048x2048 texture.

Usage:  python3 tools/assets/build_roman_hair_alpha.py
Outputs are written next to their sources in game/assets/characters/.
"""

import pathlib
import sys

try:
    from PIL import Image, ImageChops, ImageFilter
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

CHARACTERS = pathlib.Path(__file__).resolve().parents[2] / "game/assets/characters"

## How much of the source's tonal range to keep when rebuilding the head
## albedo. 1.0 is the raw ratio, which reads as bruising; see build_head().
CONTRAST = 0.42
## Floor under the darkest texels, so baked occlusion shades rather than
## punches holes.
LIFT = 0.30

# source atlas -> generated alpha-masked texture
## Alpha gamma per generated mask. 1.0 leaves the source untouched.
##
## The beard needs it and the scalp does not, and the masks say why. Fraction
## of texels at or above a given alpha:
##
##                  >=0.50   >0      opaque share of what exists
##   hair_alpha      0.320   0.409   78%
##   beard_alpha     0.096   0.158   61%
##
## Only 9.6% of the beard mask is half-opaque or better against 15.8% that is
## non-zero: nearly 40% of its strands are ghosts. That is why the beard reads
## as scattered bristle high on the cheek rather than as the jawline the source
## model has -- the faint strands ARE in the right places, they are just too
## transparent to see, so the eye joins up only the strongest clumps.
##
## Gamma 0.55 lifts a 0.25 texel to 0.46 and a 0.5 to 0.68 while pinning 0 to 0
## and 255 to 255. No strand is invented and none is discarded; the ones the
## artist drew simply render at a weight you can see. The eyebrows live in this
## same mask and are sparser than the jaw, which is why they were missing
## altogether.
BEARD_GAMMA = 0.55

## Strand dilation for the beard mask, in texels (odd, 0 = off).
##
## Superseded by BEARD_INTERLEAVE below and left at 0. Kept because the
## measurement it produced is the reason interleaving exists: dilation makes
## each strand FATTER, and past a very small radius that is how you get a
## moustache rendered as a solid slab (7 was tried, and looked exactly like
## that). It cannot add strands, only weight.
BEARD_DILATE = 0

## Horizontal offsets, in texels, at which to composite extra copies of the
## beard mask over itself.
##
## This is the repaint, done arithmetically rather than by hand. The problem
## was never that the beard's strands were in the wrong place -- measured
## against the mouth and eye lines, the mesh spans exactly where a beard,
## moustache and brow mesh should. The problem is that there are not enough of
## them: 15.8% of the mask is non-zero against the scalp mask's 40.9%, drawn
## by the same artist for the same head, so the jaw reads as scattered bristle
## next to a full head of hair.
##
## The atlas is a grid of strand cards whose hairs run vertically. Compositing
## the mask over horizontally-shifted copies of itself therefore lays a new
## hair into the gap beside each existing one, at the same length, curvature
## and taper, because it IS the same hair moved sideways. Every strand stays
## exactly as thin as it was drawn -- which is the difference between this and
## dilation, and the difference between a beard and a smear.
##
## Measured, at or above 0.5 alpha, against the scalp mask as the target:
##
##   hair_alpha (target)          0.3204
##   beard, untouched             0.0963
##   [-3, 3]                      0.2237
##   [-5, -2, 2, 5]  (chosen)     0.2917
##   [-7, -4, -2, 2, 4, 7]        0.3454   <- overshoots the scalp
##   [-9, -6, -3, 3, 6, 9]        0.3746
##
## Chosen to land just UNDER the scalp rather than over it: a beard denser
## than the head of hair above it reads as painted-on, and the offsets are
## small enough (max 5 texels of 2048) that bleed across card boundaries stays
## below one strand width.
BEARD_INTERLEAVE = (-5, -2, 2, 5)

SOURCES = {
    "roman_reigns_hair_rai.png": ("roman_reigns_hair_alpha.png", 1.0, 0, ()),
    "roman_reigns_hair_rai_4.png": (
        "roman_reigns_hair_4_alpha.png", 1.0, 0, ()),
    "roman_reigns_combinations_rai.png": (
        "roman_reigns_beard_alpha.png", BEARD_GAMMA, BEARD_DILATE,
        BEARD_INTERLEAVE),
}


def build(source: pathlib.Path, target: pathlib.Path, gamma: float = 1.0,
          dilate: int = 0, interleave: tuple = ()) -> None:
    image = Image.open(source).convert("RGBA")
    # Green is the strand mask; red and blue are the packed data we discard.
    mask = image.split()[1]
    if interleave:
        # Add strands BETWEEN the strands, rather than making each one fatter.
        # The atlas is a grid of strand cards whose hairs run vertically, so
        # compositing horizontally-shifted copies of the mask (lighter = per
        # texel max) drops a new hair into each gap while every hair stays as
        # thin as it was drawn. Shape and direction are the artist's; only the
        # count changes. See BEARD_INTERLEAVE.
        combined = mask
        for dx in interleave:
            combined = ImageChops.lighter(
                combined, ImageChops.offset(mask, dx, 0))
        mask = combined
    if dilate:
        # Grow each strand into its neighbours. A max filter takes the
        # brightest texel in the window, so a strand widens and the gaps
        # between strands close, while a region with no strand in reach stays
        # empty -- the beard's SHAPE is still the artist's, only its weight
        # changes. This is the one operation here that adds coverage rather
        # than redistributing it; see BEARD_DILATE.
        mask = mask.filter(ImageFilter.MaxFilter(dilate))
    if gamma != 1.0:
        # Thicken what is already there. alpha -> alpha**gamma with gamma < 1
        # lifts partial texels toward opaque and leaves 0 and 255 untouched,
        # so no strand is invented and none is lost -- the existing ones just
        # stop being ghosts. See BEARD_GAMMA for why the beard needs it.
        lut = [min(255, round(255.0 * ((i / 255.0) ** gamma))) for i in range(256)]
        mask = mask.point(lut)
    white = Image.new("L", image.size, 255)
    Image.merge("RGBA", (white, white, white, mask)).save(target, optimize=True)
    histogram = mask.histogram()
    total = sum(histogram)
    opaque = sum(histogram[128:]) / total
    print(f"{source.name:38} -> {target.name:34} {opaque:5.1%} of texels opaque")


def skin_tone(atlas: Image.Image) -> tuple[int, int, int]:
    """Median skin colour of the body atlas.

    Filtered to texels that actually look like skin (R > G > B, mid
    brightness) so the tattoo sleeve, the black trunks and the pink mouth
    interior don't drag the estimate. Downsampled first -- this only needs a
    representative colour, not every texel.
    """
    small = atlas.convert("RGB").resize((512, 256))
    skin = [
        (r, g, b)
        for r, g, b in small.getdata()
        if r > g > b and 60 < r < 240 and (r - b) > 20
    ]
    if not skin:
        raise SystemExit("no skin-like texels found in the body atlas")
    skin.sort(key=lambda c: c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114)
    return skin[len(skin) // 2]


def build_head(atlas: pathlib.Path, source: pathlib.Path, target: pathlib.Path) -> None:
    """Reconstructs a usable head albedo from a partly destroyed source.

    roman_reigns_Image.png is the head map -- its UVs line up exactly with the
    head mesh (forehead wrinkles, eye sockets, nostrils, lips and ears all land
    where they should, which body_color does not manage). But two of its three
    channels are gone: blue is pinned to 255 across 100% of the image, and red
    is clipped at both ends across ~40% of it. Only green survived intact (0%
    clipped low, 3% high).

    So the detail is recoverable and the colour is not. This takes green as
    luminance and tints it with the skin tone measured off body_color -- the
    same character's skin, undamaged -- normalising so mid-grey maps to that
    tone. The result keeps every wrinkle, pore and lip edge the source had.

    This is a RECONSTRUCTION, not the original texture. If the original head
    albedo can be re-exported from the source model with its channels intact,
    it should replace this outright.
    """
    tone = skin_tone(Image.open(atlas))
    green = Image.open(source).convert("RGB").split()[1]
    histogram = green.histogram()
    total = sum(histogram)
    mean = sum(i * c for i, c in enumerate(histogram)) / total

    lut = [[0] * 256 for _ in range(3)]
    for value in range(256):
        # Contrast is compressed toward the mean rather than applied at full
        # range. The green channel is a bake, not a photograph: it carries
        # baked occlusion in the eye sockets, under the brow and along the
        # nasolabial folds. Multiplying skin tone by the raw ratio drove
        # those regions to a dark red-brown and the face came out looking
        # beaten up rather than shaded. CONTRAST keeps the same detail and
        # the same relative ordering, at a fraction of the amplitude, and
        # LIFT stops the darkest texels bottoming out into near-black.
        ratio = LIFT + (1.0 - LIFT) * (value / mean)
        scale = 1.0 + CONTRAST * (ratio - 1.0)
        for channel in range(3):
            lut[channel][value] = max(0, min(255, round(tone[channel] * scale)))
    channels = [green.point(lut[c]) for c in range(3)]
    Image.merge("RGB", channels).save(target, optimize=True)
    print(f"{source.name:38} -> {target.name:34} skin tone {tone}, green mean {mean:.1f}")


def main() -> int:
    if not CHARACTERS.is_dir():
        sys.exit(f"not found: {CHARACTERS}")
    for source_name, (target_name, gamma, dilate, weave) in SOURCES.items():
        source = CHARACTERS / source_name
        if not source.exists():
            sys.exit(f"missing source texture: {source}")
        build(source, CHARACTERS / target_name, gamma, dilate, weave)
    build_head(
        CHARACTERS / "roman_reigns_body_color.png",
        CHARACTERS / "roman_reigns_Image.png",
        CHARACTERS / "roman_reigns_head_color.png",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
