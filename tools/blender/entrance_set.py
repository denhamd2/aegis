#!/usr/bin/env python3
"""Build the entrance set and the overhead truss in Blender, export as glTF.

Run:  tools/blender/build_venue.sh entrance

What this builds
----------------
The stage deck and the ramp down to the floor, the backdrop the set stands
against, the two circular entrance portals (recess, slat fan, lit ring), the
curved video wall's bezel and its picture face, and the lighting truss over
the ring.

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

**The truss is a lattice.** It was eight long boxes and eight shorter ones
stacked above them, with a comment that the chords were there so the grid
"reads as truss rather than as bare pipe". Overhead truss is the one piece of
an arena that is unmistakably a lattice from every angle. `venue.Part.lattice`
builds the real thing: four chords on the corners of a square section, with
alternating diagonals bay by bay and a vertical at every node.

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

WANTED = [
    "FLOOR_Y", "WALL_TOP", "ROOF_Y", "TRUSS_Y", "RING_HALF_EXTENT",
    "STAGE_HALF_WIDTH", "STAGE_DECK_Y", "STAGE_BACK", "STAGE_FRONT",
    "RAMP_HALF_WIDTH",
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
    "Truss": (0.13, 0.13, 0.15, 1.0),
}
EMISSIVE = frozenset({"PortalRingWest", "PortalRingEast",
                      "PortalFanWest", "PortalFanEast", "StageScreen"})
SMOOTH = frozenset({"PortalRingWest", "PortalRingEast", "PortalRecess", "Truss"})
# The screen face authors its own normalised UVs; everything else takes the
# world-metre projection the MaterialLibrary's surfaces are authored for.
PROJECTED = frozenset(PART_COLORS) - {"StageScreen"}


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
    """The deck, and the ramp as one sloped solid.

    The deck's front lip is chamfered: it is a lacquered gloss carrying an SSR
    reflection of the video wall, and a reflection running off a perfectly
    sharp edge is the one place that trick shows its seams.
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

    # The ramp: stage lip to a metre short of the ring, falling to the floor.
    ramp_end = -cfg["RING_HALF_EXTENT"] - 1.0
    stage.wedge(
        near=Vector((0.0, 0.0, cfg["STAGE_FRONT"])),
        far=Vector((0.0, 0.0, ramp_end)),
        half_width=cfg["RAMP_HALF_WIDTH"],
        near_y=cfg["STAGE_DECK_Y"],
        far_y=cfg["FLOOR_Y"] + 0.04,
        thickness=0.22,
        bevel=0.03,
    )
    # A nose at the bottom, so the walk meets the floor instead of stopping on
    # a lip. Four centimetres over half a metre is a ramp's own run-out.
    stage.wedge(
        near=Vector((0.0, 0.0, ramp_end)),
        far=Vector((0.0, 0.0, ramp_end + 0.5)),
        half_width=cfg["RAMP_HALF_WIDTH"],
        near_y=cfg["FLOOR_Y"] + 0.04,
        far_y=cfg["FLOOR_Y"] + 0.004,
        thickness=0.16,
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
        Vector((cfg["STAGE_HALF_WIDTH"] * 2.4,
                cfg["WALL_TOP"] - cfg["FLOOR_Y"], 0.4)),
    )


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


def build_truss(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """A real four-chord lattice grid above the ring.

    It sits above the four SpotLight3Ds in `match.tscn` (y 5.5, range 10), so
    it neither occludes them nor changes how the mat is lit, and it hangs from
    the roof on four drops rather than floating.
    """
    truss = parts["Truss"]
    reach = 11.0
    offsets = (-7.5, -2.5, 2.5, 7.5)
    y = cfg["TRUSS_Y"]
    for offset in offsets:
        truss.lattice(Vector((-reach, y, offset)), Vector((reach, y, offset)),
                      size=0.42, bay=1.6, chord_radius=0.055,
                      diagonal_radius=0.028)
        truss.lattice(Vector((offset, y, -reach)), Vector((offset, y, reach)),
                      size=0.42, bay=1.6, chord_radius=0.055,
                      diagonal_radius=0.028)
    for x in (-7.5, 7.5):
        for z in (-7.5, 7.5):
            truss.tube([Vector((x, y + 0.2, z)), Vector((x, cfg["ROOF_Y"], z))],
                       0.07, sides=6)


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
    build_truss(cfg, parts)
    # The picture face is an open sheet and must look at the ring (+Z); the
    # portal recess is an open bore and what is seen is its inner wall.
    venue.finish(parts, PART_COLORS, emissive=EMISSIVE, smooth=SMOOTH,
                 projected=PROJECTED,
                 face_toward={"StageScreen": (0.0, 0.0, 1.0)},
                 flip=frozenset({"PortalRecess"}))

    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("entrance_set: %d triangles, %s" % (venue.triangle_count(), out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
