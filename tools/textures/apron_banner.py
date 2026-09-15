#!/usr/bin/env python3
"""Rectify the AEW *Dynamite* ring apron out of a reference photograph.

    python3 tools/textures/apron_banner.py --source <photo.jpg> \
        --out game/assets/environment/materials/ring_apron_banner.png

Why a script and not just a committed PNG
-----------------------------------------
The banner this replaces was an opaque image with no build path -- see
`game/assets/environment/CREDITS.md`, which records it as "supplied by the
project owner". That is fine for provenance and useless for changing it: the
crop, the perspective and the placement of the wordmark on the skirt were all
unrecorded, so the only way to adjust any of them was to re-source the art.

This does the same job as `tools/blender/*.py` does for the models. The photo
is an owner-supplied reference and is NOT committed (the convention in
`gauntlet/raw/README.md`: measurements are committable, the source is not), so
this cannot run in CI and is not meant to -- it is run by hand when the apron
changes, and its output is the committed asset.

**Third-party marks.** The output carries AEW trade dress, exactly as the
banner it replaces did, and is recorded in CREDITS.md on the same terms: in
the build because `ARCHITECTURE.md` permits third-party assets, fine for a
prototype and for internal capture, and NOT cleared for distribution.

The geometry
------------
`SOURCE_QUAD` is the apron's four corners in the reference photo, read off a
gridded overlay of it. The apron recedes, so the banner is a trapezoid there
and the mapping back to a rectangle is a homography -- solved here as an 8x8
linear system rather than pulled in from OpenCV, which is not installed (see
CLAUDE.md on the deleted reference-matching skills).

The output is 1929x544 because `scenes/ring.tscn` is already tuned to that
shape: its `uv1_scale`/`uv1_offset` centre the marks on the skirt and clamp
the edges, and both edge columns have to be plain cloth for the clamp to
extend an unbroken fabric. So the rectified crop -- which is a fraction of one
apron side, with the wordmark in it -- is composited CENTRED onto a field
built from the banner's own darkest fabric, and the outermost columns are
extended to the edges.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import numpy as np
from PIL import Image

OUT_WIDTH = 1929
OUT_HEIGHT = 544

## The apron's corners in the reference photo, clockwise from top-left, read
## off a 100px grid drawn over it. It is deliberately INSET from the banner's
## true edges on all four sides.
##
## Top and bottom, because sampling right up to the edge pulls in the pale mat
## above and the dark ringside floor below, and those then become horizontal
## bands running the full width of the output once the field is extended from
## them. `ring.tscn` only samples 68% of the texture's height anyway
## (uv1_scale.y = 0.6775), so the inset costs nothing.
##
## On the right at 1020 rather than the full width, because a camera operator
## stands in front of the apron beyond that point. The wordmark ends around
## 990, so the crop keeps the mark and stops short of the man.
SOURCE_QUAD = [(0.0, 989.0), (1020.0, 1062.0), (1020.0, 1271.0), (0.0, 1230.0)]

## How much of the output width the rectified crop occupies. The crop is one
## stretch of one apron side; the rest is field. Below about 0.55 the wordmark
## reads too small against the skirt, above about 0.75 it runs into the clamped
## edge columns and the mark smears along the corner.
CROP_FRACTION = 0.66

## The columns of the rectified panel the surrounding field is taken from.
## Left of the wordmark and inside the crop: plain banner carrying the ghosted
## repeat print and nothing else.
FIELD_COLUMNS = (60, 260)


def homography(src: list[tuple[float, float]],
               dst: list[tuple[float, float]]) -> np.ndarray:
    """The 3x3 that maps `src` onto `dst`, from four point pairs.

    Standard DLT with h33 fixed at 1, which is safe here because the apron is
    never edge-on in the reference and so the mapping never goes projective
    enough for that normalisation to blow up.
    """
    rows = []
    rhs = []
    for (x, y), (u, v) in zip(src, dst):
        rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        rhs.append(u)
        rows.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        rhs.append(v)
    h = np.linalg.solve(np.asarray(rows, dtype=float), np.asarray(rhs, dtype=float))
    return np.append(h, 1.0).reshape(3, 3)


def rectify(photo: np.ndarray, quad: list[tuple[float, float]],
            width: int, height: int) -> np.ndarray:
    """Sample the source quad into a `width` x `height` rectangle.

    Inverse mapping -- for every destination pixel, find where it came from --
    so the result has no holes. Nearest-neighbour: the crop is being ENLARGED
    here, and on a photograph at this scale a bilinear tap only adds blur to
    something already soft.
    """
    dst = [(0.0, 0.0), (width - 1.0, 0.0), (width - 1.0, height - 1.0),
           (0.0, height - 1.0)]
    inverse = homography(dst, quad)
    ys, xs = np.mgrid[0:height, 0:width]
    ones = np.ones_like(xs, dtype=float)
    points = np.stack([xs.astype(float), ys.astype(float), ones], axis=-1)
    mapped = points @ inverse.T
    sx = np.rint(mapped[..., 0] / mapped[..., 2]).astype(int)
    sy = np.rint(mapped[..., 1] / mapped[..., 2]).astype(int)
    np.clip(sx, 0, photo.shape[1] - 1, out=sx)
    np.clip(sy, 0, photo.shape[0] - 1, out=sy)
    return photo[sy, sx]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True,
                        help="the reference photograph (not committed)")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    source = pathlib.Path(args.source)
    if not source.exists():
        print("apron_banner.py: no such source photo: %s" % source, file=sys.stderr)
        print("  It is an owner-supplied reference and is not committed; see "
              "the module docstring.", file=sys.stderr)
        return 2

    photo = np.asarray(Image.open(source).convert("RGB"))
    crop_width = int(round(OUT_WIDTH * CROP_FRACTION))
    panel = rectify(photo, SOURCE_QUAD, crop_width, OUT_HEIGHT)

    # The field the wordmark sits on: the same cloth, not a flat colour, which
    # would read as a painted block beside a photographed one.
    #
    # Taken as the per-row MEDIAN of a band of plain columns well inside the
    # panel, not from its outermost column. A single edge column carries
    # whatever happened to be at the crop boundary -- a fold, a highlight, a
    # speck -- and repeating it 1929 times turns that one pixel into a stripe
    # down the whole apron.
    sample = panel[:, FIELD_COLUMNS[0]:FIELD_COLUMNS[1], :]
    field = np.repeat(np.median(sample, axis=1, keepdims=True), OUT_WIDTH, axis=1)
    out = field.copy()
    left = (OUT_WIDTH - crop_width) // 2
    out[:, left:left + crop_width, :] = panel

    # Feather the two seams, or the join reads as a vertical band on a surface
    # that is otherwise continuous cloth.
    blend = 48
    for i in range(blend):
        t = (i + 1) / (blend + 1)
        for x in (left + i, left + crop_width - 1 - i):
            out[:, x, :] = (out[:, x, :] * t + field[:, x, :] * (1.0 - t))

    Image.fromarray(out.astype(np.uint8)).save(args.out, optimize=True)
    print("apron_banner: %dx%d, crop %d wide at x=%d, %s"
          % (OUT_WIDTH, OUT_HEIGHT, crop_width, left, args.out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
