#!/usr/bin/env python3
"""Roman's tribal ink, rebuilt dense and near-black.

    python3 tools/assets/build_roman_tattoo.py

Reads game/assets/characters/roman_reigns_body_color.png (the supplied
4096x2048 body atlas) and writes roman_reigns_body_ink.png beside it, which
RomanModel uses as the body's albedo (BODY_ALBEDO).

Why: the supplied sleeve and chest piece are thin dark-teal lines on tan
skin. On screen, at any distance a match is shot from, the lines and the
skin between them average to a grey wash and the tattoo all but disappears
(stage 8 review against WWE 2K26, gauntlet/refs/raw 190-218 s, where it is
his most recognisable marking: dense, near-black ink with the skin showing
through in fine lines). So, in the two tattoo panels of the atlas only:

  1. the ink is found by hue, not darkness -- ink is teal (green >= red),
     skin is red well over green -- so the nipples, the navel and the
     shading in the skin are left alone;
  2. it can be thickened by INK_GROW pixels -- tried at 1 and 2 and both
     filled the pattern's fine work in, so it is 0: the ink is darkened,
     not widened;
  3. it is laid down as INK, near-black with a trace of the original teal,
     over a soft edge (EDGE) so it does not stair-step under filtering.

Then his gloves: 2K26's Roman wrestles in black fingerless gloves with a
white tribal print, over white wrist tape (the tape is its own mesh). The
hands are in the atlas -- two panels, wrist at the top of each, fingers
running down to the nails -- so the glove is painted over each panel from
the wrist edge down to the knuckle line (GLOVES), fingers left bare: black
with a white band print, a scalloped edge over the knuckles.

Deterministic: the same atlas in gives a byte-identical PNG out.
"""
import pathlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHARS = ROOT / "game" / "assets" / "characters"
SOURCE = CHARS / "roman_reigns_body_color.png"
OUT = CHARS / "roman_reigns_body_ink.png"

# The two tattoo panels, in atlas pixels (x0, y0, x1, y1): the chest and
# shoulder piece (upper middle) and the arm sleeve (lower middle). Measured
# off the atlas; nothing outside them is touched.
PANELS = [(2240, 0, 3220, 780), (1480, 870, 2320, 2048)]
# R - G at which a pixel is all ink (at or below INK_RG) / all skin (at or
# above SKIN_RG). Measured: ink median (49, 61, 58), R-G -12; skin median
# (173, 109, 79), R-G +64.
INK_RG = 2.0
SKIN_RG = 26.0
# Pixels the ink grows by (a max filter of 2 * INK_GROW + 1).
INK_GROW = 0
# Edge softness after growing, in pixels (Gaussian radius).
EDGE = 0.5
# The ink: near-black, a trace of the original teal (sRGB).
INK = np.array([24.0, 30.0, 30.0])

# The gloves, per hand panel: (x0, x1, wrist_y, knuckle_y) in atlas pixels.
# Measured off the atlas: the panels' top edges and the crease line across
# the knuckles, ~100 px above the nails' row.
GLOVES = [(3000, 4096, 893, 1215), (3000, 4096, 1497, 1765)]
GLOVE = np.array([22.0, 22.0, 25.0])     # the glove's black
PRINT = np.array([226.0, 224.0, 218.0])  # the print's white
BAND = 84.0      # px between print bands, wrist to knuckles
SCALLOP = 38.0   # px period of the scalloped edge over the knuckles


def glove_print(xx, yy, wrist_y):
    """1 where the white print is, 0 on the black: bands of triangles
    (the Samoan 'teeth') between thin rules, alternating direction."""
    v = (yy - wrist_y) / BAND
    row = np.floor(v)
    f = v - row
    rule = np.abs(f - 0.06) < 0.018
    u = (xx / (BAND * 0.5)) % 1.0
    up = np.where(row % 2 == 0, f, 1.0 - f)
    tooth = (np.abs(u - 0.5) * 2.0 < (up - 0.30) / 0.5) & (f > 0.30) & (f < 0.80)
    inner = (np.abs(u - 0.5) * 2.0 < (up - 0.30) / 0.5 - 0.16) & (f > 0.38) & (f < 0.80)
    return (rule | (tooth & ~inner)).astype(np.float32)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    rgba = np.asarray(image).astype(np.float32)
    rgb = rgba[..., :3]
    out = rgb.copy()
    for x0, y0, x1, y1 in PANELS:
        tile = rgb[y0:y1, x0:x1]
        rg = tile[..., 0] - tile[..., 1]
        ink = np.clip((SKIN_RG - rg) / (SKIN_RG - INK_RG), 0.0, 1.0)
        mask = Image.fromarray((ink * 255.0 + 0.5).astype(np.uint8), "L")
        if INK_GROW > 0:
            mask = mask.filter(ImageFilter.MaxFilter(2 * INK_GROW + 1))
        mask = mask.filter(ImageFilter.GaussianBlur(EDGE))
        m = np.asarray(mask).astype(np.float32)[..., None] / 255.0
        out[y0:y1, x0:x1] = tile * (1.0 - m) + INK * m
    height, width = out.shape[:2]
    for x0, x1, wrist_y, knuckle_y in GLOVES:
        y0, y1 = int(wrist_y), int(knuckle_y + SCALLOP)
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        edge = knuckle_y + 10.0 * np.abs(np.sin(xx * np.pi / SCALLOP))
        cover = np.clip((edge - yy) / 2.5, 0.0, 1.0)[..., None]
        glove = GLOVE + (PRINT - GLOVE) * glove_print(xx, yy, wrist_y)[..., None] * 0.7
        out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * (1.0 - cover) + glove * cover
    rgba[..., :3] = out
    Image.fromarray(np.clip(rgba + 0.5, 0, 255).astype(np.uint8), "RGBA").save(
        OUT, optimize=False, compress_level=9)
    print("wrote %s" % OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
