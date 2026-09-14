#!/usr/bin/env python3
"""Build the ringside floor, its panel joints and the barricades in Blender.

Run:  tools/blender/build_venue.sh ringside

What this builds
----------------
The event floor slab, the joints between the decking panels laid over the ice,
and the four runs of barricade around the ring.

What moving it buys
-------------------
Only one of the three gains anything from Blender, and it is said plainly
because the other two are here for completeness rather than for craft:

* **The barricades.** They were flat boxes: a panel, a cap rail and a leg,
  each a sharp-edged slab. A real barricade is a steel frame -- a panel with a
  chamfered edge, a ROUND capping rail, and a raking leg that is a tube. The
  cap rail is the part that matters: it is the only horizontal at ringside
  catching the house rig, it runs right across the wide shot at chest height,
  and a box cannot take a highlight along its length the way a tube does.
* **The floor slab** is one box and stays one box. It is here so the whole
  ringside is one model rather than half a model.
* **The panel joints** keep their analytic clip to the rink's own plan: at a
  given x the decking reaches `BOWL_STRAIGHT_Z + sqrt(r^2 - dx^2)`, so a joint
  stops where the decking does instead of running out over the seating. They
  are flat strips a hair above the floor rather than grooves cut into it -- a
  joint is 5 cm wide and a groove would need three faces where one strip is
  identical from every camera in the shotlist.

Dimensions are READ OUT OF `game/core/arena/arena_builder.gd`, never retyped.
"""

from __future__ import annotations

import argparse
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import venue  # noqa: E402 -- venue imports bpy, which registers mathutils
from venue import Part  # noqa: E402
from mathutils import Vector  # noqa: E402

WANTED = [
    "FLOOR_Y", "WALL_EXTENT", "WALL_EXTENT_X",
    "FLOOR_SEAM_PITCH", "FLOOR_SEAM_WIDTH",
    "RINK_HALF_LENGTH", "RINK_HALF_WIDTH", "RINK_CORNER_RADIUS",
    "BOWL_STRAIGHT_X", "BOWL_STRAIGHT_Z",
    "BARRICADE_RADIUS", "BARRICADE_HEIGHT", "BARRICADE_PANEL", "BARRICADE_JOIN",
    "BARRICADE_GAP", "RINGSIDE_MAT_LIFT", "RAMP_HALF_WIDTH",
]

# Placeholder colours only; arena_builder.gd overrides every part by name.
PART_COLORS = {
    "Floor": (0.14, 0.14, 0.16, 1.0),
    "RingsideMat": (0.035, 0.035, 0.040, 1.0),
    "FloorSeams": (0.09, 0.09, 0.10, 1.0),
    "Barricades": (0.30, 0.31, 0.34, 1.0),
}
SMOOTH = frozenset()
PROJECTED = frozenset(PART_COLORS)


