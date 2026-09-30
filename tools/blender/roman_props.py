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
    round the right side, down to its lowest point on the chest, and back up
    the left. Origin at neck_01; forward is -Z. Authored at Roman's own size
    in metres (EntranceProps fits it 1:1), off his body as measured from
    M_Body: the neck 0.18 m across at its base, the trapezius sloping out to
    +-0.24 m, the chest 0.16 m proud of the neck line 0.15 m down.

    Behind, it sits on the trapezius at the base of the neck (z +0.075); over
    the shoulders it rides the trapezius slope 0.125 m out; in front it drapes
    to 0.20 m below the neck onto the upper chest. That is a cord of about
    0.78 m, and with the keys hanging off it an inner edge of ~0.62 m -- the
    24-26 inches Roman's is worn at, and the 600 mm of Te Papa's 'ulafala."""
    a = 2.0 * math.pi * t
    # Measured off his posed skin (tools/probe/fala_shot.gd's fit pass): the
    # trapezius tops out 0.07 m ABOVE neck_01 at 0.14 m out, 0.056 m at the
    # back 0.17 m out; the chest's front is 0.11 m ahead of it by 0.15 m down.
    # So the cord rides up over the traps and drops onto the chest.
    x = 0.158 * math.sin(a)
    z = -0.01 + 0.16 * math.cos(a)
    front = (1.0 - math.cos(a)) * 0.5
    # Snug on the shoulders (the owner: "floating a little"): the sides sit
    # down on the trapezius, 1.5 cm lower than the first fit, and slightly
    # further out where the muscle is lower.
    y = 0.045 + 0.018 * math.sin(a) ** 2 - 0.195 * front ** 3.2
    return Vector((x, y, z))


def ellipsoid(part: Part, center: Vector, ax: Vector, ay: Vector, az: Vector,
              radii: Vector, seg: int = 8, rings: int = 5) -> None:
    """A low-poly ellipsoid on an arbitrary frame (radii along ax, ay, az)."""
    rows = []
    for r in range(rings + 1):
        phi = math.pi * r / rings - math.pi * 0.5
        row = []
        for s in range(seg):
            th = 2.0 * math.pi * s / seg
            p = (ax * (radii.x * math.cos(phi) * math.cos(th))
                 + ay * (radii.y * math.cos(phi) * math.sin(th))
                 + az * (radii.z * math.sin(phi)))
            row.append(part.vert(center + p))
        rows.append(row)
    for r in range(rings):
        for s in range(seg):
            n = (s + 1) % seg
            part.quad(rows[r][s], rows[r][n], rows[r + 1][n], rows[r + 1][s])


## The keys: how many round the loop, and how big (metres, along the cord,
## off the body, out from the neck). A pandanus key is a wedge about 5 cm
## long: a narrow fibrous base where it is strung, a broad rounded red end.
## Te Papa's 'ulafala is a band 70 mm wide; the keys lie FLAT on the wearer,
## fanned out from the neck across the chest and over the shoulders, so the
## band is wide and thin -- about 2 cm off the skin, not a ring standing off
## it. Seeded jitter, so the file is identical on every build.
FALA_KEYS = 84
FALA_KEY = Vector((0.027, 0.019, 0.052))
FALA_SEED = 3


