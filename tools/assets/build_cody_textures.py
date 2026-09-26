#!/usr/bin/env python3
"""Cody Rhodes's head texture, re-coloured to the owner's references.

The supplied model paints his hair onto the head texture (no hair cards) as a
short ash-brown crop; the owner's photographs show it platinum blond, bleached
bright through the lengths with a darker, warmer root. This writes

  game/assets/characters/cody_rhodes_head_blond.png

from the supplied head texture (cody_rhodes_ximage_d17c32323759dea.png): the
hair region re-coloured, everything else -- face, brows, the neck tattoo,
the ears -- byte for byte as supplied.

The hair region is a polygon drawn on the texture's own UV layout (the face,
ears and neck are one clean island, the hair the band around its top and
sides), feathered. Texture statistics cannot find it: the skin map carries as
much fine detail as the painted strands, and hair and skin share a hue.

The colour keeps every strand the artist painted: each hair texel's
luminance, normalised to the hair's own median, scales the target blond, so
the strand detail survives and only the colour changes.

Deterministic: same input, byte-identical output.
"""

from __future__ import annotations

import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CHARACTERS = pathlib.Path(__file__).resolve().parents[2] / "game/assets/characters"
SOURCE = CHARACTERS / "cody_rhodes_ximage_d17c32323759dea.png"
TARGET = CHARACTERS / "cody_rhodes_head_blond.png"

## Platinum through the lengths, a warmer darker root -- measured off the
## owner's references: bright hair (217,179,154) under warm stage light,
## (131,109,86) in the shadowed roots of the press photograph.
BLOND = np.array([236.0, 214.0, 170.0])
ROOT = np.array([150.0, 122.0, 88.0])

## The face/ears/neck island, in 0..1 texture coordinates (x right, y down),
## traced on the texture: the hairline across the brow, down each temple to
## the top of the ear, round the ear, and down the side of the neck.
SKIN = [(0.312, 0.195), (0.651, 0.195), (0.729, 0.300), (0.779, 0.367),
        (0.870, 0.367), (0.875, 0.553), (0.853, 0.651), (0.853, 1.0),
        (0.143, 1.0), (0.143, 0.651), (0.124, 0.553), (0.130, 0.367),
        (0.224, 0.367), (0.267, 0.300)]
## The temples are the one place the outline cannot be drawn by hand: the
## sideburns and the skin beside them share a strip. Inside this narrower
## outline's difference from SKIN, only texels as dark as the painted hair
## are treated as hair (the skin there is ~35 levels brighter).
SKIN_TIGHT = [(0.312, 0.195), (0.651, 0.195), (0.665, 0.300), (0.700, 0.371),
              (0.870, 0.371), (0.875, 0.553), (0.853, 0.651), (0.853, 1.0),
              (0.143, 1.0), (0.143, 0.651), (0.124, 0.553), (0.130, 0.371),
              (0.275, 0.371), (0.303, 0.300)]
HAIR_DARKER_THAN = 128.0
## The two skin-coloured patches in the top corners (the ear backs).
CORNERS = [(0.0, 0.0, 0.098, 0.150), (0.905, 0.0, 1.0, 0.150)]
## Nothing below this is hair.
HAIR_BOTTOM = 0.655


def main() -> int:
    img = Image.open(SOURCE).convert("RGBA")
    w, h = img.size
    def hair_mask(skin):
        mask = Image.new("L", (w, h), 0)
        draw = ImageDraw.Draw(mask)
        draw.rectangle((0, 0, w, int(HAIR_BOTTOM * h)), fill=255)
        draw.polygon([(x * w, y * h) for x, y in skin], fill=0)
        for x0, y0, x1, y1 in CORNERS:
            draw.rectangle((x0 * w, y0 * h, x1 * w, y1 * h), fill=0)
        return np.asarray(mask).astype(np.float32) / 255.0

    sure = hair_mask(SKIN)
    band = np.clip(hair_mask(SKIN_TIGHT) - sure, 0.0, 1.0)
    lum0 = np.asarray(img.convert("RGB")).astype(np.float32).mean(axis=2)
    dark = np.clip((HAIR_DARKER_THAN - lum0) / 20.0, 0.0, 1.0)
    dark = np.asarray(Image.fromarray(np.round(dark * 255).astype(np.uint8))
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    mask = Image.fromarray(np.round(np.maximum(sure, band * dark) * 255).astype(np.uint8))
    mask = mask.filter(ImageFilter.GaussianBlur(w / 512.0))
    m = np.asarray(mask).astype(np.float32)[..., None] / 255.0

    rgba = np.asarray(img).astype(np.float32)
    rgb = rgba[..., :3]
    lum = rgb.mean(axis=2)
    hair = lum[m[..., 0] > 0.9]
    ratio = np.clip(lum / max(float(np.median(hair)), 1.0), 0.0, 1.6)[..., None]
    # Darker texels are the roots and the shadowed underside: lean them warm.
    root = np.clip(1.1 - ratio, 0.0, 1.0)
    colour = (BLOND * (1.0 - root) + ROOT * root) * np.clip(ratio, 0.55, 1.25)
    out = rgb * (1.0 - m) + np.clip(colour, 0, 255) * m
    rgba[..., :3] = out
    Image.fromarray(np.round(rgba).astype(np.uint8), "RGBA").save(TARGET, optimize=True)
    print("%s: hair %.1f%% of the texture" % (TARGET.name, 100.0 * float((m > 0.5).mean())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
