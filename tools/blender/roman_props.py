#!/usr/bin/env python3
"""Build Roman Reigns' entrance props in Blender, export as glTF.

Run:  tools/blender/build_venue.sh roman

Two files:

  game/assets/props/ula_fala.glb      the Samoan chief's necklace he wears to
                                      the ring (gauntlet/refs/entrances.md)
  game/assets/props/aew_title.glb     the AEW World Championship, in two
                                      shapes: Title* worn round his waist,
                                      Held* straight in the hand

Authored in the WRESTLER'S OWN FRAME, game axes: +Y up, forward -Z (the
controller's convention, WrestlerController._turn_toward_opponent), so +X is
his RIGHT and his left shoulder is at -X. Every prop's origin is the point it
hangs from:

  ula fala   the base of the neck (the neck_01 bone's head)
  worn       his hips bone (the belt is authored at his measured waist)
  held       the left hand's grip (hand_l)

and core/match/entrance_props.gd puts each origin on that bone at runtime,
scaled by the model's shoulder width -- so the same file fits the base
mannequin and Roman's much bigger frame.

Materials are placeholders, as everywhere in the venue: the game dresses each
part by name (EntranceProps.MATERIALS), because gold metal under this hall's
light is a solved value, not a Blender colour.

Deterministic: same code in, byte-identical .glb out.
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import venue  # noqa: E402
from venue import Part  # noqa: E402
from mathutils import Vector  # noqa: E402

import bpy_exit  # noqa: E402

PROP_DIR = venue.REPO / "game" / "assets" / "props"

## Measured shoulder span (upperarm_l to upperarm_r heads) of the base rig the
## props are authored against. EntranceProps scales by model span / this.
BASE_SHOULDER_SPAN = 0.384

FALA_COLORS = {
    "FalaRed": (0.60, 0.05, 0.03, 1.0),
    "FalaOrange": (0.86, 0.30, 0.06, 1.0),
    "FalaCord": (0.10, 0.07, 0.05, 1.0),
}
TITLE_COLORS = {
    "TitleArt": (1.0, 0.77, 0.34, 1.0),
    "TitleGold": (1.0, 0.77, 0.34, 1.0),
    "TitleStrap": (0.03, 0.03, 0.03, 1.0),
    "TitleSnap": (0.8, 0.62, 0.3, 1.0),
    "HeldArt": (1.0, 0.77, 0.34, 1.0),
    "HeldGold": (1.0, 0.77, 0.34, 1.0),
    "HeldStrap": (0.03, 0.03, 0.03, 1.0),
    "HeldSnap": (0.8, 0.62, 0.3, 1.0),
}


def framed_box(part: Part, center: Vector, ax: Vector, ay: Vector, az: Vector,
               size: Vector) -> None:
    """A box on an arbitrary orthonormal frame -- a necklace segment lies on
    a curve that tilts every way, which an upright oriented_box cannot."""
    ex, ey, ez = ax * (size.x * 0.5), ay * (size.y * 0.5), az * (size.z * 0.5)
    corners = [center + ex * a + ey * b + ez * c
               for a, b, c in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                               (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1))]
    v = [part.vert(c) for c in corners]
    for face in ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
                 (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        part.quad(*[v[i] for i in face])


# ---------------------------------------------------------------------------
# The ula fala
# ---------------------------------------------------------------------------

def fala_curve(t: float) -> Vector:
    """The loop the necklace lies on, t in [0, 1), from the back of the neck
    round the right side, down to its lowest point on the sternum, and back
    up the left. Origin at the base of the neck; forward is -Z.

    Behind, it sits on the trapezius just under the neck (y 0, z +0.07);
    in front it drops 0.26 onto the chest and stands 0.13 proud of the
    neck's line -- the pectorals' thickness on the base rig."""
    a = 2.0 * math.pi * t
    # Round the neck: a circle in plan, 0.10 wide either side.
    x = 0.105 * math.sin(a)
    # Back (a=0) to front (a=pi): z from +0.07 to -0.13.
    z = 0.07 * math.cos(a) - 0.03 - 0.03 * (1.0 - math.cos(a)) * 0.5 * 2.0
    # Drops toward the front, a U rather than a V: the lowest 40% of the loop
    # is where the weight of the segments hangs.
    front = (1.0 - math.cos(a)) * 0.5
    y = -0.26 * front ** 1.6
    return Vector((x, y, z))


def build_ula_fala(parts: dict[str, Part]) -> None:
    """Forty wedge segments of dried pandanus on a cord, red and orange.

    The real thing is a chain of the fruit's wedge-shaped keys, strung so
    their wide ends face out: from the front it reads as a thick, faceted
    band, darker at the base of each key and bright at the tip. Each segment
    here is a small box on the curve's own frame -- long along the cord,
    deep out from the body -- alternating the two colours, with a slight
    fan so the band has the ridged silhouette the real one has.
    """
    count = 40
    for i in range(count):
        t0, t1 = i / count, (i + 1) / count
        p0, p1 = fala_curve(t0), fala_curve(t1)
        center = (p0 + p1) * 0.5
        along = (p1 - p0).normalized()
        # Out from the body: away from the neck's axis, level.
        radial = Vector((center.x, 0.0, center.z))
        if radial.length < 1e-4:
            radial = Vector((0.0, 0.0, -1.0))
        radial.normalize()
        up = along.cross(radial).normalized()
        out = up.cross(along).normalized()
        # A small alternating tilt about the cord: the keys fan.
        fan = 0.18 * (1 if i % 2 else -1)
        out2 = (out * math.cos(fan) + up * math.sin(fan)).normalized()
        up2 = out2.cross(along).normalized()
        part = parts["FalaRed" if i % 2 == 0 else "FalaOrange"]
        framed_box(part, center + out2 * 0.012, along, up2, out2,
                   Vector((0.030, 0.028, 0.042)))
    # The cord the keys hang on, visible between them.
    path = [fala_curve(i / 64.0) for i in range(65)]
    parts["FalaCord"].tube(path, 0.006, sides=6)


# ---------------------------------------------------------------------------
# The AEW World Championship
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# The belt, laid out off the owner's texture atlas
# ---------------------------------------------------------------------------
#
# tools/assets/build_title_textures.py measures the atlas and writes
# aew_title_layout.json: each plate's pixel box in the belt band, the centre
# column, the strap's rows, and the metres per pixel. Every plate here is
# placed and sized from that, and its front face is UV-mapped to exactly its
# own box -- so the artwork lands on the plate it was drawn for, unstretched,
# and the leather between plates is real strap, not a picture of one.
#
# Atlas x runs across the belt as a viewer sees it: the viewer's LEFT is the
# wearer's RIGHT (+X), so a belt coordinate `s` (metres along the belt from
# the centre plate, + toward +X) is (centre_x - px) * metres_per_px.

LAYOUT = json.loads((pathlib.Path(__file__).resolve().parent
                     / "aew_title_layout.json").read_text())
MPP = LAYOUT["metres_per_px"]
BAND_W, BAND_H = LAYOUT["band"]
CENTRE_PX = LAYOUT["centre_x"]
STRAP_TOP, STRAP_BOTTOM = LAYOUT["strap_y"]
STRAP_MID = 0.5 * (STRAP_TOP + STRAP_BOTTOM)
STRAP_HEIGHT = (STRAP_BOTTOM - STRAP_TOP) * MPP
## How far each plate stands off the strap: the centre plate is the deepest.
PLATE_DEPTH = {"centre": 0.009, "inner_l": 0.007, "inner_r": 0.007}
PLATE_DEPTH_DEFAULT = 0.005
## Snaps: two columns of three at each end of the band, as the atlas has
## them (and as its snap swatch draws them: brass rings).
SNAP_COLS_PX = (29, 80)
SNAP_ROWS_PX = (190, 272, 355)


def _s(px: float) -> float:
    return (CENTRE_PX - px) * MPP


def _y(py: float) -> float:
    return (STRAP_MID - py) * MPP


def _uv(px: float, py: float) -> tuple[float, float]:
    return (px / BAND_W, 1.0 - py / BAND_H)


def build_belt(parts: dict[str, Part], prefix: str, frame) -> None:
    """The whole belt along a path. `frame(s)` gives (point, along, out) for
    belt coordinate s: the strap's centre line and its outward face."""
    art, gold, strap, snap = (parts[prefix + k] for k in ("Art", "Gold", "Strap", "Snap"))
    s_end = _s(0.0)
    # The strap: a band STRAP_HEIGHT tall, 8 mm thick, following the path.
    steps = 64
    for i in range(steps):
        s0 = -s_end + 2.0 * s_end * i / steps
        s1 = -s_end + 2.0 * s_end * (i + 1) / steps
        p0, _, _ = frame(s0)
        p1, _, _ = frame(s1)
        pm, along, out = frame(0.5 * (s0 + s1))
        up = out.cross(along).normalized()
        framed_box(strap, pm, along, up, out,
                   Vector(((p1 - p0).length + 0.001, STRAP_HEIGHT, 0.008)))
    # The plates: a raised slab each, bent along the path in columns, with
    # the art on its face.
    for name, (x0, y0, x1, y1) in sorted(LAYOUT["plates"].items()):
        depth = PLATE_DEPTH.get(name, PLATE_DEPTH_DEFAULT)
        cols = max(2, int(round((x1 - x0) / LAYOUT["column_px"])))
        slabs = LAYOUT["slabs"][name]
        for c in range(cols):
            pa = x0 + (x1 - x0) * c / cols
            pb = x0 + (x1 - x0) * (c + 1) / cols
            sa, sb = _s(pa), _s(pb)
            qa, _, oa = frame(sa)
            qb, _, ob = frame(sb)
            face = 0.004 + depth
            top, bottom = _y(y0), _y(y1)
            corners = [qa + oa * face + Vector((0, bottom, 0)),
                       qb + ob * face + Vector((0, bottom, 0)),
                       qb + ob * face + Vector((0, top, 0)),
                       qa + oa * face + Vector((0, top, 0))]
            art.quad_at(*corners, uvs=[_uv(pa, y1), _uv(pb, y1), _uv(pb, y0), _uv(pa, y0)])
            # The slab behind the art gives the plate its depth from the
            # side. Built to the rows that are solid plate in this column
            # (measured off the cut-out art, build_title_textures.py) and a
            # little inside them, so no edge of it shows past the outline.
            span = slabs[c]
            if span is None:
                continue
            pm, along, out = frame(0.5 * (sa + sb))
            up = out.cross(along).normalized()
            s_top, s_bottom = _y(span[0]) - 0.007, _y(span[1]) + 0.007
            if s_top <= s_bottom:
                continue
            # Its front face 1.5 mm behind the art's, or the two z-fight
            # and the slab's flat gold wins over the artwork.
            framed_box(gold, pm + out * (0.004 + depth * 0.5 - 0.0015)
                       + Vector((0, 0.5 * (s_top + s_bottom), 0)), along, up, out,
                       Vector((abs(sb - sa) * 0.9, s_top - s_bottom, depth)))
    # Snaps at both ends.
    for px in SNAP_COLS_PX:
        for end in (px, BAND_W - px):
            for py in SNAP_ROWS_PX:
                p, along, out = frame(_s(end))
                centre = p + out * 0.004 + Vector((0, _y(py), 0))
                # A brass grommet: a ring, the leather showing through it.
                ring = []
                for k in range(11):
                    ang = 2.0 * math.pi * k / 10.0
                    ring.append(centre + along * (0.0085 * math.cos(ang))
                                + Vector((0, 0.0085 * math.sin(ang), 0)))
                snap.tube(ring, 0.0032, sides=5, caps=False)


