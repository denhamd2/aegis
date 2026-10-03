#!/usr/bin/env python3
"""Build the entrance set in Blender, export as glTF.

Run:  tools/blender/build_venue.sh entrance

What this builds
----------------
The stage deck and the ramp down to the floor, the backdrop the set stands
against, the two circular entrance portals (recess, slat fan, lit ring), the
curved video wall's bezel and its picture face. The lighting truss that
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

Everything else is reproduced at its existing measurements. The portals' depth
order -- dark recess, fan inside it, lit ring proud of both -- is what makes a
ring read as a fixture rather than a painted circle, and is unchanged.

The video face
--------------
`StageScreen` carries **normalised** UVs (0..1 across the wall), not world
metres, because `StageVideo` puts a moving picture on it and
`arena_builder.gd` resets `uv1_scale` to 1 for exactly that reason. Every
other part is projected at world-metre texel density like the rest of the
venue.

Dimensions are READ OUT OF `game/core/arena/arena_builder.gd`, never retyped.
The three derived stage values (`SCREEN_CENTER_Y`, `SCREEN_FACE_Z`,
`PORTAL_FACE_Z`) are recomputed here from the same plain constants the
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
    "RAMP_HALF_WIDTH", "BARRICADE_RADIUS",
    "SCREEN_WIDTH", "SCREEN_HEIGHT", "SCREEN_SAGITTA", "SCREEN_SEGMENTS",
    "SCREEN_DEPTH", "SCREEN_BEZEL", "SCREEN_CENTER_RISE", "SCREEN_FACE_OFFSET",
    "PORTAL_MAJOR", "PORTAL_MINOR", "PORTAL_OFFSET_X", "PORTAL_CUT_DEPTH",
    "PORTAL_RING_SEGMENTS", "PORTAL_TUBE_SIDES", "PORTAL_SLATS",
    "PORTAL_RECESS_DEPTH", "PORTAL_FACE_OFFSET",
]

# Placeholder colours only; arena_builder.gd overrides every part by name.
PART_COLORS = {
    "EntranceStage": (0.10, 0.10, 0.12, 1.0),
    "StageBackdrop": (0.11, 0.11, 0.13, 1.0),
    "PortalRecess": (0.03, 0.03, 0.04, 1.0),
    "PortalRingWest": (0.62, 0.08, 0.42, 1.0),
    "PortalRingEast": (0.72, 0.44, 0.06, 1.0),
    "PortalFanWest": (0.40, 0.06, 0.28, 1.0),
    "PortalFanEast": (0.48, 0.30, 0.05, 1.0),
    "StageScreenBezel": (0.05, 0.05, 0.06, 1.0),
    "StageScreen": (0.10, 0.08, 0.16, 1.0),
    "RampLeds": (0.72, 0.10, 0.55, 1.0),
    "StageLedDots": (0.20, 0.85, 0.90, 1.0),
    "StageCentreScreen": (0.30, 0.10, 0.45, 1.0),
    "StageScreenWings": (0.60, 0.20, 0.55, 1.0),
}
EMISSIVE = frozenset({"PortalRingWest", "PortalRingEast",
                      "PortalFanWest", "PortalFanEast", "StageScreen",
                      "RampLeds", "StageLedDots", "StageCentreScreen",
                      "StageScreenWings"})
SMOOTH = frozenset({"PortalRingWest", "PortalRingEast", "PortalRecess",
                    "RampLeds"})
# The screen face authors its own normalised UVs; everything else takes the
# world-metre projection the MaterialLibrary's surfaces are authored for.
PROJECTED = frozenset(PART_COLORS) - {"StageScreen", "StageCentreScreen", "StageScreenWings"}

## The owner's AEW arena still (the Dynamite set in WWE 2K), which our set
## lacked two things of:
## * COLUMNS OF LED DOTS on the dark backdrop either side of the portals --
##   teal pixels in vertical runs, the set's own lighting texture;
## * a CENTRE SCREEN between the two portals, an LED panel of its own under
##   the video wall.
## Three near the portals as before, then pairs out across the widened wall.
LED_COLUMNS_X = (5.95, 6.45, 6.95, 8.15, 8.65, 9.85, 10.35)
## The backdrop's run past each end of the video wall (backdrop_half).
BACKDROP_PAST_SCREEN = 1.9
## The video wall's end panels (the owner's stills): an LED wing at each end of
## the screen carrying the set's pink / orange / blue diagonal stripes, the
## chevron frame the picture sits in.
WING_WIDTH = 1.5
WING_GAP = 0.08
WING_TEX = venue.REPO / "game/assets/environment/materials/stage_screen_wing.png"
LED_DOT_PITCH = 0.24
LED_DOT_SIZE = 0.10
LED_DOT_BOTTOM = 0.45     # above the deck
LED_DOT_TOP = 7.6
CENTRE_SCREEN_HALF_W = 1.35
CENTRE_SCREEN_Y = (0.9, 4.3)   # above the deck
CENTRE_SCREEN_TEX = venue.REPO / "game/assets/environment/materials/stage_centre_screen.png"


def derived(cfg: dict[str, float]) -> dict[str, float]:
    """The three values `arena_builder.gd` declares as sums of the above."""
    return {
        "SCREEN_CENTER_Y": cfg["STAGE_DECK_Y"] + cfg["SCREEN_CENTER_RISE"],
        "SCREEN_FACE_Z": cfg["STAGE_BACK"] + cfg["SCREEN_FACE_OFFSET"],
        "PORTAL_FACE_Z": cfg["STAGE_BACK"] + cfg["PORTAL_FACE_OFFSET"],
        "PORTAL_CENTER_Y": cfg["STAGE_DECK_Y"] + cfg["PORTAL_MAJOR"]
        - cfg["PORTAL_CUT_DEPTH"],
    }


def portal_cut_angle(cfg: dict[str, float], d: dict[str, float]) -> float:
    """Where the portal circle crosses the deck on its right-hand side.

    Derived rather than typed, exactly as `ArenaBuilder._portal_cut_angle()`
    derives it, so moving PORTAL_CUT_DEPTH cannot leave the tube's ends
    floating above the deck or buried under it.
    """
    ratio = (cfg["STAGE_DECK_Y"] - d["PORTAL_CENTER_Y"]) / cfg["PORTAL_MAJOR"]
    return math.asin(max(-1.0, min(1.0, ratio)))


def build_deck_and_ramp(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The deck, the ramp as one sloped solid, and the ramp's edge LEDs.

    The deck's front lip is chamfered: it is a lacquered gloss carrying an SSR
    reflection of the video wall, and a reflection running off a perfectly
    sharp edge is the one place that trick shows its seams.

    **Where the ramp stops.** At the BARRICADE line, not at the ring. Ringside
    is floored in black matting from the barrier in to the apron, and the
    entrance comes down to the edge of that and no further -- a ramp running
    all the way to the apron is a ramp nobody could walk around. It used to
    end 1m short of the ring, which also put it straight through the barrier.

    **The edge LEDs.** Measured off `gauntlet/refs/stage/`'s own photographs
    rather than remembered: sampling the lit strip along the deck's leading
    edge in `dynamite_stage_low_angle.jpg`, 67 of 136 sampled columns are
    violet-magenta at hue 287-295 degrees, against 9 blue and 5 cyan, with the
    remaining 51 blown to near-white at the strip's core. So the strips are
    the same magenta the portals carry, and `arena_builder.gd` dresses them
    from the same `arena_portal_magenta` key.
    """
    stage = parts["EntranceStage"]
    deck_depth = cfg["STAGE_FRONT"] - cfg["STAGE_BACK"]
    stage.box(
        Vector((0.0, (cfg["FLOOR_Y"] + cfg["STAGE_DECK_Y"]) * 0.5,
                (cfg["STAGE_FRONT"] + cfg["STAGE_BACK"]) * 0.5)),
        Vector((cfg["STAGE_HALF_WIDTH"] * 2.0,
                cfg["STAGE_DECK_Y"] - cfg["FLOOR_Y"], deck_depth)),
        bevel=0.05,
    )

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

    # The strips themselves: thin, just proud of the ramp's flank, running the
    # whole fall from the stage lip to the foot. Eight-sided tubes at 4cm --
    # a strip light is a lens, not an edge, and it has to hold its highlight
    # where the ramp turns away from the camera.
    leds = parts["RampLeds"]
    for sx in (-1.0, 1.0):
        x = sx * (cfg["RAMP_HALF_WIDTH"] + 0.045)
        leds.tube(
            [Vector((x, cfg["STAGE_DECK_Y"] - 0.09, cfg["STAGE_FRONT"])),
             Vector((x, foot_y - 0.09, foot_z))],
            0.040, sides=8,
        )


