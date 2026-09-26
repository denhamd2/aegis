#!/usr/bin/env python3
"""Build Roman Reigns' entrance props in Blender, export as glTF.

Run:  tools/blender/build_venue.sh roman

Two files:

  game/assets/props/ula_fala.glb      the Samoan chief's necklace he wears to
                                      the ring (gauntlet/refs/entrances.md)
  game/assets/props/aew_title.glb     the AEW World Championship, in two
                                      shapes: TitleDraped over the left
                                      shoulder, TitleHeld straight in the hand

Authored in the WRESTLER'S OWN FRAME, game axes: +Y up, forward -Z (the
controller's convention, WrestlerController._turn_toward_opponent), so +X is
his RIGHT and his left shoulder is at -X. Every prop's origin is the point it
hangs from:

  ula fala   the base of the neck (the neck_01 bone's head)
  draped     the top of the left shoulder (upperarm_l's head)
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
    "TitleGold": (1.0, 0.77, 0.34, 1.0),
    "TitleStrap": (0.03, 0.03, 0.03, 1.0),
    "TitleGem": (0.9, 0.9, 0.95, 1.0),
    "HeldGold": (1.0, 0.77, 0.34, 1.0),
    "HeldStrap": (0.03, 0.03, 0.03, 1.0),
    "HeldGem": (0.9, 0.9, 0.95, 1.0),
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

def build_plates(part_gold: Part, part_gem: Part, center: Vector,
                 right: Vector, up: Vector, out: Vector) -> None:
    """The plates, laid on the strap: a big centre plate and two side plates
    each side, gold, with a raised rim and a stone in the middle.

    Proportions of a heavyweight title: the centre plate ~0.26 wide and
    ~0.22 tall against a 0.10 strap; side plates ~0.09 x 0.11."""
    # Centre plate: a stack of three, stepping out, for the relief.
    framed_box(part_gold, center + out * 0.004, right, up, out,
               Vector((0.26, 0.21, 0.008)))
    framed_box(part_gold, center + out * 0.010, right, up, out,
               Vector((0.21, 0.17, 0.006)))
    framed_box(part_gold, center + out * 0.015, right, up, out,
               Vector((0.15, 0.12, 0.005)))
    # The crest: a raised vertical bar and a stone.
    framed_box(part_gold, center + out * 0.019 + up * 0.035, right, up, out,
               Vector((0.03, 0.09, 0.004)))
    framed_box(part_gem, center + out * 0.020 - up * 0.02, right, up, out,
               Vector((0.035, 0.035, 0.008)))
    for side in (-1.0, 1.0):
        for k, offset in enumerate((0.20, 0.31)):
            c = center + right * side * offset + out * 0.004
            framed_box(part_gold, c, right, up, out,
                       Vector((0.085, 0.10 - 0.012 * k, 0.007)))
            framed_box(part_gold, c + out * 0.006, right, up, out,
                       Vector((0.060, 0.075 - 0.012 * k, 0.004)))


def strap_along(part: Part, path: list[Vector], normal_hint: Vector,
                width: float = 0.10, thickness: float = 0.006) -> None:
    """The leather strap swept along a polyline, flat face toward `normal_hint`."""
    for i in range(len(path) - 1):
        a, b = path[i], path[i + 1]
        along = (b - a).normalized()
        n = (normal_hint - along * normal_hint.dot(along)).normalized()
        across = n.cross(along).normalized()
        framed_box(part, (a + b) * 0.5, along, across, n,
                   Vector(((b - a).length + 0.002, width, thickness)))


def build_title_held(parts: dict[str, Part]) -> None:
    """Held overhead: the belt straight across, plates facing forward (-Z),
    gripped at the middle of the strap just above the centre plate."""
    right = Vector((1.0, 0.0, 0.0))
    up = Vector((0.0, 1.0, 0.0))
    out = Vector((0.0, 0.0, -1.0))
    center = Vector((0.0, -0.08, -0.02))
    path = [center + right * (-0.62 + 1.24 * i / 12.0) for i in range(13)]
    strap_along(parts["HeldStrap"], path, out)
    build_plates(parts["HeldGold"], parts["HeldGem"], center, right, up, out)


def build_title_draped(parts: dict[str, Part]) -> None:
    """Over the left shoulder: folded across the top of it, the centre plate
    lying on the front of the shoulder and the chest, the ends hanging down
    front and back. The strap's curve is an arc over the shoulder's top."""
    path = []
    for i in range(17):
        s = i / 16.0
        # From down the back (s=0) over the top (s=0.5) to down the front.
        ang = math.pi * (s - 0.5)          # -90 back .. +90 front
        r = 0.085
        z = -r * math.sin(ang)             # forward is -Z: front is +ang
        y = r * math.cos(ang) + 0.01
        # Past the shoulder the strap hangs straight down.
        if abs(ang) > math.radians(70):
            drop = (abs(ang) - math.radians(70)) * 0.9
            y -= drop
        # -X: out over his LEFT shoulder's point, not in toward the neck.
        path.append(Vector((-0.02, y, z)))
    # Extend both ends straight down.
    back_end, front_end = path[0], path[-1]
    path = [back_end + Vector((0, -0.22, 0))] + path + [front_end + Vector((0, -0.22, 0))]
    strap_along(parts["TitleStrap"], path, Vector((1.0, 0.0, 0.0)))
    # The centre plate on the front slope, facing forward and slightly up.
    center = Vector((-0.02, -0.06, -0.12))
    out = Vector((0.0, 0.25, -1.0)).normalized()
    right = Vector((1.0, 0.0, 0.0))
    up = out.cross(right).normalized() * -1.0
    build_plates(parts["TitleGold"], parts["TitleGem"], center, right, up, out)


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
    build_title_draped(parts)
    build_title_held(parts)
    venue.finish(parts, TITLE_COLORS)
    venue.export_glb(PROP_DIR / "aew_title.glb")
    print("aew_title: %d triangles" % venue.triangle_count())
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