## Roman's waist at the height the belt sits (y 1.05, just under the
## waistband of his trunks at 1.08-1.11), measured off M_Bottoms in
## roman_reigns.glb: 0.36 m across, 0.26 m front to back, its centre 2.4 cm
## forward of the hips bone's line.
WAIST_HALF_X = 0.19
WAIST_HALF_Z = 0.14
WAIST_FORWARD = 0.024
WAIST_LIFT = 0.075


def _waist_point(t: float) -> Vector:
    """A point on the belt line, t in [0, 1): 0 at the buckle (front, -Z),
    going round his RIGHT (+X) side."""
    a = 2.0 * math.pi * t
    return Vector((WAIST_HALF_X * math.sin(a), 0.0,
                   -WAIST_FORWARD - WAIST_HALF_Z * math.cos(a)))


def build_title_waist(parts: dict[str, Part]) -> None:
    """Worn round his waist: the belt path is his measured waist, the centre
    plate at the front, the ends meeting at his back. Authored for Roman at
    his measured size -- EntranceProps puts it on at 1:1 -- origin at his
    hips bone, the belt line WAIST_LIFT above it."""
    count = 720
    pts = [_waist_point(i / count) for i in range(count + 1)]
    arc = [0.0]
    for a, b in zip(pts, pts[1:]):
        arc.append(arc[-1] + (b - a).length)
    perimeter = arc[-1]

    def frame(s: float):
        # s along the belt from the front centre, + round his right (+X).
        u = (s % perimeter)
        lo, hi = 0, len(arc) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if arc[mid] <= u:
                lo = mid
            else:
                hi = mid
        k = (u - arc[lo]) / max(arc[hi] - arc[lo], 1e-9)
        p = pts[lo].lerp(pts[hi], k) + Vector((0.0, WAIST_LIFT, 0.0))
        along = (pts[hi] - pts[lo]).normalized()
        out = Vector((p.x, 0.0, p.z + WAIST_FORWARD)).normalized()
        return p, along, out
    build_belt(parts, "Title", frame)


