#!/usr/bin/env python3
"""Build the entrance set in Blender, export as glTF.

Run:  tools/blender/build_venue.sh entrance

What this builds
----------------
The stage deck and the ramp down to the floor, the backdrop the set stands
against, the curved video wall's bezel and its picture face, the centre
screen, and the 2026 set's two LED walls either side of it (the circular
portals they replaced are gone; see build_side_screens). The lighting truss that
used to be built here is `overhead_rig.py`'s now, with the rest of the rig.

The two things worth moving it for
----------------------------------
**The ramp is a wedge.** `arena_builder.gd` built it as a stack of
axis-aligned boxes and said why in its own comment: "`_add_box` only makes
axis-aligned boxes". The ramp is 25.7 m long and falls 1.45 m, so that was
**eighteen steps of 8 cm** standing in for a 6% grade. The note argued the
steps were under a pixel of rise from any camera in the shotlist, which is
true of the *treads* and not of the edge: a stepped ramp has a stepped
silhouette against the floor, and its side profile is a staircase from every
angle that sees it side-on. Here it is one solid with a sloped top, a sloped
underside and a fascia down each flank -- which is also what lets it have a
nose at the bottom instead of ending in a 1.45 m cliff face.

**The truss was a lattice** built here, until it moved to
`overhead_rig.py` with the rest of the rig -- see that file for why it had to
be rebuilt from the fixture positions.

Everything else is reproduced at its existing measurements.

The video face
--------------
`StageScreen` carries **normalised** UVs (0..1 across the wall), not world
metres, because `StageVideo` puts a moving picture on it and
`arena_builder.gd` resets `uv1_scale` to 1 for exactly that reason. Every
other part is projected at world-metre texel density like the rest of the
venue.

Dimensions are READ OUT OF `game/core/arena/arena_builder.gd`, never retyped.
The derived stage values (`SCREEN_CENTER_Y`, `SCREEN_FACE_Z`,
`side_screen_inner_z()`) are recomputed here from the same plain constants the
GDScript sums, so the arithmetic is duplicated but no measurement is.
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

import bpy_exit  # noqa: E402

WANTED = [
    "FLOOR_Y", "WALL_TOP", "ROOF_Y", "TRUSS_Y", "RING_HALF_EXTENT",
    "STAGE_HALF_WIDTH", "STAGE_DECK_Y", "STAGE_BACK", "STAGE_FRONT",
    "RAMP_HALF_WIDTH", "STAGE_FLARE_LENGTH", "BARRICADE_RADIUS",
    "SCREEN_WIDTH", "SCREEN_HEIGHT", "SCREEN_SAGITTA", "SCREEN_SEGMENTS",
    "SCREEN_DEPTH", "SCREEN_BEZEL", "SCREEN_CENTER_RISE", "SCREEN_FACE_OFFSET",
    "SIDE_SCREEN_INNER_X", "SIDE_SCREEN_OUTER_X", "SIDE_SCREEN_BOTTOM",
    "SIDE_SCREEN_TOP", "SIDE_SCREEN_FACE_OFFSET", "SIDE_SCREEN_TOE_DEG",
    "SIDE_SCREEN_DEPTH",
]

# Placeholder colours only; arena_builder.gd overrides every part by name.
PART_COLORS = {
    "EntranceStage": (0.10, 0.10, 0.12, 1.0),
    "StageBackdrop": (0.11, 0.11, 0.13, 1.0),
    "StageScreenBezel": (0.05, 0.05, 0.06, 1.0),
    "StageScreen": (0.10, 0.08, 0.16, 1.0),
    "StageCentreScreen": (0.30, 0.10, 0.45, 1.0),
    "StageScreenWings": (0.60, 0.20, 0.55, 1.0),
    "StageSideScreens": (0.10, 0.08, 0.16, 1.0),
    "StageSideScreenFrame": (0.03, 0.03, 0.035, 1.0),
    "StageFloorCans": (1.00, 0.16, 0.12, 1.0),
    "StageDrape": (0.02, 0.02, 0.025, 1.0),
    "StageTruss": (0.45, 0.46, 0.50, 1.0),
}
EMISSIVE = frozenset({"StageScreen", "StageCentreScreen", "StageScreenWings",
                      "StageSideScreens", "StageFloorCans"})
SMOOTH = frozenset({"StageFloorCans"})
# The screen faces author their own normalised UVs; everything else takes the
# world-metre projection the MaterialLibrary's surfaces are authored for.
PROJECTED = frozenset(PART_COLORS) - {"StageScreen", "StageCentreScreen",
                                      "StageScreenWings", "StageSideScreens"}

## The backdrop's run past each end of the video wall (backdrop_half).
BACKDROP_PAST_SCREEN = 3.8

## Black drape outboard of the LED walls: pleated cloth from the floor to the
## top of the wall, the folds running vertically as a stage curtain's do. In
## the 2026 set everything either side of the walls is black.
DRAPE_X = (7.6, 13.0)
DRAPE_PLEAT = 0.42       # one fold, in metres across
DRAPE_DEPTH = 0.16       # how far a fold stands off the wall
DRAPE_STEPS = 6          # facets per fold

## The rig frame behind and above the video wall: a box truss across the top
## and one at each end standing on the deck, as in the reference stills where
## the wall hangs inside a frame of truss with the lamps strung along it.
TRUSS_SIZE = 0.55
TRUSS_BAY = 1.4
TRUSS_HALF_SPAN = 11.4
TRUSS_ABOVE_SCREEN = 1.1     # truss centre above the screen's top edge
TRUSS_BEHIND_SCREEN = 0.9    # centre line behind the picture's CENTRE face
## The video wall's end panels (the owner's stills): an LED wing at each end of
## the screen carrying the set's pink / orange / blue diagonal stripes, the
## chevron frame the picture sits in.
WING_WIDTH = 1.5
WING_GAP = 0.08
WING_TEX = venue.REPO / "game/assets/environment/materials/stage_screen_wing.png"
## The centre screen, between the LED walls' inner edges (SIDE_SCREEN_INNER_X
## 2.55): the panel the wrestlers walk out in front of.
CENTRE_SCREEN_HALF_W = 2.3
## Its height is the LED walls' (SIDE_SCREEN_BOTTOM .. SIDE_SCREEN_TOP): the
## owner, 20 Oct -- the three screens the same height, the walls kept 16:9.
## It stood 0.4 .. 5.2 above the deck, a tall panel between two short ones.
CENTRE_SCREEN_TEX = venue.REPO / "game/assets/environment/materials/stage_centre_screen.png"


def derived(cfg: dict[str, float]) -> dict[str, float]:
    """The values `arena_builder.gd` declares as sums of the above."""
    return {
        "SCREEN_CENTER_Y": cfg["STAGE_DECK_Y"] + cfg["SCREEN_CENTER_RISE"],
        "SCREEN_FACE_Z": cfg["STAGE_BACK"] + cfg["SCREEN_FACE_OFFSET"],
        "SIDE_SCREEN_INNER_Z": cfg["STAGE_BACK"] + cfg["SIDE_SCREEN_FACE_OFFSET"],
    }


def build_deck_and_ramp(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The deck and the ramp as one sloped solid.

    The deck's front lip is chamfered: it is a lacquered gloss carrying an SSR
    reflection of the video wall, and a reflection running off a perfectly
    sharp edge is the one place that trick shows its seams.

    **Where the ramp stops.** At the BARRICADE line, not at the ring. Ringside
    is floored in black matting from the barrier in to the apron, and the
    entrance comes down to the edge of that and no further -- a ramp running
    all the way to the apron is a ramp nobody could walk around. It used to
    end 1m short of the ring, which also put it straight through the barrier.

    **No edge LEDs.** The magenta strips the old set ran down the ramp's
    flanks and round the deck's front are gone with it (the owner, 18 October
    2026): the 2026 set's ramp is plain black.
    """
    stage = parts["EntranceStage"]
    build_flared_deck(cfg, stage)

    foot_z = -cfg["BARRICADE_RADIUS"]
    foot_y = cfg["FLOOR_Y"] + 0.04
    stage.wedge(
        near=Vector((0.0, 0.0, cfg["STAGE_FRONT"])),
        far=Vector((0.0, 0.0, foot_z)),
        half_width=cfg["RAMP_HALF_WIDTH"],
        near_y=cfg["STAGE_DECK_Y"],
        far_y=foot_y,
        thickness=0.22,
        bevel=0.03,
    )
    # A nose, so the walk meets the matting instead of stopping on a lip.
    stage.wedge(
        near=Vector((0.0, 0.0, foot_z)),
        far=Vector((0.0, 0.0, foot_z + 0.5)),
        half_width=cfg["RAMP_HALF_WIDTH"],
        near_y=foot_y,
        far_y=cfg["FLOOR_Y"] + 0.004,
        thickness=0.16,
    )



