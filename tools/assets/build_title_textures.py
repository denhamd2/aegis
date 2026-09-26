#!/usr/bin/env python3
"""Builds the AEW title's textures from the owner's texture atlas.

Source: tools/assets/source/aew_title_atlas.png (2172x724, supplied by the
project owner; see game/assets/props/CREDITS.md). Its top band is the belt
drawn straight on -- the plate artwork. Everything under it is SWATCHES: the
black rectangles are leather, the gold ones metal, the round stone the gems,
the ring studs the snaps. The swatches are read as material references here
and nothing below the band is ever put on the belt.

Writes, into game/assets/props/:

  aew_title_art.png         the belt band, RGBA. Alpha keeps each plate and
                            cuts it to its own ornate outline: inside each
                            plate's box, the dark leather and background that
                            is CONNECTED TO THE BOX'S EDGE is removed (a flood
                            fill), so the black globe and enamel inside a
                            plate -- dark, but enclosed by metal -- stay.
  aew_title_art_normal.png  relief from the art's own shading: engraving,
                            rims, stones. A normal map, not geometry -- the
                            plates themselves are real raised slabs.
  aew_title_art_orm.png     R occlusion (1), G roughness, B metallic: metal
                            where the art is metal (bright), dielectric enamel
                            where it is black; silver reads a touch smoother
                            than gold, with a fine noise for wear.
  aew_leather.png           tileable black leather from the close-up grain
  aew_leather_normal.png    swatch, and its grain as a normal map.

PLATES below is the measured layout (pixel boxes in the atlas), shared with
tools/blender/roman_props.py, which maps each plate's front face to its box.

Deterministic: same atlas in, byte-identical files out.
"""

from __future__ import annotations

import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "tools/assets/source/aew_title_atlas.png"
OUT = REPO / "game/assets/props"
LAYOUT = REPO / "tools/blender/aew_title_layout.json"

## The belt band: everything above the swatches.
BAND_H = 520
## Plate boxes, (x0, y0, x1, y1) in atlas pixels, measured as the columns
## where the metal (luminance > 75) runs, and its rows within them.
PLATES = {
    "outer_l": (199, 108, 427, 435),
    "bar2_l": (432, 105, 486, 450),
    "inner_l": (490, 68, 747, 484),
    "bar1_l": (752, 69, 813, 486),
    "centre": (816, 4, 1359, 520),
    "bar1_r": (1363, 71, 1425, 500),
    "inner_r": (1429, 75, 1683, 495),
    "bar2_r": (1687, 102, 1741, 443),
    "outer_r": (1746, 110, 1978, 440),
}
## Where the belt's centre line is in the atlas: the strap's own middle row
## and the centre plate's middle column.
CENTRE_X = 1087
STRAP_Y = (124, 421)
## Metres per atlas pixel: puts the centre plate at 0.26 m across.
METRES_PER_PX = 0.00048
## The close-up leather swatch (bottom right, the large grain square).
LEATHER = (1795, 505, 1980, 700)
DARK = 62          # luminance under which a pixel can be leather/background


def _flood_edge_dark(dark: np.ndarray) -> np.ndarray:
    """Dark pixels connected to the border of `dark`'s box (4-neighbour)."""
    seen = np.zeros_like(dark)
    seen[0, :] = dark[0, :]
    seen[-1, :] = dark[-1, :]
    seen[:, 0] = dark[:, 0]
    seen[:, -1] = dark[:, -1]
    while True:
        grown = seen.copy()
        grown[1:, :] |= seen[:-1, :]
        grown[:-1, :] |= seen[1:, :]
        grown[:, 1:] |= seen[:, :-1]
        grown[:, :-1] |= seen[:, 1:]
        grown &= dark
        if (grown == seen).all():
            return seen
        seen = grown


