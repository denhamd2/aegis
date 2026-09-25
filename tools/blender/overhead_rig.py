#!/usr/bin/env python3
"""Build the overhead lighting rig and the moving-head fixture, export as glTF.

Run:  tools/blender/build_venue.sh rig

Two files come out of this:

  game/assets/environment/overhead_rig.glb   the steel: truss, battens, booms,
                                              roof joists, speaker arrays, and
                                              the LED strips on the truss
  game/assets/environment/moving_head.glb    one fixture body, in four parts,
                                              that `ArenaLighting` hangs at
                                              every light it builds

Why this exists
---------------
Every AEW still in `gauntlet/refs/lighting/` shows the rig: truss lit against
a dark roof, rows of fixture bodies with hot lenses, LED edge strips, roof
steel washed in colour, speaker arrays hanging off the grid. The build had a
bare grid over the ring and a black slab above it. Worse, the grid did not
hold the fixtures: its inner lines were at +-2.5 and the ring keys hang at
+-3.9, and the beam fixtures added over the bowl hung 17m up from nothing.

So the steel is placed FROM the fixtures, not the other way round. Every
hanging position is a plain constant in `core/lighting/arena_lighting.gd`,
read here with `venue.read_constants`, and each truss is put where the
fixtures on it need it to be. Move a fixture there, rebuild this, and the
steel follows it.

The fixture
-----------
Built in its own frame so the GDScript can articulate it the way a real
moving head is: the BASE is fixed to the steel, the YOKE pans about the
vertical, and the HEAD tilts inside the yoke to point where the light points.
The origin of every part is the head's tilt axis, which is where the
SpotLight3D sits -- so placing the fixture at the light's position and giving
the head the light's basis puts the lens on the beam by construction.

  y +FIXTURE_TOP .. +FIXTURE_TOP-0.12   base (the clamp end)
  y +0.20                              yoke crossbar
  head: a can along -Z, lens at -Z     (-Z is a Godot light's forward)

Deterministic: same constants in, byte-identical .glb out.
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

import arena_bowl  # noqa: E402 -- the plan curve and the row schedule
import bpy_exit  # noqa: E402

LIGHTING_GD = venue.REPO / "game" / "core" / "lighting" / "arena_lighting.gd"
LIGHTING_WANTED = [
    "TRUSS_Y", "ROOF_Y", "BOWL_INNER", "STAGE_BACK_Z",
    "KEY_OFFSET", "TOP_OFFSET_Z", "BEAM_INSET", "BEAM_DROP",
    "HOUSE_INSET", "HOUSE_DROP", "STAGE_WASH_X", "STAGE_WASH_Y",
    "STAGE_WASH_DZ", "ACCENT_Y", "ACCENT_DZ", "ACCENT_FAR_X",
    "RIM_X", "RIM_Y", "RIM_Z",
    "UPLIGHT_NEAR_X", "UPLIGHT_FAR_X", "UPLIGHT_Y", "UPLIGHT_DZ",
]
ARENA_WANTED = ["FLOOR_Y", "STAGE_DECK_Y", "STAGE_HALF_WIDTH"]

## Height of the fixture's clamp face above the head's tilt axis. The steel
## a fixture hangs from starts here. Mirrored as `ArenaLighting.FIXTURE_TOP`.
FIXTURE_TOP = 0.32

## Truss sections. The ring grid keeps the 0.42 section it always had; the
## perimeter rings span further and carry more, so they are the heavier 0.52.
RING_GRID_SIZE = 0.42
PERIMETER_SIZE = 0.52
## The ring grid's outer lines and reach, unchanged from entrance_set.py.
GRID_OUTER = 7.5
GRID_REACH = 11.0

## How far below a truss's bottom chord its LED strip runs.
LED_DROP = 0.05
LED_RADIUS = 0.025

PART_COLORS = {
    "RigTruss": (0.55, 0.57, 0.60, 1.0),
    "RoofSteel": (0.14, 0.14, 0.16, 1.0),
    "RigLeds": (0.20, 0.62, 1.00, 1.0),
    "SpeakerArrays": (0.03, 0.03, 0.035, 1.0),
}
FIXTURE_COLORS = {
    "FixtureBase": (0.04, 0.04, 0.045, 1.0),
    "FixtureYoke": (0.05, 0.05, 0.055, 1.0),
    "FixtureHead": (0.04, 0.04, 0.045, 1.0),
    "FixtureLens": (1.0, 1.0, 1.0, 1.0),
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def truss_run(parts: dict[str, Part], start: Vector, end: Vector,
              size: float, led: bool = True, sides: int = 6) -> None:
    """One lattice run, plus its LED strip along the bottom.

    `sides` is the tube section. The perimeter rings are 17-20m up and use 4:
    at that distance a square and a hexagonal tube are the same pixels, and it
    takes the rig from 73k triangles to under 50k.
    """
    parts["RigTruss"].lattice(start, end, size=size, bay=1.6,
                              chord_radius=0.055 if size < 0.5 else 0.065,
                              diagonal_radius=0.028 if size < 0.5 else 0.032,
                              sides=sides)
    if led:
        drop = Vector((0.0, -(size * 0.5 + LED_DROP), 0.0))
        parts["RigLeds"].tube([start + drop, end + drop], LED_RADIUS, sides=6)


def drop_line(parts: dict[str, Part], at: Vector, roof_y: float) -> None:
    """A chain-motor drop from a truss's top chord to the roof steel."""
    parts["RigTruss"].tube([at, Vector((at.x, roof_y, at.z))], 0.03, sides=6)


