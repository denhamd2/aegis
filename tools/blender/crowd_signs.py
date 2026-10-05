#!/usr/bin/env python3
"""Paint the crowd's sign boards into one atlas.

    python3 tools/blender/crowd_signs.py          # writes the committed PNG

Every board in the bowl (`crowd.py`, the `CrowdSigns` mesh) and the extra
ringside sign fans (`core/arena/sign_fans.gd`) take a cell of this atlas.
Plain PIL -- no Blender -- and deterministic: the same font file and this
table produce the same PNG.

Most slogans are ORIGINAL; five are fan opinions the owner asked for. A real crowd's signs are about real wrestlers and
real shows, and those names and marks are not ours to print; these are the
kind of thing a fan writes in marker on a board without naming anybody
(`game/assets/environment/CREDITS.md`).

Layout: COLS x ROWS cells of CELL_W x CELL_H (2:1, the board's aspect), cell
`i` at column i % COLS, row i // COLS from the top.
"""

from __future__ import annotations

import argparse
import pathlib

from PIL import Image, ImageDraw, ImageFont

REPO = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "game" / "assets" / "environment" / "signs" / "crowd_signs.png"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

COLS, ROWS = 4, 4
CELL_W, CELL_H = 256, 128

## (lines, board sRGB, ink sRGB, accent sRGB or None). Marker on poster
## board: white, yellow and black boards mostly, a few in colour.
SIGNS = (
    (("WHAT A", "MATCH!"), (238, 236, 228), (20, 20, 24), (200, 30, 30)),
    (("1-2-3!",), (250, 214, 40), (18, 18, 20), None),
    (("HOLD ON!",), (20, 20, 22), (245, 245, 240), (230, 190, 40)),
    (("RING THE", "BELL"), (238, 236, 228), (180, 20, 24), None),
    (("VINCE IS", "INNOCENT"), (238, 236, 228), (20, 20, 24), (200, 30, 30)),
    (("I BELIEVE IN", "JOE HENDRY"), (250, 214, 40), (20, 20, 24), None),
    (("BIG MATCH", "ENERGY"), (200, 24, 30), (255, 255, 255), None),
    (("DROPKICK", "ME!"), (250, 214, 40), (190, 20, 24), None),
    (("WIRTZ", "IS CRAP"), (30, 30, 34), (250, 214, 40), None),
    (("FIRE BERNIE", "FOLEY"), (200, 24, 30), (255, 255, 255), None),
    (("HEADLOCK", "HEAVEN"), (120, 60, 170), (255, 255, 255), None),
    (("ROW 9 IS", "LOUD"), (238, 236, 228), (30, 120, 60), (20, 20, 24)),
    (("FIRE ANDY", "O'NEIL"), (238, 236, 228), (20, 40, 140), (20, 20, 24)),
    (("KICK OUT!",), (238, 236, 228), (200, 24, 30), (20, 20, 24)),
    (("NEW", "CHAMP"), (20, 20, 22), (240, 200, 60), None),
    (("BEST SEATS", "IN THE HOUSE"), (250, 214, 40), (20, 20, 24), None),
)
COUNT = len(SIGNS)


def _fit(draw: ImageDraw.ImageDraw, lines, width: int, height: int):
    """The largest font size at which every line fits the cell."""
    for size in range(70, 10, -2):
        font = ImageFont.truetype(FONT, size)
        boxes = [draw.textbbox((0, 0), line, font=font) for line in lines]
        w = max(b[2] - b[0] for b in boxes)
        h = sum(b[3] - b[1] for b in boxes) + (len(lines) - 1) * size * 0.18
        if w <= width and h <= height:
            return font, boxes
    font = ImageFont.truetype(FONT, 10)
    return font, [draw.textbbox((0, 0), line, font=font) for line in lines]


def paint() -> Image.Image:
    atlas = Image.new("RGB", (COLS * CELL_W, ROWS * CELL_H), (0, 0, 0))
    for index, (lines, board, ink, accent) in enumerate(SIGNS):
        x0 = (index % COLS) * CELL_W
        y0 = (index // COLS) * CELL_H
        cell = Image.new("RGB", (CELL_W, CELL_H), board)
        draw = ImageDraw.Draw(cell)
        if accent:
            # A border in marker, a hand's width in.
            draw.rectangle((6, 6, CELL_W - 7, CELL_H - 7), outline=accent, width=5)
        font, boxes = _fit(draw, lines, CELL_W - 30, CELL_H - 28)
        total = sum(b[3] - b[1] for b in boxes) + (len(lines) - 1) * font.size * 0.18
        y = (CELL_H - total) * 0.5
        for line, box in zip(lines, boxes):
            w = box[2] - box[0]
            draw.text(((CELL_W - w) * 0.5 - box[0], y - box[1]), line, font=font, fill=ink)
            y += (box[3] - box[1]) + font.size * 0.18
        atlas.paste(cell, (x0, y0))
    return atlas


def cell_uv(index: int) -> tuple[float, float, float, float]:
    """(u0, v0, u1, v1) of cell `index`, in Blender's V-up convention."""
    col, row = index % COLS, index // COLS
    u0, u1 = col / COLS, (col + 1) / COLS
    v1 = 1.0 - row / ROWS
    v0 = 1.0 - (row + 1) / ROWS
    # A texel in from the edge, so mipmaps never bleed a neighbour in.
    du, dv = 1.5 / (COLS * CELL_W), 1.5 / (ROWS * CELL_H)
    return (u0 + du, v0 + dv, u1 - du, v1 - dv)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    paint().save(out, optimize=False, compress_level=9)
    print("crowd_signs: %d signs, %s" % (COUNT, out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