def build_floor(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The slab.

    WALL_EXTENT_X on the long axis: the bowl reaches further down +-X than it
    does down +-Z, and a square slab under an obround hall leaves the back
    rows standing over nothing.
    """
    parts["Floor"].box(
        Vector((0.0, cfg["FLOOR_Y"] - 0.1, 0.0)),
        Vector((cfg["WALL_EXTENT_X"] * 2.0, 0.2, cfg["WALL_EXTENT"] * 2.0)),
    )


def build_seams(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The joints between the decking panels, clipped to the rink's plan."""
    seams = parts["FloorSeams"]
    r = cfg["RINK_CORNER_RADIUS"]

    def reach_z(x: float) -> float:
        dx = max(abs(x) - cfg["BOWL_STRAIGHT_X"], 0.0)
        return cfg["BOWL_STRAIGHT_Z"] + math.sqrt(max(r * r - dx * dx, 0.0))

    def reach_x(z: float) -> float:
        dz = max(abs(z) - cfg["BOWL_STRAIGHT_Z"], 0.0)
        return cfg["BOWL_STRAIGHT_X"] + math.sqrt(max(r * r - dz * dz, 0.0))

    pitch = cfg["FLOOR_SEAM_PITCH"]
    width = cfg["FLOOR_SEAM_WIDTH"]
    y = cfg["FLOOR_Y"] + 0.004
    steps = int(cfg["RINK_HALF_WIDTH"] / pitch)
    for i in range(-steps, steps + 1):
        at = i * pitch
        seams.box(Vector((at, y, 0.0)),
                  Vector((width, 0.008, reach_z(at) * 2.0)))
    steps = int(cfg["RINK_HALF_LENGTH"] / pitch)
    for i in range(-steps, steps + 1):
        at = i * pitch
        seams.box(Vector((0.0, y, at)),
                  Vector((reach_x(at) * 2.0, 0.008, width)))


def build_ringside_mat(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The black matting from the barrier in to the ring.

    A real ringside floor is not the bare deck: it is covered in interlocking
    rubber mats, and they are the dark ground the ring, the steps and the
    wrestlers working outside are all read against. It is also what the
    entrance ramp comes down ONTO -- the ramp stops at this mat's outer edge,
    and the mat carries the last few metres to the apron.

    Laid as one slab a few millimetres above the floor rather than as tiles.
    At every camera in the shotlist the joins between mats are below a pixel,
    and the ring, the steps and the barricade all stand on top of it.
    """
    reach = cfg["BARRICADE_RADIUS"]
    parts["RingsideMat"].box(
        Vector((0.0, cfg["FLOOR_Y"] + cfg["RINGSIDE_MAT_LIFT"] * 0.5, 0.0)),
        Vector((reach * 2.0, cfg["RINGSIDE_MAT_LIFT"], reach * 2.0)),
    )


def build_barricades(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Four runs of discrete panels, each with a round cap rail and a leg.

    Discrete rather than one continuous box per side, which from the wide
    camera is a featureless band with nothing in it to read scale off.

    The -Z run carries the entrance GAP. The ramp's foot lands on this line
    now, and without a gap the barrier would run straight through it -- which
    is what it did while the ramp ended further in and the barrier stood 3m
    further out.
    """
    barricade = parts["Barricades"]
    height = cfg["BARRICADE_HEIGHT"]
    y = cfg["FLOOR_Y"] + height * 0.5
    top = cfg["FLOOR_Y"] + height
    span = cfg["BARRICADE_RADIUS"] * 2.0
    panels = int(span / cfg["BARRICADE_PANEL"])
    pitch = span / panels
    width = pitch - cfg["BARRICADE_JOIN"]

    for out in (Vector((0.0, 0.0, 1.0)), Vector((0.0, 0.0, -1.0)),
                Vector((1.0, 0.0, 0.0)), Vector((-1.0, 0.0, 0.0))):
        along = Vector((out.z, 0.0, -out.x))
        line = out * cfg["BARRICADE_RADIUS"]
        entrance_run = out.z < -0.5
        for i in range(panels):
            t = (i + 0.5) / panels - 0.5
            at = line + along * (t * span)
            # Skip any panel that INTRUDES on the walkway, not just one
            # centred in it: a panel whose centre clears the gap by less than
            # its own half-width still puts its end through the opening, and
            # the first attempt left two of them standing in the entrance.
            if entrance_run and abs(at.x) - width * 0.5 < cfg["BARRICADE_GAP"]:
                continue
            panel_center = at + Vector((0.0, y, 0.0))
            barricade.oriented_box(panel_center, along, out,
                                   Vector((width, height, 0.14)))
            # The cap rail: a TUBE, because it is the only horizontal at
            # ringside at chest height and it runs across the whole wide
            # shot. A box takes a highlight on one facet; a tube takes one
            # along its length, which is what reads as steel.
            rail_y = top - 0.035
            half = along * (width * 0.5)
            barricade.tube(
                [at + Vector((0.0, rail_y, 0.0)) - half,
                 at + Vector((0.0, rail_y, 0.0)) + half],
                0.048, sides=8,
            )
            # One leg per panel, behind it, raking out to the floor. A tube
            # again: at ringside distance its silhouette is the whole of what
            # it contributes, and a round one is never seen edge-on as a line.
            barricade.tube(
                [at + Vector((0.0, top - 0.18, 0.0)),
                 at + out * 0.42 + Vector((0.0, cfg["FLOOR_Y"] + 0.02, 0.0))],
                0.028, sides=6,
            )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(venue.ASSET_DIR / "ringside.glb"))
    args = parser.parse_args(argv)

    cfg = venue.read_constants(venue.ARENA_GD, WANTED)
    venue.reset_scene()
    parts = {name: Part(name) for name in PART_COLORS}
    build_floor(cfg, parts)
    build_seams(cfg, parts)
    build_ringside_mat(cfg, parts)
    build_barricades(cfg, parts)
    venue.finish(parts, PART_COLORS, smooth=SMOOTH, projected=PROJECTED)

    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("ringside: %d triangles, %s" % (venue.triangle_count(), out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