def perimeter_points(cfg: dict[str, float], offset: float) -> list[Vector]:
    """The plan curve at `offset`, thinned for truss.

    Each quarter of `arena_bowl.plan_loop` is one straight (whose points are
    collinear, so only its start is needed) and a corner of
    BOWL_CORNER_SEGMENTS points. Keeping every fourth corner point turns the
    semicircular ends into chords of ~2.6m -- which is what real perimeter
    truss is: straight sections on corner blocks, not a bent tube.
    """
    loop = arena_bowl.plan_loop(cfg, offset)
    straight_n = int(cfg["BOWL_STRAIGHT_SEGMENTS"])
    corner_n = int(cfg["BOWL_CORNER_SEGMENTS"])
    block = straight_n + corner_n
    out = []
    for i, (point, _) in enumerate(loop):
        k = i % block
        if k == 0 or (k >= straight_n and (k - straight_n) % 4 == 0):
            out.append(point)
    return out


def perimeter_ring(parts: dict[str, Part], cfg: dict[str, float],
                   offset: float, y: float, roof_y: float,
                   drops: int) -> None:
    points = [Vector((p.x, y, p.z)) for p in perimeter_points(cfg, offset)]
    for i, a in enumerate(points):
        b = points[(i + 1) % len(points)]
        truss_run(parts, a, b, PERIMETER_SIZE, sides=4)
    step = len(points) / drops
    for d in range(drops):
        p = points[int(d * step)]
        drop_line(parts, p + Vector((0.0, PERIMETER_SIZE * 0.5, 0.0)), roof_y)


# ---------------------------------------------------------------------------
# The rig
# ---------------------------------------------------------------------------

