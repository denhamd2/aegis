#!/usr/bin/env python3
"""A muscle-definition normal map for Roman's torso.

    python3 tools/assets/build_roman_muscle.py

Writes game/assets/characters/roman_reigns_body_nrm.png (4096x2048, the
body atlas's own layout), which RomanModel puts on the body material
(BODY_NORMAL). The supplied body has no normal map at all, and its paint
carries almost no anatomy (a band-pass of it is tattoo and noise), so the
torso rendered as one smooth surface where 2K26's Roman shows a hard
six-pack and a heavy pec line (stage 8 review).

There is no sculpt to bake from, so the relief is laid out in the atlas
from landmarks measured on it -- the front torso panel is an upright front
projection: nipples at (2973, 387) and (3363, 385), navel at (3166, 758),
midline x 3168 -- as a height field of grooves and masses in the usual
places, then turned into a tangent-space normal map (OpenGL convention,
green up, which is what Godot reads). Everywhere else is flat.

Deterministic: no randomness; the same constants give a byte-identical PNG.
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "characters" / "roman_reigns_body_nrm.png"
W, H = 4096, 2048

MID_X = 3168.0
NIPPLE_Y = 386.0
NIPPLE_DX = 195.0          # half the nipple spacing
NAVEL_Y = 758.0
WAIST_Y = 835.0            # the waistband: no relief below it

# Grooves: (depth, half-width px). Depth is in height units, scaled by
# STRENGTH into the normal.
LINEA = (0.8, 16.0)         # the centre line
INTERSECTION = (0.55, 16.0)  # the three lines across the abs
SEMILUNAR = (0.8, 24.0)    # the outer edge of the abs
PEC_LINE = (1.0, 24.0)     # under the pecs
# Masses: (height, radius px).
PEC_MASS = (2.2, 170.0)
AB_BLOCK = (1.0, 62.0)
STRENGTH = 3.2             # height units -> normal tilt


def groove_along(h, xs, ys, depth, width, yy, xx):
    """Subtract a Gaussian groove along the polyline (xs, ys)."""
    pts = np.stack([np.asarray(xs, float), np.asarray(ys, float)], axis=1)
    x0, x1 = int(pts[:, 0].min() - 4 * width), int(pts[:, 0].max() + 4 * width)
    y0, y1 = int(pts[:, 1].min() - 4 * width), int(pts[:, 1].max() + 4 * width)
    sub_x = xx[y0:y1, x0:x1]
    sub_y = yy[y0:y1, x0:x1]
    best = np.full(sub_x.shape, np.inf)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        dx, dy = bx - ax, by - ay
        t = np.clip(((sub_x - ax) * dx + (sub_y - ay) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
        d = np.hypot(sub_x - (ax + t * dx), sub_y - (ay + t * dy))
        best = np.minimum(best, d)
    h[y0:y1, x0:x1] -= depth * np.exp(-(best / width) ** 2)


def mass_at(h, cx, cy, height, radius, yy, xx):
    h += height * np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (radius * radius))


def main() -> None:
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    h = np.zeros((H, W))
    top = NIPPLE_Y + 70.0            # where the abs start, under the pecs
    rows = [top + (NAVEL_Y - top) * f for f in (0.3, 0.6, 0.88)]
    for side in (-1.0, 1.0):
        # Pec mass and the line under it, sweeping up and out to the armpit.
        mass_at(h, MID_X + side * NIPPLE_DX * 0.8, NIPPLE_Y - 30.0, *PEC_MASS, yy, xx)
        groove_along(h, [MID_X + side * 10.0, MID_X + side * 120.0,
                         MID_X + side * 230.0, MID_X + side * 310.0],
                     [NIPPLE_Y + 70.0, NIPPLE_Y + 80.0, NIPPLE_Y + 40.0, NIPPLE_Y - 60.0],
                     *PEC_LINE, yy, xx)
        # The outer edge of the abs, curving in toward the hip.
        groove_along(h, [MID_X + side * 175.0, MID_X + side * 182.0,
                         MID_X + side * 170.0, MID_X + side * 140.0],
                     [top, top + 140.0, NAVEL_Y, WAIST_Y], *SEMILUNAR, yy, xx)
        # The blocks between the lines.
        edges = [top] + rows + [WAIST_Y]
        for a, b in zip(edges[:-1], edges[1:]):
            mass_at(h, MID_X + side * 88.0, (a + b) * 0.5, *AB_BLOCK, yy, xx)
    groove_along(h, [MID_X, MID_X], [top - 10.0, WAIST_Y], *LINEA, yy, xx)
    for y in rows:
        groove_along(h, [MID_X - 170.0, MID_X - 80.0, MID_X, MID_X + 80.0, MID_X + 170.0],
                     [y + 6.0, y - 4.0, y + 2.0, y - 4.0, y + 6.0], *INTERSECTION, yy, xx)
    # Only on the torso panel; fade out at its edges and the waistband.
    panel = np.clip((WAIST_Y - yy) / 25.0, 0.0, 1.0) \
        * np.clip((xx - (MID_X - 470.0)) / 40.0, 0.0, 1.0) \
        * np.clip(((MID_X + 470.0) - xx) / 40.0, 0.0, 1.0) \
        * np.clip((yy - 120.0) / 40.0, 0.0, 1.0)
    h *= panel
    gy, gx = np.gradient(h)
    n = np.stack([-gx * STRENGTH, gy * STRENGTH, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    rgb = np.clip((n * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(OUT, optimize=False, compress_level=9)
    print("wrote %s" % OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
