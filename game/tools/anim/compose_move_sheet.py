#!/usr/bin/env python3
"""Compose a per-move QA sheet from paired_shot frames.

Usage:
  compose_move_sheet.py <move_id> <match_dir> <side_dir> <out_png>

Both directories contain the PNGs written by tools/probe/paired_shot.gd
(<clip>_00.png, <clip>_20.png, ...). The sheet is a two-row contact strip:
the game's match camera on top, the side/close probe below.
"""
from __future__ import annotations

import glob
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

FRAME_W = 640
FRAME_H = 360
GAP = 8
HEADER_H = 54
ROW_H = 30
MARGIN = 8


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _frames(directory: str) -> list[tuple[float, str]]:
    out: list[tuple[float, str]] = []
    for path in glob.glob(os.path.join(directory, "*.png")):
        m = re.search(r"_(\d+)\.png$", path)
        if not m:
            continue
        out.append((int(m.group(1)) / 100.0, path))
    out.sort(key=lambda item: item[0])
    return out


def _row(paths: list[tuple[float, str]], label: str) -> Image.Image:
    width = len(paths) * FRAME_W + max(0, len(paths) - 1) * GAP + MARGIN * 2
    height = ROW_H + FRAME_H + MARGIN
    row = Image.new("RGB", (width, height), (24, 24, 28))
    draw = ImageDraw.Draw(row)
    draw.text((MARGIN, 6), label, fill=(220, 220, 225), font=_font(17, True))
    x = MARGIN
    for fraction, path in paths:
        image = Image.open(path).convert("RGB")
        if image.size != (FRAME_W, FRAME_H):
            image = image.resize((FRAME_W, FRAME_H), Image.Resampling.LANCZOS)
        row.paste(image, (x, ROW_H))
        draw.text((x + 8, ROW_H + 6), f"{fraction:.2f}", fill=(255, 255, 255),
                  font=_font(15, True))
        x += FRAME_W + GAP
    return row


def main() -> int:
    if len(sys.argv) != 5:
        print(__doc__)
        return 2
    move_id, match_dir, side_dir, out_path = sys.argv[1:5]
    side_only = match_dir == "-"
    match = [] if side_only else _frames(match_dir)
    side = _frames(side_dir)
    if not match and not side:
        print("missing both match and side frames")
        return 1
    if not match:
        match = side
    if not side:
        side = match
    # Keep the common fractions only, so the two rows line up.
    common = sorted(set(f for f, _ in match) & set(f for f, _ in side))
    match = [(f, p) for f, p in match if f in common]
    side = [(f, p) for f, p in side if f in common]
    top = _row(match if not side_only else side,
               "SIDE / CLOSE — both roles" if side_only
               else "MATCH CAMERA — attacker left, defender right")
    bottom = None if side_only else _row(side, "SIDE / CLOSE — both roles")
    width = max(top.width, bottom.width if bottom else 0)
    height = HEADER_H + top.height + (bottom.height if bottom else 0)
    canvas = Image.new("RGB", (width, height), (16, 16, 20))
    draw = ImageDraw.Draw(canvas)
    draw.text((MARGIN, 10), f"FF MOVE QA — {move_id}", fill=(255, 255, 255),
              font=_font(24, True))
    draw.text((MARGIN, 36), "beats are fractions of the move's length"
              if side_only else "beats are fractions of the move's length; "
              "both rows are the same beat", fill=(180, 180, 190),
              font=_font(14))
    canvas.paste(top, (0, HEADER_H))
    if bottom:
        canvas.paste(bottom, (0, HEADER_H + top.height))
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    canvas.save(out_path, optimize=True)
    print(f"SHEET {move_id} -> {out_path} ({canvas.width}x{canvas.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