def flare_half_width(cfg: dict[str, float], z: float) -> float:
    """Half the deck's width at depth `z`.

    The deck is STAGE_HALF_WIDTH wide from the back wall to the start of the
    flare, then closes to the ramp's own width at STAGE_FRONT along a
    smoothstep: tangent to the deck's side where it starts and to the ramp's
    edge where it ends, so the ramp OPENS OUT into the stage instead of
    butting into a square-ended slab. (The reference's deck does the same.)
    """
    length = cfg["STAGE_FLARE_LENGTH"]
    t = (z - (cfg["STAGE_FRONT"] - length)) / length
    t = max(0.0, min(1.0, t))
    ease = t * t * (3.0 - 2.0 * t)
    return cfg["RAMP_HALF_WIDTH"] + (cfg["STAGE_HALF_WIDTH"] - cfg["RAMP_HALF_WIDTH"]) * (1.0 - ease)


FLARE_ROWS = 10


def build_flared_deck(cfg: dict[str, float], stage: Part) -> None:
    """The deck as one closed solid whose front closes to the ramp's width.

    Rows run back to front; each row is a left and a right point at
    `flare_half_width`. The top is a strip of quads between rows, the sides
    skirt down to the floor, and the two ends are flat.

    The deck's top edge is 5 cm chamfered, as the box it replaces was: this
    is the lacquered gloss that carries the wall's SSR reflection, and a
    reflection running off a sharp edge shows its seams.
    """
    floor, deck = cfg["FLOOR_Y"], cfg["STAGE_DECK_Y"]
    length = cfg["STAGE_FLARE_LENGTH"]
    z_back, z_front = cfg["STAGE_BACK"], cfg["STAGE_FRONT"]
    z_flare = z_front - length
    zs = [z_back, z_flare] + [z_flare + length * i / FLARE_ROWS
                              for i in range(1, FLARE_ROWS + 1)]
    chamfer = 0.05
    rows = []
    for z in zs:
        w = flare_half_width(cfg, z)
        rows.append((z, w))

    def v(x: float, y: float, z: float):
        return stage.vert(Vector((x, y, z)))

    # Plateau edge, chamfer foot, floor: three vertex rows per station.
    inner = [(v(-w + chamfer, deck, z), v(w - chamfer, deck, z)) for z, w in rows]
    low = [(v(-w, deck - chamfer, z), v(w, deck - chamfer, z)) for z, w in rows]
    foot = [(v(-w, floor, z), v(w, floor, z)) for z, w in rows]
    for i in range(len(rows) - 1):
        stage.quad(inner[i][0], inner[i][1], inner[i + 1][1], inner[i + 1][0])
        for side in (0, 1):
            stage.quad(low[i][side], inner[i][side], inner[i + 1][side], low[i + 1][side])
            stage.quad(foot[i][side], low[i][side], low[i + 1][side], foot[i + 1][side])
        stage.quad(foot[i][0], foot[i][1], foot[i + 1][1], foot[i + 1][0])
    for k in (0, len(rows) - 1):
        stage.quad(foot[k][0], low[k][0], low[k][1], foot[k][1])
        stage.quad(low[k][0], inner[k][0], inner[k][1], low[k][1])