def build_title_held(parts: dict[str, Part]) -> None:
    """Held overhead: the belt straight across, plates facing forward (-Z),
    gripped at the middle of the strap just above the centre plate."""
    grip = Vector((0.0, -0.08, -0.02))

    def frame(s: float):
        return grip + Vector((s, 0.0, 0.0)), Vector((1.0, 0.0, 0.0)), Vector((0.0, 0.0, -1.0))
    build_belt(parts, "Held", frame)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)
    PROP_DIR.mkdir(parents=True, exist_ok=True)

    venue.reset_scene()
    parts = {name: Part(name) for name in FALA_COLORS}
    build_ula_fala(parts)
    venue.finish(parts, FALA_COLORS, smooth=frozenset({"FalaCord"}))
    venue.export_glb(PROP_DIR / "ula_fala.glb")
    print("ula_fala: %d triangles" % venue.triangle_count())

    venue.reset_scene()
    parts = {name: Part(name) for name in TITLE_COLORS}
    build_title_waist(parts)
    build_title_held(parts)
    venue.finish(parts, TITLE_COLORS, projected=frozenset({"TitleStrap", "HeldStrap"}))
    venue.export_glb(PROP_DIR / "aew_title.glb")
    print("aew_title: %d triangles" % venue.triangle_count())
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