def _grow_from_centre(mask: np.ndarray) -> np.ndarray:
    """The 4-connected part of `mask` that contains its box's centre."""
    seen = np.zeros_like(mask)
    h, w = mask.shape
    seen[h // 2, w // 2] = True
    while True:
        grown = seen.copy()
        grown[1:, :] |= seen[:-1, :]
        grown[:-1, :] |= seen[1:, :]
        grown[:, 1:] |= seen[:, :-1]
        grown[:, :-1] |= seen[:, 1:]
        grown &= mask
        if (grown == seen).all():
            return seen
        seen = grown


def _normal_from_height(height: np.ndarray, strength: float) -> Image.Image:
    gy, gx = np.gradient(height)
    nx, ny = -gx * strength, gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return Image.fromarray(np.round((rgb * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


## Columns each plate's slab is built in (roman_props.py bends a plate along
## the belt one column at a time). Shared so the slab extents below line up.
COLUMN_PX = 40.0


def plate_columns(x0: int, x1: int) -> int:
    return max(2, int(round((x1 - x0) / COLUMN_PX)))


SLABS: dict[str, list] = {}


def build_art(atlas: Image.Image) -> None:
    band = np.asarray(atlas.crop((0, 0, atlas.width, BAND_H)).convert("RGB")).astype(np.float32)
    lum = band.mean(axis=2)
    alpha = np.zeros(lum.shape, dtype=np.uint8)
    for name, (x0, y0, x1, y1) in PLATES.items():
        box = lum[y0:y1, x0:x1]
        outside = _flood_edge_dark(box < DARK)
        # Then only the piece joined to the plate's middle: stitching and
        # grain on the strap either side can clear the threshold in thin
        # slivers that are not part of any plate.
        kept = _grow_from_centre(~outside)
        alpha[y0:y1, x0:x1] = np.where(kept, 255, 0)
        # Per column, the rows that are solidly plate: the slab behind the
        # art is built to these, so its edges never show past the outline.
        cols = plate_columns(x0, x1)
        spans = []
        for c in range(cols):
            a = int(round((x1 - x0) * c / cols))
            b = int(round((x1 - x0) * (c + 1) / cols))
            # A row counts if the whole column width is plate across it.
            rows = np.where(kept[:, a:b].all(axis=1))[0]
            spans.append(None if len(rows) < 8 else [int(y0 + rows.min()), int(y0 + rows.max())])
        SLABS[name] = spans
    # Soften the cut by a pixel so the outline does not stair-step.
    a = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.8))
    rgba = Image.fromarray(band.astype(np.uint8), "RGB").convert("RGBA")
    rgba.putalpha(a)
    rgba.save(OUT / "aew_title_art.png", optimize=True)

    height = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
    _normal_from_height(height, 6.0).save(OUT / "aew_title_art_normal.png", optimize=True)

    sat = band.max(axis=2) - band.min(axis=2)
    metal = np.clip((lum - 45.0) / 40.0, 0.0, 1.0)
    silver = np.clip((70.0 - sat) / 50.0, 0.0, 1.0) * metal
    rng = np.random.default_rng(11)
    wear = rng.normal(0.0, 0.035, lum.shape)
    rough = 0.34 - 0.08 * silver + wear
    rough = np.where(metal > 0.5, rough, 0.58 + wear)
    orm = np.stack([np.ones_like(lum), np.clip(rough, 0.05, 1.0), metal], axis=-1)
    Image.fromarray(np.round(orm * 255).astype(np.uint8), "RGB").save(
        OUT / "aew_title_art_orm.png", optimize=True)
    print("art %dx%d, %d plates, %.1f%% of the band kept" % (
        band.shape[1], band.shape[0], len(PLATES), 100.0 * (alpha > 0).mean()))


def build_leather(atlas: Image.Image) -> None:
    patch = np.asarray(atlas.crop(LEATHER).convert("RGB")).astype(np.float32)
    h, w, _ = patch.shape
    # Tileable: cross-fade each edge into the opposite one over a quarter of
    # the patch, so the repeat has no seam and no mirror symmetry.
    o = w // 4
    ramp = np.linspace(0.0, 1.0, o)[None, :, None]
    body = patch[:, o:, :].copy()
    body[:, -o:, :] = body[:, -o:, :] * (1 - ramp) + patch[:, :o, :] * ramp
    o2 = body.shape[0] // 4
    ramp2 = np.linspace(0.0, 1.0, o2)[:, None, None]
    tile = body[o2:, :, :].copy()
    tile[-o2:, :, :] = tile[-o2:, :, :] * (1 - ramp2) + body[:o2, :, :] * ramp2
    img = Image.fromarray(np.clip(tile, 0, 255).astype(np.uint8), "RGB").resize((256, 256), Image.LANCZOS)
    img.save(OUT / "aew_leather.png", optimize=True)
    lum = np.asarray(img.convert("L")).astype(np.float32) / 255.0
    _normal_from_height(lum, 3.0).save(OUT / "aew_leather_normal.png", optimize=True)
    print("leather tile 256x256 from a %dx%d swatch" % (w, h))


def main() -> int:
    if not SOURCE.exists():
        sys.exit("missing %s" % SOURCE)
    atlas = Image.open(SOURCE)
    OUT.mkdir(parents=True, exist_ok=True)
    build_art(atlas)
    build_leather(atlas)
    LAYOUT.write_text(json.dumps({
        "band": [atlas.width, BAND_H], "plates": PLATES, "centre_x": CENTRE_X,
        "strap_y": STRAP_Y, "metres_per_px": METRES_PER_PX,
        "column_px": COLUMN_PX, "slabs": SLABS}, indent=1, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