def build_ring_grid(lc: dict[str, float], parts: dict[str, Part]) -> None:
    """The grid over the ring, with its inner lines where the keys hang.

    The keys hang at HANG_Y = TRUSS_Y - 0.35 (arena_lighting.gd); the grid
    sits so their clamps meet its bottom chord. That is 0.18m higher than the
    grid entrance_set.py used to build, which a fixture body 0.32m tall would
    otherwise have been buried in.
    """
    hang_y = lc["TRUSS_Y"] - 0.35
    y = hang_y + FIXTURE_TOP + RING_GRID_SIZE * 0.5
    offsets = (-GRID_OUTER, -lc["KEY_OFFSET"], lc["KEY_OFFSET"], GRID_OUTER)
    # LED strips on the outer box only. In the references the edge lines trace
    # the rig's outline; lit on every line, the inner pair criss-crossed the
    # frame over the ring on every upward shot.
    for offset in offsets:
        outer = abs(offset) == GRID_OUTER
        truss_run(parts, Vector((-GRID_REACH, y, offset)),
                  Vector((GRID_REACH, y, offset)), RING_GRID_SIZE, led=outer)
        truss_run(parts, Vector((offset, y, -GRID_REACH)),
                  Vector((offset, y, GRID_REACH)), RING_GRID_SIZE, led=outer)
    for x in (-GRID_OUTER, GRID_OUTER):
        for z in (-GRID_OUTER, GRID_OUTER):
            drop_line(parts, Vector((x, y + RING_GRID_SIZE * 0.5, z)),
                      lc["ROOF_Y"] - 1.3)

    # The two top fills hang 0.2 higher than the keys, between the key lines:
    # a pipe batten across, ends into the truss either side.
    batten_y = hang_y + 0.2 + FIXTURE_TOP + 0.03
    for sz in (-1.0, 1.0):
        z = sz * lc["TOP_OFFSET_Z"]
        parts["RigTruss"].tube([Vector((-lc["KEY_OFFSET"], batten_y, z)),
                                Vector((lc["KEY_OFFSET"], batten_y, z))],
                               0.03, sides=8)

    # The rim pair hangs forward of the upstage line on a short drop arm.
    chord_y = y - RING_GRID_SIZE * 0.5
    for sx in (-1.0, 1.0):
        x = sx * lc["RIM_X"]
        parts["RigTruss"].tube([Vector((x, chord_y, -GRID_OUTER)),
                                Vector((x, lc["RIM_Y"] + FIXTURE_TOP, lc["RIM_Z"]))],
                               0.03, sides=8)


def build_perimeter(cfg: dict[str, float], lc: dict[str, float],
                    parts: dict[str, Part]) -> None:
    """The beam ring and the house ring, on the bowl's own plan curve."""
    beam_y = lc["ROOF_Y"] - lc["BEAM_DROP"] + FIXTURE_TOP + PERIMETER_SIZE * 0.5
    perimeter_ring(parts, cfg, lc["BOWL_INNER"] - lc["BEAM_INSET"], beam_y,
                   lc["ROOF_Y"] - 1.3, drops=12)
    house_y = lc["ROOF_Y"] - lc["HOUSE_DROP"] + FIXTURE_TOP + PERIMETER_SIZE * 0.5
    perimeter_ring(parts, cfg, lc["BOWL_INNER"] - lc["HOUSE_INSET"], house_y,
                   lc["ROOF_Y"] - 1.3, drops=12)


def build_stage_steel(lc: dict[str, float], ac: dict[str, float],
                      parts: dict[str, Part]) -> None:
    """The stage-wash truss, the accent boom and the uplight stands."""
    z = lc["STAGE_BACK_Z"] + lc["STAGE_WASH_DZ"]
    y = lc["STAGE_WASH_Y"] + FIXTURE_TOP + PERIMETER_SIZE * 0.5
    reach = lc["STAGE_WASH_X"] + 2.0
    truss_run(parts, Vector((-reach, y, z)), Vector((reach, y, z)), PERIMETER_SIZE)
    for sx in (-1.0, 1.0):
        drop_line(parts, Vector((sx * reach, y + PERIMETER_SIZE * 0.5, z)),
                  lc["ROOF_Y"] - 1.3)

    # Accent boom: a pipe across the set just above the accents, on two
    # uprights standing on the deck outside the portal rings.
    bz = lc["STAGE_BACK_Z"] + lc["ACCENT_DZ"]
    by = lc["ACCENT_Y"] + FIXTURE_TOP + 0.03
    post = ac["STAGE_HALF_WIDTH"] - 0.1
    parts["RigTruss"].tube([Vector((-post, by, bz)), Vector((post, by, bz))],
                           0.035, sides=8)
    for sx in (-1.0, 1.0):
        parts["RigTruss"].tube([Vector((sx * post, ac["STAGE_DECK_Y"], bz)),
                                Vector((sx * post, by + 0.05, bz))], 0.045, sides=8)

    # Uplights stand on the arena floor beside the set: a short pole each.
    uz = lc["STAGE_BACK_Z"] + lc["UPLIGHT_DZ"]
    top = lc["UPLIGHT_Y"] - FIXTURE_TOP
    for sx in (-1.0, 1.0):
        for x in (lc["UPLIGHT_NEAR_X"], lc["UPLIGHT_FAR_X"]):
            parts["RigTruss"].tube([Vector((sx * x, ac["FLOOR_Y"], uz)),
                                    Vector((sx * x, top, uz))], 0.04, sides=8)
            parts["RigTruss"].cylinder(Vector((sx * x, ac["FLOOR_Y"], uz)),
                                       Vector((0.0, 1.0, 0.0)), 0.25, 0.03, sides=12)