def build_ula_fala(parts: dict[str, Part]) -> None:
    """The pandanus keys of a chief's ula fala, packed on a cord.

    The second build stood every key straight out from the neck, level, so on
    his chest they pointed at the camera and the garland read as a thick red
    ring round his throat -- chunky, and 4 cm proud of him. A real one drapes:
    each key lies along the body, its broad end pointing away from the neck --
    down the chest in front, down the back behind, out over the shoulder at
    the sides. So each key is built on the body's own surface frame at that
    point: `n` the skin's normal (forward on the chest, up on the shoulder),
    `out` the way down the skin away from the neck, and the key's two
    ellipsoids -- an orange base at the cord, a larger red tip beyond -- are
    thin along `n`.
    """
    import random
    rng = random.Random(FALA_SEED)
    for i in range(FALA_KEYS):
        t0, t1 = i / FALA_KEYS, (i + 1) / FALA_KEYS
        p0, p1 = fala_curve(t0), fala_curve(t1)
        center = (p0 + p1) * 0.5
        along = (p1 - p0).normalized()
        ang = 2.0 * math.pi * (t0 + t1) * 0.5
        side = abs(math.sin(ang))
        radial = Vector((center.x, 0.0, center.z + 0.0325))
        if radial.length < 1e-4:
            radial = Vector((0.0, 0.0, -1.0))
        radial.normalize()
        n = (radial * (1.0 - side) + Vector((0.0, 1.0, 0.0)) * side).normalized()
        out = n.cross(along).normalized()
        want = radial * side + Vector((0.0, -1.0, 0.0)) * (1.0 - side)
        if out.dot(want) < 0.0:
            out = -out
        n = along.cross(out).normalized()
        if n.dot(Vector((0.0, 1.0, 0.0)) * side + radial * (1.0 - side)) < 0.0:
            n = -n
        # Neighbours overlap and lie a little over one another, and none
        # hangs exactly like the next: a small fan about the cord.
        fan = (0.22 if i % 2 else -0.22) + rng.uniform(-0.10, 0.10)
        out2 = (out * math.cos(fan) + n * math.sin(fan) * 0.35).normalized()
        n2 = along.cross(out2).normalized()
        if n2.dot(n) < 0.0:
            n2 = -n2
        k = 1.0 + rng.uniform(-0.10, 0.10)
        size = Vector((FALA_KEY.x * k, FALA_KEY.y * k, FALA_KEY.z * k))
        lift = n2 * (size.y * 0.35)
        ellipsoid(parts["FalaOrange"], center + out2 * (size.z * 0.22) + lift, along, n2, out2,
                  Vector((size.x * 0.34, size.y * 0.36, size.z * 0.26)), seg=6, rings=4)
        ellipsoid(parts["FalaRed"], center + out2 * (size.z * 0.62) + lift, along, n2, out2,
                  Vector((size.x * 0.50, size.y * 0.50, size.z * 0.36)), seg=8, rings=5)
    # The cord the keys hang on, visible between them.
    path = [fala_curve(i / 64.0) for i in range(65)]
    parts["FalaCord"].tube(path, 0.004, sides=6)


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


## Roman's waist, as the belt must clear it. The first cut was one rest-pose
## ellipse (0.19 x 0.14 m, centre 2.4 cm forward), and in the owner's video
## the plates sat inside his stomach. tools/probe/wear_clearance.tscn then
## measured every torso vertex in the belt's height band (the centre plate
## runs from 4 cm under the hips bone to 20 cm over it, up onto his belly)
## on every fifth frame of his entrance: his belly stands 0.21 m in front of
## the hips bone and his seat 0.15 m behind, and he is 0.21 m to a side.
## So the belt line is two half-ellipses -- a deeper one in front -- fitted
## to clear 99.9% of those points by 17 mm (the strap's inner face is 4 mm
## inside the line); the rest come within 2 mm of it, on single frames.
WAIST_HALF_X = 0.225
WAIST_FRONT = 0.225
WAIST_BACK = 0.165
WAIST_LIFT = 0.075


def _waist_point(t: float) -> Vector:
    """A point on the belt line, t in [0, 1): 0 at the buckle (front, -Z),
    going round his RIGHT (+X) side."""
    a = 2.0 * math.pi * t
    depth = WAIST_FRONT if math.cos(a) > 0.0 else WAIST_BACK
    return Vector((WAIST_HALF_X * math.sin(a), 0.0, -depth * math.cos(a)))


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
        # The line's outward normal: along perpendicular to up.
        out = along.cross(Vector((0.0, 1.0, 0.0))).normalized()
        if out.dot(Vector((p.x, 0.0, p.z))) < 0.0:
            out = -out
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