def build_backdrop(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The wall the set stands against, and what is hung on it.

    Without the wall the gap between the LED walls is a hole onto the
    Environment's background colour, which `measure_frame.py` scores as void.

    The wall used to be all there was: one flat dark box, which from the ring
    reads as a painted flat. The reference's back of stage is a built thing,
    so the wall is now dressed with more pieces (each its own part, because
    each takes its own material):

    * `StageDrape` -- pleated black cloth from the LED walls out to the ends
      of the wall;
    * `StageTruss` -- the box-truss frame the video wall hangs in, behind and
      above it (`build_truss_frame`).
    """
    wall_front = cfg["STAGE_BACK"] - 0.2
    parts["StageBackdrop"].box(
        Vector((0.0, (cfg["FLOOR_Y"] + cfg["WALL_TOP"]) * 0.5,
                cfg["STAGE_BACK"] - 0.4)),
        Vector((backdrop_half(cfg) * 2.0,
                cfg["WALL_TOP"] - cfg["FLOOR_Y"], 0.4)),
    )
    build_drape(cfg, parts, wall_front)


def build_drape(cfg: dict[str, float], parts: dict[str, Part],
                wall_front: float) -> None:
    """Pleated black cloth, floor to wall top, outboard of the LED walls.

    Each fold is a raised cosine across DRAPE_PLEAT, so the sheet has real
    depth and the house lights find a different angle on every facet -- a
    flat black rectangle is what the wall already was. The sheet is open and
    faces the ring.
    """
    drape = parts["StageDrape"]
    y0, y1 = cfg["FLOOR_Y"], cfg["WALL_TOP"] - 0.05
    for sx in (-1.0, 1.0):
        x_lo, x_hi = DRAPE_X
        folds = int(round((x_hi - x_lo) / DRAPE_PLEAT))
        steps = folds * DRAPE_STEPS
        cols = []
        for i in range(steps + 1):
            u = i / steps
            x = x_lo + (x_hi - x_lo) * u
            phase = u * folds * 2.0 * math.pi
            z = wall_front + 0.01 + DRAPE_DEPTH * 0.5 * (1.0 - math.cos(phase))
            cols.append((sx * x, z))
        for i in range(steps):
            (xa, za), (xb, zb) = cols[i], cols[i + 1]
            a = [drape.vert(Vector(p)) for p in ((xa, y0, za), (xb, y0, zb),
                                                 (xb, y1, zb), (xa, y1, za))]
            drape.quad(*a)


def build_truss_frame(cfg: dict[str, float], d: dict[str, float],
                      parts: dict[str, Part]) -> None:
    """The rig frame the video wall hangs in.

    A box truss across the top, above the wall's bezel, and one standing on
    the deck at each end. Behind the picture's centre line so it never
    touches the wall's own sag, and wider than the wings so its ends are seen
    past them. Four-sided chords keep it to a few thousand triangles.
    """
    truss = parts["StageTruss"]
    top_y = d["SCREEN_CENTER_Y"] + cfg["SCREEN_HEIGHT"] * 0.5 \
        + cfg["SCREEN_BEZEL"] + TRUSS_ABOVE_SCREEN
    z = d["SCREEN_FACE_Z"] - TRUSS_BEHIND_SCREEN
    half = TRUSS_HALF_SPAN
    truss.lattice(Vector((-half, top_y, z)), Vector((half, top_y, z)),
                  TRUSS_SIZE, TRUSS_BAY, 0.045, 0.025, sides=4)
    for sx in (-1.0, 1.0):
        truss.lattice(Vector((sx * half, cfg["STAGE_DECK_Y"], z)),
                      Vector((sx * half, top_y - TRUSS_SIZE * 0.5, z)),
                      TRUSS_SIZE, TRUSS_BAY, 0.045, 0.025, sides=4)


def backdrop_half(cfg: dict[str, float]) -> float:
    """Half the backdrop's width. The owner's AEW stills have the set's black
    wall running wider than the video wall above it, its LED columns spread
    across the whole of it; ours stopped 1.2 m past the deck and left the end
    stand's seats showing either side of the set. Now it runs
    BACKDROP_PAST_SCREEN beyond each end of the screen."""
    return cfg["SCREEN_WIDTH"] * 0.5 + cfg["SCREEN_BEZEL"] + BACKDROP_PAST_SCREEN


def arc_radius(half_chord: float, sagitta: float) -> float:
    """Radius of the circle through a chord of half-width `half_chord` bowed
    by `sagitta` at its midpoint: R = (c^2 + s^2) / 2s.

    The video wall is specified by the two numbers anyone can read off a
    photograph -- how wide it is, and how far its centre sits behind its ends
    -- rather than by a radius, which is a number nobody can measure from a
    seat.
    """
    return (half_chord * half_chord + sagitta * sagitta) / max(2.0 * sagitta, 1e-4)


def sagitta_for(radius: float, half_chord: float) -> float:
    """The sagitta a chord of half-width `half_chord` has on `radius` -- the
    inverse of `arc_radius`.

    This is what makes the bezel CONCENTRIC with the picture it frames.
    Building both from the same sagitta looks right and is not: a wider chord
    bowed by the same amount is a *different circle*, the two arcs cross
    somewhere in the middle of the panel, and the frame surfaces through the
    picture. That showed up as two dark chevrons across the top of the wall
    the first time it was rendered. Same circle, different chord, and the
    frame stays behind the picture everywhere.
    """
    return radius - math.sqrt(max(radius * radius - half_chord * half_chord, 0.0))


def build_screen(cfg: dict[str, float], d: dict[str, float],
                 parts: dict[str, Part]) -> None:
    """The gently wrapped LED wall: the picture face and its bezel.

    24 facets is 0.75 m each; a facet's chord deviates from the true arc by
    (0.375^2) / (2 * 26.11) = 2.7 mm, under a pixel at the distance the
    `stage_wide` shot sees the wall from.

    Points on the arc, exactly as `_add_curved_face` derived them:

        phi_i = -phi_max + 2 * phi_max * i / segments,  phi_max = asin(c / R)
        p_i   = center + (R sin phi_i, +-height/2, R - R cos phi_i)
    """
    segments = int(cfg["SCREEN_SEGMENTS"])
    half_w = cfg["SCREEN_WIDTH"] * 0.5
    half_h = cfg["SCREEN_HEIGHT"] * 0.5
    radius = arc_radius(half_w, cfg["SCREEN_SAGITTA"])
    top = d["SCREEN_CENTER_Y"] + half_h
    bottom = d["SCREEN_CENTER_Y"] - half_h

    def rail(half_chord: float, base_z: float, count: int) -> list[Vector]:
        """`count` + 1 points along the shared circle, spanning the chord."""
        phi_max = math.asin(max(-1.0, min(1.0, half_chord / radius)))
        points = []
        for i in range(count + 1):
            phi = -phi_max + 2.0 * phi_max * i / count
            points.append(Vector((radius * math.sin(phi), 0.0,
                                  base_z + radius - radius * math.cos(phi))))
        return points

    # The picture face, with normalised UVs for StageVideo's clip.
    screen = parts["StageScreen"]
    face = rail(half_w, d["SCREEN_FACE_Z"], segments)
    for i in range(segments):
        u0, u1 = i / segments, (i + 1) / segments
        # Wound counter-clockwise as seen from the ring (+Z), which is what
        # glTF and Godot call front-facing. Authoring it the other way round
        # and reversing the faces afterwards does NOT give the same result:
        # the reversal re-pairs each loop with its UV and the picture came
        # back on the wall rotated 180 degrees.
        screen.quad_at(
            Vector((face[i].x, top, face[i].z)),
            Vector((face[i].x, bottom, face[i].z)),
            Vector((face[i + 1].x, bottom, face[i + 1].z)),
            Vector((face[i + 1].x, top, face[i + 1].z)),
            # v runs bottom-up against the wall's geometry; u does not.
            # Read off rendered frames rather than reasoned from a winding
            # rule: the straightforward mapping put the picture on the wall
            # rotated 180 degrees, and inverting both axes then mirrored the
            # text. Only the picture on the wall settles this.
            uvs=[(u0, 1.0), (u0, 0.0), (u1, 0.0), (u1, 1.0)],
        )

    # The bezel: a frame on the SAME circle, a wider chord, standing 6 cm
    # behind the picture and returning SCREEN_DEPTH back into the wall.
    bezel = parts["StageScreenBezel"]
    bezel_z = d["SCREEN_FACE_Z"] - 0.06
    outer_half = half_w + cfg["SCREEN_BEZEL"]
    outer_top = top + cfg["SCREEN_BEZEL"]
    outer_bottom = bottom - cfg["SCREEN_BEZEL"]
    inner = rail(half_w, bezel_z, segments)
    outer = rail(outer_half, bezel_z, segments)

    def strip(a: list[Vector], y_a: float, b: list[Vector], y_b: float) -> None:
        for i in range(segments):
            bezel.quad_at(
                Vector((a[i].x, y_a, a[i].z)),
                Vector((a[i + 1].x, y_a, a[i + 1].z)),
                Vector((b[i + 1].x, y_b, b[i + 1].z)),
                Vector((b[i].x, y_b, b[i].z)),
            )

    # Front frame: above, below and either side of the picture.
    strip(outer, outer_top, inner, top)
    strip(inner, bottom, outer, outer_bottom)
    # The return into the wall, so the panel is a built object not a decal.
    back = [p + Vector((0.0, 0.0, -cfg["SCREEN_DEPTH"])) for p in outer]
    strip(outer, outer_top, back, outer_top)
    strip(back, outer_bottom, outer, outer_bottom)
    for i in range(segments):
        bezel.quad_at(
            Vector((back[i].x, outer_top, back[i].z)),
            Vector((back[i + 1].x, outer_top, back[i + 1].z)),
            Vector((back[i + 1].x, outer_bottom, back[i + 1].z)),
            Vector((back[i].x, outer_bottom, back[i].z)),
        )
    # The two ends, closing the frame onto the wall.
    for edge in (0, segments):
        bezel.quad_at(
            Vector((outer[edge].x, outer_top, outer[edge].z)),
            Vector((back[edge].x, outer_top, back[edge].z)),
            Vector((back[edge].x, outer_bottom, back[edge].z)),
            Vector((outer[edge].x, outer_bottom, outer[edge].z)),
        )
        bezel.quad_at(
            Vector((outer[edge].x, outer_top, outer[edge].z)),
            Vector((outer[edge].x, outer_bottom, outer[edge].z)),
            Vector((inner[edge].x, bottom, inner[edge].z)),
            Vector((inner[edge].x, top, inner[edge].z)),
        )


def build_screen_wings(cfg: dict[str, float], d: dict[str, float],
                       parts: dict[str, Part]) -> None:
    """The chevron wings either end of the video wall (WING_*): flat LED
    panels the screen's height, turned to the arc's own tangent at its ends so
    they carry its curve on, a hand's width off the bezel."""
    wings = parts["StageScreenWings"]
    half_w = cfg["SCREEN_WIDTH"] * 0.5
    radius = arc_radius(half_w, cfg["SCREEN_SAGITTA"])
    half_h = cfg["SCREEN_HEIGHT"] * 0.5
    top = d["SCREEN_CENTER_Y"] + half_h + cfg["SCREEN_BEZEL"]
    bottom = d["SCREEN_CENTER_Y"] - half_h - cfg["SCREEN_BEZEL"]
    for sx in (-1.0, 1.0):
        # Along the circle past the bezel's end: start and end angles.
        a0 = math.asin(min(1.0, (half_w + cfg["SCREEN_BEZEL"] + WING_GAP) / radius))
        a1 = a0 + WING_WIDTH / radius
        pts = []
        for a in (a0, a1):
            pts.append(Vector((sx * radius * math.sin(a), 0.0,
                               d["SCREEN_FACE_Z"] + radius - radius * math.cos(a))))
        inner, outer = pts
        # u runs from the screen outward on both sides, so the stripes
        # mirror about the centre line.
        if sx > 0.0:
            wings.quad_at(Vector((inner.x, top, inner.z)), Vector((inner.x, bottom, inner.z)),
                          Vector((outer.x, bottom, outer.z)), Vector((outer.x, top, outer.z)),
                          uvs=[(0.0, 1.0), (0.0, 0.0), (1.0, 0.0), (1.0, 1.0)])
        else:
            wings.quad_at(Vector((outer.x, top, outer.z)), Vector((outer.x, bottom, outer.z)),
                          Vector((inner.x, bottom, inner.z)), Vector((inner.x, top, inner.z)),
                          uvs=[(1.0, 1.0), (1.0, 0.0), (0.0, 0.0), (0.0, 1.0)])
    paint_screen_wing()


def paint_screen_wing() -> None:
    """The wing's picture, u = 0 at the screen: a deep violet LED field and the
    set's chevrons -- magenta, amber and blue bands rising away from the
    screen at 50 degrees -- under the same fine pixel grid as the centre
    screen."""
    import numpy as np
    from PIL import Image
    w, h = 256, 1024
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = x / w, 1.0 - y / h
    field = np.stack([0.16 + 0.06 * v, 0.04 + 0.03 * v, 0.32 + 0.12 * v], -1)
    # Distance along the stripe normal, in wing widths (aspect-corrected).
    t = u * 1.0 + v * (h / w) * 0.25
    period = 0.62
    phase = np.mod(t, period) / period
    for lo, hi, col in ((0.00, 0.16, (1.0, 0.22, 0.62)), (0.22, 0.34, (1.0, 0.58, 0.14)),
                        (0.42, 0.50, (0.22, 0.42, 1.0))):
        band = ((phase >= lo) & (phase < hi)).astype(np.float32)
        field = field * (1 - band[..., None]) + np.array(col, np.float32) * band[..., None]
    grid = ((x % 6 < 5) & (y % 6 < 5)).astype(np.float32) * 0.25 + 0.75
    rgb = np.clip(field * grid[..., None], 0, 1) * 255
    Image.fromarray(np.round(rgb).astype(np.uint8), "RGB").save(WING_TEX, optimize=True)


def build_centre_screen(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The centre screen on the back wall, between the LED walls."""
    face_z = cfg["STAGE_BACK"] - 0.2 + 0.012
    deck = cfg["STAGE_DECK_Y"]
    scr = parts["StageCentreScreen"]
    w = CENTRE_SCREEN_HALF_W
    y0, y1 = deck + cfg["SIDE_SCREEN_BOTTOM"], deck + cfg["SIDE_SCREEN_TOP"]
    v = [scr.vert(Vector(p)) for p in ((-w, y0, face_z), (w, y0, face_z), (w, y1, face_z), (-w, y1, face_z))]
    scr.quad(*v, uvs=[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])
    paint_centre_screen()


## The LED cabinet's lip proud of the picture all round, and the picture's
## stand-off in front of the cabinet face (no z-fighting).
SIDE_SCREEN_LIP = 0.06
SIDE_SCREEN_STANDOFF = 0.012
## The red floor cans at each wall's foot: spacing along the wall, size, and
## how far in front of the picture they stand.
FLOOR_CAN_PITCH = 0.7
FLOOR_CAN_RADIUS = 0.09
FLOOR_CAN_HEIGHT = 0.16
FLOOR_CAN_OUT = 0.35


def build_side_screens(cfg: dict[str, float], d: dict[str, float],
                       parts: dict[str, Part]) -> None:
    """The 2026 set's two LED walls, either side of the centre screen.

    Each is a flat picture (normalised UVs, the whole frame left to right as
    the ring sees it -- StageVideo crops the clip to fit) on a black cabinet,
    standing on the deck with its inner edge SIDE_SCREEN_FACE_OFFSET in front
    of the back wall and turned SIDE_SCREEN_TOE_DEG about that edge (negative: the
    outer edge set back, the walls splayed away from the ring). A row of red floor cans stands along its foot.
    """
    deck = cfg["STAGE_DECK_Y"]
    y0, y1 = deck + cfg["SIDE_SCREEN_BOTTOM"], deck + cfg["SIDE_SCREEN_TOP"]
    toe = math.radians(cfg["SIDE_SCREEN_TOE_DEG"])
    span = cfg["SIDE_SCREEN_OUTER_X"] - cfg["SIDE_SCREEN_INNER_X"]
    z_in = d["SIDE_SCREEN_INNER_Z"]
    z_out = z_in + span * math.tan(toe)
    depth = cfg["SIDE_SCREEN_DEPTH"]
    lip = SIDE_SCREEN_LIP
    pic, frame, cans = parts["StageSideScreens"], parts["StageSideScreenFrame"], parts["StageFloorCans"]
    for sx in (-1.0, 1.0):
        inner = Vector((sx * cfg["SIDE_SCREEN_INNER_X"], 0.0, z_in))
        outer = Vector((sx * cfg["SIDE_SCREEN_OUTER_X"], 0.0, z_out))
        along = (outer - inner).normalized()
        # The face's normal: horizontal, perpendicular to the wall, ringward.
        normal = Vector((-along.z, 0.0, along.x))
        if normal.z < 0.0:
            normal = -normal
        # The picture, left to right as seen from the ring.
        left, right = (outer, inner) if sx < 0.0 else (inner, outer)
        off = normal * SIDE_SCREEN_STANDOFF
        v = [pic.vert(p + off) for p in (left + Vector((0, y0, 0)), right + Vector((0, y0, 0)),
                                         right + Vector((0, y1, 0)), left + Vector((0, y1, 0)))]
        pic.quad(*v, uvs=[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])
        # The cabinet: a box round and behind the picture, `lip` proud of it.
        l = left - (right - left).normalized() * lip
        r = right + (right - left).normalized() * lip
        lo, hi = y0 - lip, y1 + lip
        back = -normal * depth
        corners = {
            "lf": l + Vector((0, lo, 0)), "rf": r + Vector((0, lo, 0)),
            "rt": r + Vector((0, hi, 0)), "lt": l + Vector((0, hi, 0)),
        }
        f = {k: frame.vert(c) for k, c in corners.items()}
        b = {k: frame.vert(c + back) for k, c in corners.items()}
        frame.quad(f["lf"], f["rf"], f["rt"], f["lt"])          # face, under the picture
        frame.quad(b["rf"], b["lf"], b["lt"], b["rt"])          # back
        frame.quad(f["lt"], f["rt"], b["rt"], b["lt"])          # top
        frame.quad(b["lf"], b["rf"], f["rf"], f["lf"])          # bottom
        frame.quad(b["lf"], f["lf"], f["lt"], b["lt"])          # left end
        frame.quad(f["rf"], b["rf"], b["rt"], f["rt"])          # right end
        # Feet: the cabinet stands on the deck.
        for p in (l, r):
            frame.box(p + back * 0.5 + Vector((0.0, (deck + lo) * 0.5, 0.0)),
                      Vector((0.12, lo - deck, 0.12)))
        # The floor cans along its foot, in front of the picture.
        n = int(span / math.cos(toe) / FLOOR_CAN_PITCH)
        for k in range(n):
            t = (k + 0.5) / n
            base = left + (right - left) * t + normal * FLOOR_CAN_OUT + Vector((0.0, deck, 0.0))
            cans.tube([base, base + Vector((0.0, FLOOR_CAN_HEIGHT, 0.0))],
                      FLOOR_CAN_RADIUS, sides=12)


def paint_centre_screen() -> None:
    """The centre screen's picture: a violet LED field with the set's pink and
    orange chevrons coming in from the corners, under a fine pixel grid."""
    import numpy as np
    from PIL import Image
    w, h = 552, 576
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = x / w, y / h
    field = np.stack([0.30 + 0.15 * v, 0.06 + 0.05 * v, 0.55 + 0.2 * (1 - v)], -1)
    for corner, col in (((0.0, 0.0), (1.0, 0.25, 0.65)), ((1.0, 1.0), (1.0, 0.55, 0.15)),
                        ((1.0, 0.0), (0.25, 0.45, 1.0)), ((0.0, 1.0), (0.95, 0.2, 0.7))):
        d = np.abs((u - corner[0]) + (v - corner[1]) * (1 if corner[0] == corner[1] else -1))
        for k, width in ((0.18, 0.05), (0.30, 0.035), (0.40, 0.02)):
            band = (np.abs(d - k) < width).astype(np.float32)
            field = field * (1 - band[..., None]) + np.array(col, np.float32) * band[..., None]
    grid = ((x % 8 < 6) & (y % 8 < 6)).astype(np.float32) * 0.25 + 0.75
    rgb = np.clip(field * grid[..., None], 0, 1) * 255
    Image.fromarray(np.round(rgb).astype(np.uint8), "RGB").save(CENTRE_SCREEN_TEX, optimize=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(venue.ASSET_DIR / "entrance_set.glb"))
    args = parser.parse_args(argv)

    cfg = venue.read_constants(venue.ARENA_GD, WANTED)
    d = derived(cfg)
    venue.reset_scene()
    parts = {name: Part(name) for name in PART_COLORS}
    build_deck_and_ramp(cfg, parts)
    build_backdrop(cfg, parts)
    build_screen(cfg, d, parts)
    build_centre_screen(cfg, parts)
    build_side_screens(cfg, d, parts)
    build_screen_wings(cfg, d, parts)
    build_truss_frame(cfg, d, parts)
    # The picture faces are open sheets and must look at the ring (+Z).
    venue.finish(parts, PART_COLORS, emissive=EMISSIVE, smooth=SMOOTH,
                 projected=PROJECTED,
                 face_toward={"StageScreen": (0.0, 0.0, 1.0),
                              "StageDrape": (0.0, 0.0, 1.0),
                              "StageCentreScreen": (0.0, 0.0, 1.0)},
                 # Two sheets facing different ways: recalc would pick a side
                 # per quad and lose one (face_toward's note). Authored
                 # counter-clockwise from the ring, as the screen is.
                 # The two LED walls too: splayed opposite ways.
                 keep_winding=frozenset({"StageScreenWings", "StageSideScreens"}))

    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("entrance_set: %d triangles, %s" % (venue.triangle_count(), out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