def build_backdrop(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The wall the set stands against.

    Without it the portals are holes onto the Environment's background colour,
    which `measure_frame.py` scores as void -- a quarter of the frame's middle
    band on the first capture. A portal has to be a recess in something.
    """
    parts["StageBackdrop"].box(
        Vector((0.0, (cfg["FLOOR_Y"] + cfg["WALL_TOP"]) * 0.5,
                cfg["STAGE_BACK"] - 0.4)),
        Vector((backdrop_half(cfg) * 2.0,
                cfg["WALL_TOP"] - cfg["FLOOR_Y"], 0.4)),
    )


def backdrop_half(cfg: dict[str, float]) -> float:
    """Half the backdrop's width. The owner's AEW stills have the set's black
    wall running wider than the video wall above it, its LED columns spread
    across the whole of it; ours stopped 1.2 m past the deck and left the end
    stand's seats showing either side of the portals. Now it runs
    BACKDROP_PAST_SCREEN beyond each end of the screen."""
    return cfg["SCREEN_WIDTH"] * 0.5 + cfg["SCREEN_BEZEL"] + BACKDROP_PAST_SCREEN


def build_portals(cfg: dict[str, float], d: dict[str, float],
                  parts: dict[str, Part]) -> None:
    """Recess, slat fan and lit ring, in that depth order.

    Flattening any of the three onto the same plane collapses the effect: the
    recess is the darkest thing on the stage, the fan sits inside it lit only
    by the ring, and the ring is in front of both and is the only part that
    emits.
    """
    segments = int(cfg["PORTAL_RING_SEGMENTS"])
    sides = int(cfg["PORTAL_TUBE_SIDES"])
    cut = portal_cut_angle(cfg, d)

    for sx, name in ((-1.0, "West"), (1.0, "East")):
        center = Vector((sx * cfg["PORTAL_OFFSET_X"], d["PORTAL_CENTER_Y"],
                         d["PORTAL_FACE_Z"]))

        # The recess: a cylinder bored back into the backdrop.
        radius = cfg["PORTAL_MAJOR"] - cfg["PORTAL_MINOR"] * 0.5
        rim = venue.arc(center, radius, 0.0, 2.0 * math.pi, segments, axis="z")
        back = [p - Vector((0.0, 0.0, cfg["PORTAL_RECESS_DEPTH"])) for p in rim]
        recess = parts["PortalRecess"]
        for i in range(segments):
            recess.quad_at(rim[i], rim[i + 1], back[i + 1], back[i])
        cap_center = center - Vector((0.0, 0.0, cfg["PORTAL_RECESS_DEPTH"]))
        for i in range(segments):
            recess.tri(recess.vert(cap_center), recess.vert(back[i]),
                       recess.vert(back[i + 1]))

        # The ring: a circle with the bottom cut off by the deck. The sweep
        # runs from where the circle meets the deck on the right, the long way
        # over the top, to where it meets it on the left -- 308 degrees. There
        # are no legs and no feet; the tube simply stops at the deck, which is
        # what a circle sunk a quarter of a metre into a stage does.
        path = venue.arc(center, cfg["PORTAL_MAJOR"], cut, math.pi - cut,
                         segments, axis="z")
        parts["PortalRing%s" % name].tube(path, cfg["PORTAL_MINOR"], sides)

        # The slat fan: strip fixtures in the reference photographs, not dark
        # slats catching the ring's spill. One wedge per portal, on its
        # OUTBOARD side and clear of the gap the entrance walks through -- a
        # full lower half would fill the doorway with slats.
        fan_center = center - Vector((0.0, 0.0, 0.12))
        wedge_from = (math.pi - 0.30) if sx < 0.0 else cut + 0.30
        wedge_to = wedge_from + (-cut - 0.30) + 0.30
        fan = parts["PortalFan%s" % name]
        slats = int(cfg["PORTAL_SLATS"])
        for i in range(slats):
            theta = wedge_from + (wedge_to - wedge_from) * i / max(slats - 1, 1)
            direction = Vector((math.cos(theta), math.sin(theta), 0.0))
            # 13 slats across 52 degrees are 0.15 m apart at the outer radius,
            # so a half-width over about 0.06 closes the gaps and the fan
            # renders as one solid triangle. It did, at 0.09.
            fan.tube([fan_center + direction * 0.55,
                      fan_center + direction * 2.2], 0.030, sides=4)


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


def build_stage_leds(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The backdrop's LED dot columns and the centre screen (see LED_*)."""
    face_z = cfg["STAGE_BACK"] - 0.2 + 0.012
    deck = cfg["STAGE_DECK_Y"]
    dots = parts["StageLedDots"]
    h = LED_DOT_SIZE * 0.5
    for sx in (-1.0, 1.0):
        for x in LED_COLUMNS_X:
            n = int((LED_DOT_TOP - LED_DOT_BOTTOM) / LED_DOT_PITCH)
            for k in range(n + 1):
                y = deck + LED_DOT_BOTTOM + k * LED_DOT_PITCH
                c = Vector((sx * x, y, face_z))
                v = [dots.vert(c + Vector(o)) for o in ((-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0))]
                dots.quad(*v)
    scr = parts["StageCentreScreen"]
    w = CENTRE_SCREEN_HALF_W
    y0, y1 = deck + CENTRE_SCREEN_Y[0], deck + CENTRE_SCREEN_Y[1]
    v = [scr.vert(Vector(p)) for p in ((-w, y0, face_z), (w, y0, face_z), (w, y1, face_z), (-w, y1, face_z))]
    scr.quad(*v, uvs=[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])
    paint_centre_screen()


def paint_centre_screen() -> None:
    """The centre screen's picture: a violet LED field with the set's pink and
    orange chevrons coming in from the corners, under a fine pixel grid."""
    import numpy as np
    from PIL import Image
    w, h = 512, 640
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
    build_portals(cfg, d, parts)
    build_screen(cfg, d, parts)
    build_stage_leds(cfg, parts)
    build_screen_wings(cfg, d, parts)
    # The picture face is an open sheet and must look at the ring (+Z); the
    # portal recess is an open bore and what is seen is its inner wall.
    venue.finish(parts, PART_COLORS, emissive=EMISSIVE, smooth=SMOOTH,
                 projected=PROJECTED,
                 face_toward={"StageScreen": (0.0, 0.0, 1.0),
                              "StageLedDots": (0.0, 0.0, 1.0),
                              "StageCentreScreen": (0.0, 0.0, 1.0)},
                 # Two sheets facing different ways: recalc would pick a side
                 # per quad and lose one (face_toward's note). Authored
                 # counter-clockwise from the ring, as the screen is.
                 keep_winding=frozenset({"StageScreenWings"}),
                 flip=frozenset({"PortalRecess"}))

    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("entrance_set: %d triangles, %s" % (venue.triangle_count(), out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