def build_roof_steel(cfg: dict[str, float], lc: dict[str, float],
                     parts: dict[str, Part]) -> None:
    """Open-web joists under the roof slab, clipped to the obround shell.

    Two chords and a zigzag web: the steel a real arena roof is carried on,
    and what the references show lit from below. Each joist spans x at one z
    and stops half a metre inside the wall, which on the curved ends is
    solved on the circle rather than the rectangle.
    """
    rows = arena_bowl.row_schedule(cfg)
    wall = next(r for r in rows if r["kind"] == "outer")["inner"] + 1.2 - 0.5
    ax, az = cfg["BOWL_STRAIGHT_X"], cfg["BOWL_STRAIGHT_Z"]
    top = lc["ROOF_Y"] - 0.06
    bottom = top - 1.2
    part = parts["RoofSteel"]
    spacing = 7.0
    count = int((az + wall) // spacing)
    for k in range(-count, count + 1):
        z = k * spacing
        dz = max(abs(z) - az, 0.0)
        if dz >= wall:
            continue
        half = ax + math.sqrt(wall * wall - dz * dz)
        a, b = -half, half
        part.tube([Vector((a, top, z)), Vector((b, top, z))], 0.07, sides=4)
        part.tube([Vector((a + 0.6, bottom, z)), Vector((b - 0.6, bottom, z))],
                  0.06, sides=4)
        bays = max(int((b - a - 1.2) / 1.5), 1)
        for i in range(bays):
            x0 = a + 0.6 + (b - a - 1.2) * i / bays
            x1 = a + 0.6 + (b - a - 1.2) * (i + 1) / bays
            xm = (x0 + x1) * 0.5
            part.tube([Vector((x0, bottom, z)), Vector((xm, top, z))], 0.025, sides=4)
            part.tube([Vector((xm, top, z)), Vector((x1, bottom, z))], 0.025, sides=4)


def build_speaker_arrays(cfg: dict[str, float], lc: dict[str, float],
                         parts: dict[str, Part]) -> None:
    """Four line arrays off the beam ring's long sides, facing the floor.

    A line array is a column of boxes that curves at the bottom (the "J") so
    its lower cabinets throw at the near seats. Ten cabinets each, the splay
    opening from 0 to ~5 degrees per cabinet toward the bottom.
    """
    offset = lc["BOWL_INNER"] - lc["BEAM_INSET"]
    chord_y = lc["ROOF_Y"] - lc["BEAM_DROP"] + FIXTURE_TOP
    x_line = cfg["BOWL_STRAIGHT_X"] + offset
    part = parts["SpeakerArrays"]
    for sx in (-1.0, 1.0):
        for z in (-9.0, 9.0):
            # Hung inboard of the truss so the column clears it.
            anchor = Vector((sx * (x_line - 0.9), chord_y, z))
            part.tube([Vector((sx * x_line, chord_y + 0.05, z)), anchor],
                      0.02, sides=4)
            y = chord_y - 0.25
            angle = 0.0
            x = anchor.x
            for cabinet in range(10):
                angle += math.radians(0.3 + 0.55 * cabinet)
                # Face inward (toward -sx) and tilt the face down by `angle`.
                out = Vector((-sx * math.cos(angle), -math.sin(angle), 0.0))
                along = Vector((0.0, 0.0, 1.0))
                center = Vector((x, y - 0.18, z))
                up = out.cross(along).normalized()
                half_h = up * 0.17
                half_w = along * 0.55
                half_d = out * 0.28
                corners = [center + half_w * a + half_h * b + half_d * c
                           for a, b, c in ((-1, -1, -1), (1, -1, -1), (1, -1, 1),
                                           (-1, -1, 1), (-1, 1, -1), (1, 1, -1),
                                           (1, 1, 1), (-1, 1, 1))]
                v = [part.vert(c) for c in corners]
                for face in ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
                             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
                    part.quad(*[v[i] for i in face])
                y -= 0.36 * math.cos(angle)
                x += sx * 0.36 * math.sin(angle) * 0.5


# ---------------------------------------------------------------------------
# The fixture
# ---------------------------------------------------------------------------

def build_fixture(parts: dict[str, Part]) -> None:
    """One moving head, origin at the head's tilt axis, lens toward -Z."""
    base = parts["FixtureBase"]
    base.box(Vector((0.0, FIXTURE_TOP - 0.06, 0.0)), Vector((0.40, 0.12, 0.34)),
             bevel=0.015)
    yoke = parts["FixtureYoke"]
    yoke.box(Vector((0.0, 0.215, 0.0)), Vector((0.40, 0.05, 0.14)))
    for sx in (-1.0, 1.0):
        yoke.box(Vector((sx * 0.185, 0.07, 0.0)), Vector((0.04, 0.30, 0.12)))
    head = parts["FixtureHead"]
    head.cylinder(Vector((0.0, 0.0, 0.12)), Vector((0.0, 0.0, -1.0)), 0.14,
                  0.30, sides=16)
    # Trunnions into the yoke arms.
    for sx in (-1.0, 1.0):
        head.cylinder(Vector((sx * 0.13, 0.0, 0.0)), Vector((sx, 0.0, 0.0)),
                      0.035, 0.045, sides=8)
    lens = parts["FixtureLens"]
    lens.cylinder(Vector((0.0, 0.0, -0.175)), Vector((0.0, 0.0, -1.0)), 0.11,
                  0.012, sides=16)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(venue.ASSET_DIR / "overhead_rig.glb"))
    parser.add_argument("--fixture-out",
                        default=str(venue.ASSET_DIR / "moving_head.glb"))
    args = parser.parse_args(argv)

    lc = venue.read_constants(LIGHTING_GD, LIGHTING_WANTED)
    ac = venue.read_constants(venue.ARENA_GD, ARENA_WANTED)
    cfg = arena_bowl.read_constants(arena_bowl.BUILDER_GD)

    venue.reset_scene()
    parts = {name: Part(name) for name in PART_COLORS}
    build_ring_grid(lc, parts)
    build_perimeter(cfg, lc, parts)
    build_stage_steel(lc, ac, parts)
    build_roof_steel(cfg, lc, parts)
    build_speaker_arrays(cfg, lc, parts)
    venue.finish(parts, PART_COLORS, emissive=frozenset({"RigLeds"}),
                 smooth=frozenset({"RigTruss", "RigLeds"}),
                 projected=frozenset({"RigTruss", "RoofSteel"}))
    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("overhead_rig: %d triangles, %s" % (venue.triangle_count(), out))

    venue.reset_scene()
    parts = {name: Part(name) for name in FIXTURE_COLORS}
    build_fixture(parts)
    venue.finish(parts, FIXTURE_COLORS, emissive=frozenset({"FixtureLens"}),
                 smooth=frozenset({"FixtureHead", "FixtureLens"}))
    fixture_out = pathlib.Path(args.fixture_out)
    venue.export_glb(fixture_out)
    print("moving_head: %d triangles, %s" % (venue.triangle_count(), fixture_out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
