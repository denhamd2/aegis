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
    "RAMP_HALF_WIDTH", "STAGE_FLARE_LENGTH", "BARRICADE_RADIUS",
    "SCREEN_WIDTH", "SCREEN_HEIGHT", "SCREEN_SAGITTA", "SCREEN_SEGMENTS",
    "SCREEN_DEPTH", "SCREEN_BEZEL", "SCREEN_CENTER_RISE", "SCREEN_FACE_OFFSET",
    "PORTAL_MAJOR", "PORTAL_MINOR", "PORTAL_OFFSET_X", "PORTAL_CUT_DEPTH",
    "PORTAL_RING_SEGMENTS", "PORTAL_TUBE_SIDES",
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
    "PortalBack": (0.30, 0.12, 0.55, 1.0),
    "PortalPods": (0.20, 0.45, 1.00, 1.0),
    "StageScreenBezel": (0.05, 0.05, 0.06, 1.0),
    "StageScreen": (0.10, 0.08, 0.16, 1.0),
    "RampLeds": (0.72, 0.10, 0.55, 1.0),
    "StageLedDots": (0.20, 0.85, 0.90, 1.0),
    "StageCentreScreen": (0.30, 0.10, 0.45, 1.0),
    "StageScreenWings": (0.60, 0.20, 0.55, 1.0),
    "StageSidePanels": (0.30, 0.12, 0.55, 1.0),
    "StageDrape": (0.02, 0.02, 0.025, 1.0),
    "StageTruss": (0.45, 0.46, 0.50, 1.0),
}
EMISSIVE = frozenset({"PortalRingWest", "PortalRingEast",
                      "PortalFanWest", "PortalFanEast", "PortalBack", "PortalPods",
                      "StageScreen",
                      "RampLeds", "StageLedDots", "StageCentreScreen",
                      "StageScreenWings", "StageSidePanels"})
SMOOTH = frozenset({"PortalRingWest", "PortalRingEast", "PortalRecess",
                    "RampLeds"})
# The screen face authors its own normalised UVs; everything else takes the
# world-metre projection the MaterialLibrary's surfaces are authored for.
PROJECTED = frozenset(PART_COLORS) - {"StageScreen", "StageCentreScreen",
                                      "StageScreenWings", "StageSidePanels",
                                      "PortalRingWest", "PortalRingEast",
                                      "PortalBack"}

## The owner's AEW arena still (the Dynamite set in WWE 2K), which our set
## lacked two things of:
## * COLUMNS OF LED DOTS on the dark backdrop either side of the portals --
##   teal pixels in vertical runs, the set's own lighting texture;
## * a CENTRE SCREEN between the two portals, an LED panel of its own under
##   the video wall.
## Three near the portals as before, then pairs out across the widened wall.
## With the portals respaced out to |x| 7.67 the columns moved out with them:
## they now stand on the lit side panels (SIDE_PANEL_*), clear of the rings.
LED_COLUMNS_X = (8.45, 9.25, 10.05)
## The backdrop's run past each end of the video wall (backdrop_half).
BACKDROP_PAST_SCREEN = 3.8

## The lit, perforated side panels flanking the portals (the reference's
## backdrop is not one black wall: a tall perforated panel stands either side
## of the rings, uplit and faintly lit from within). Out of the portals' reach
## and under the video wall's lower edge, so the wall keeps the top of the
## frame to itself.
SIDE_PANEL_X = (7.95, 10.85)
SIDE_PANEL_Y = (0.15, 5.9)       # above the deck
SIDE_PANEL_TEX = venue.REPO / "game/assets/environment/materials/stage_side_panel.png"
## The lattice closing each tunnel (dynamite_portals_close.jpg, dynamite_stage_
## head_on.webp): a pale lavender sheet lit from behind, round perforations in
## a staggered grid -- the bright thing seen through each ring, not the dark
## dotted panel beside it.
TUNNEL_LATTICE_TEX = venue.REPO / "game/assets/environment/materials/tunnel_lattice.png"
## Proud of the wall plane by this much, so the panel and the dot columns on
## it never z-fight with the backdrop face.
SIDE_PANEL_LIFT = 0.06

## Black drape either side of the panels: pleated cloth from the floor to the
## top of the wall, the folds running vertically as a stage curtain's do.
DRAPE_X = (10.85, 13.0)
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
LED_DOT_PITCH = 0.24
LED_DOT_SIZE = 0.10
LED_DOT_BOTTOM = 0.45     # above the deck
LED_DOT_TOP = 5.65
## One portal's width (the rings are 4.9 m across) so the panel the two rings
## frame is no narrower than they are; 4.4 m leaves a hand of backdrop either
## side of it before the rings' inner edges at |x| 2.44.
CENTRE_SCREEN_HALF_W = 2.3
CENTRE_SCREEN_Y = (0.4, 5.2)   # above the deck
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
    build_flared_deck(cfg, stage, parts["RampLeds"])

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


def build_flared_deck(cfg: dict[str, float], stage: Part, leds: Part) -> None:
    """The deck as one closed solid whose front closes to the ramp's width.

    Rows run back to front; each row is a left and a right point at
    `flare_half_width`. The top is a strip of quads between rows, the sides
    skirt down to the floor, and the two ends are flat. The lit strip that
    runs the ramp's flanks carries on round the flare and along the deck's
    sides, in the same tube, so the leading edge reads as one line.

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

    # The lit leading edge: down each side of the deck and round the flare to
    # the ramp's own strip, which `build_deck_and_ramp` starts at STAGE_FRONT.
    for sx in (-1.0, 1.0):
        path = [Vector((sx * (flare_half_width(cfg, z) + 0.045), deck - 0.09, z))
                for z in zs[1:]]
        leds.tube(path, 0.040, sides=8)


def build_backdrop(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The wall the set stands against, and what is hung on it.

    Without the wall the portals are holes onto the Environment's background
    colour, which `measure_frame.py` scores as void -- a quarter of the
    frame's middle band on the first capture. A portal has to be a recess in
    something.

    The wall used to be all there was: one flat dark box, which from the ring
    reads as a painted flat. The reference's back of stage is a built thing,
    so the wall is now dressed with more pieces (each its own part, because
    each takes its own material):

    * `StageSidePanels` -- a tall perforated panel either side of the
      portals, lit faintly from within (the reference's lit side panels);
    * `StageDrape` -- pleated black cloth from the panels out to the ends of
      the wall;
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
    build_side_panels(cfg, parts, wall_front)
    build_drape(cfg, parts, wall_front)


def build_side_panels(cfg: dict[str, float], parts: dict[str, Part],
                      wall_front: float) -> None:
    """The lit perforated panels flanking the portals. Open sheets with
    normalised UVs, facing the ring; `paint_side_panel` draws them."""
    panels = parts["StageSidePanels"]
    deck = cfg["STAGE_DECK_Y"]
    z = wall_front + SIDE_PANEL_LIFT
    y0, y1 = deck + SIDE_PANEL_Y[0], deck + SIDE_PANEL_Y[1]
    x0, x1 = SIDE_PANEL_X
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * x0, sx * x1))
        v = [panels.vert(Vector(p)) for p in ((xa, y0, z), (xb, y0, z),
                                              (xb, y1, z), (xa, y1, z))]
        # u runs outward on both sides so the two mirror about the centre.
        if sx > 0.0:
            uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
        else:
            uvs = [(1.0, 0.0), (0.0, 0.0), (0.0, 1.0), (1.0, 1.0)]
        panels.quad(*v, uvs=uvs)
    paint_side_panel()
    paint_tunnel_lattice()


def build_drape(cfg: dict[str, float], parts: dict[str, Part],
                wall_front: float) -> None:
    """Pleated black cloth, floor to wall top, outboard of the side panels.

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


def paint_tunnel_lattice() -> None:
    """The tunnel's back wall as an emission picture over the disc's 0-1 UVs:
    lit lattice, dark round holes on a staggered grid, falling off toward the
    rim where the tunnel wall shades it."""
    import numpy as np
    from PIL import Image
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    pitch = 28.0
    row = np.floor(y / (pitch * 0.866))
    fx = np.mod(x + (row % 2) * pitch * 0.5, pitch) - pitch * 0.5
    fy = np.mod(y, pitch * 0.866) - pitch * 0.433
    sheet = (fx * fx + fy * fy > 10.5 * 10.5).astype(np.float32)
    r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    falloff = np.clip(1.0 - r, 0.0, 1.0) ** 0.6
    lavender = np.array((0.74, 0.62, 1.0), np.float32)
    rgb = np.clip(lavender * (sheet * (0.25 + 0.75 * falloff))[..., None], 0, 1) * 255
    Image.fromarray(np.round(rgb).astype(np.uint8), "RGB").save(TUNNEL_LATTICE_TEX, optimize=True)


def paint_side_panel() -> None:
    """The perforated panel's picture: a near-black sheet with a grid of
    round perforations lit from behind in the house violet, warming toward the
    foot, and a few brighter slot columns. Emission texture, so the level it
    ships at is the dial; the unlit sheet stays dark."""
    import numpy as np
    from PIL import Image
    w, h = 384, 736
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    v = 1.0 - y / h                      # 0 at the foot, 1 at the top
    pitch = 12.0
    fx = np.mod(x, pitch) - pitch * 0.5
    fy = np.mod(y, pitch) - pitch * 0.5
    hole = (fx * fx + fy * fy < 3.2 * 3.2).astype(np.float32)
    # Brighter at the foot, where the uplights are, fading up the panel.
    level = 0.30 + 0.70 * (1.0 - v) ** 1.5
    violet = np.array((0.46, 0.16, 0.92), np.float32)
    magenta = np.array((0.98, 0.22, 0.62), np.float32)
    mix = np.clip((1.0 - v) * 1.4 - 0.2, 0.0, 1.0)[..., None]
    colour = violet * (1.0 - mix) + magenta * mix
    slots = ((np.mod(x, 96.0) < 4.0)).astype(np.float32)[..., None]
    field = colour * (hole * level)[..., None]
    field = field * (1.0 - slots) + np.array((0.55, 0.30, 1.0), np.float32) * slots * 0.55
    # A solid border, the panel's frame.
    border = ((x < 6) | (x > w - 7) | (y < 6) | (y > h - 7))[..., None]
    field = np.where(border, 0.0, field)
    rgb = np.clip(field, 0, 1) * 255
    Image.fromarray(np.round(rgb).astype(np.uint8), "RGB").save(SIDE_PANEL_TEX, optimize=True)


def backdrop_half(cfg: dict[str, float]) -> float:
    """Half the backdrop's width. The owner's AEW stills have the set's black
    wall running wider than the video wall above it, its LED columns spread
    across the whole of it; ours stopped 1.2 m past the deck and left the end
    stand's seats showing either side of the portals. Now it runs
    BACKDROP_PAST_SCREEN beyond each end of the screen."""
    return cfg["SCREEN_WIDTH"] * 0.5 + cfg["SCREEN_BEZEL"] + BACKDROP_PAST_SCREEN


# The tunnel's insides (gauntlet/refs/stage/dynamite_portals_close.jpg,
# dynamite_stage_wide.jpg): LED bars on the tunnel's inner wall running back
# into it, on its outboard side; the lit lattice panel at the back, seen
# through the ring; a bank of small blue LED pods on the deck at its foot.
TUNNEL_BARS = 11
## The arc of the inner wall the bars cover, measured from straight outboard
## (0) up and down: 60 degrees up to 52 down, clear of the deck (the circle
## meets it 64 degrees down) and of the doorway the entrance walks through.
TUNNEL_BARS_UP = math.radians(60.0)
TUNNEL_BARS_DOWN = math.radians(52.0)
TUNNEL_BAR_RADIUS = 0.035
## Bars start just inside the ring and stop short of the back panel.
TUNNEL_BAR_FRONT = 0.05
TUNNEL_BAR_BACK = 0.12
## Each bar runs from the wall at the ring, back and INWARD to this fraction
## of the wall's radius at the back panel: head-on the bars read as the long
## fan of lines in the photographs, and they still recede with real depth.
## 0.42 keeps the inner ends clear of a man walking out down the middle.
TUNNEL_BAR_INNER = 0.42
TUNNEL_PODS = 4
TUNNEL_POD_SPACING = 0.34
## From the ring's centre line, outboard: the foot is 1.08 m out.
TUNNEL_POD_FROM = 1.40
TUNNEL_POD_RADIUS = 0.07


def ring_tube(part: Part, path: list[Vector], radius: float, sides: int) -> None:
    """The portal tube with authored UVs: u runs 0 -> 1 along the ring from
    its right-hand foot over the top to its left, v once round the section.
    The ring's colour gradient (arena_builder PORTAL_GRADIENT_*) is a strip
    texture read along u, so the tube must not take the world-metre
    projection every other part gets."""
    frames = venue._frames(path)
    rings: list[list[Vector]] = []
    for point, (_, normal, binormal) in zip(path, frames):
        ring = []
        for k in range(sides + 1):
            theta = 2.0 * math.pi * k / sides
            ring.append(point + normal * (math.cos(theta) * radius)
                        + binormal * (math.sin(theta) * radius))
        rings.append(ring)
    n = len(path) - 1
    for i in range(n):
        u0, u1 = i / n, (i + 1) / n
        for k in range(sides):
            v0, v1 = k / sides, (k + 1) / sides
            part.quad_at(rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k],
                         uvs=[(u0, v0), (u0, v1), (u1, v1), (u1, v0)])
    for end, u in ((0, 0.0), (n, 1.0)):
        verts = [part.vert(p) for p in rings[end][:sides]]
        face = part.bm.faces.new(verts if end else list(reversed(verts)))
        for loop in face.loops:
            loop[part.uv].uv = (u, 0.5)


def build_portals(cfg: dict[str, float], d: dict[str, float],
                  parts: dict[str, Part]) -> None:
    """Recess, light tunnel and lit ring, in that depth order.

    The ring is in front and is the brightest thing; behind it the tunnel is
    a dark, glossy bore with LED bars running back along its outboard wall
    and the lit lattice panel closing it -- the reference photographs read as
    a lit ring in front of a lit recess, with real depth between the two.
    """
    segments = int(cfg["PORTAL_RING_SEGMENTS"])
    sides = int(cfg["PORTAL_TUBE_SIDES"])
    cut = portal_cut_angle(cfg, d)
    depth = cfg["PORTAL_RECESS_DEPTH"]

    for sx, name in ((-1.0, "West"), (1.0, "East")):
        center = Vector((sx * cfg["PORTAL_OFFSET_X"], d["PORTAL_CENTER_Y"],
                         d["PORTAL_FACE_Z"]))

        # The recess: a cylinder bored back into the backdrop, open at the
        # back where the lattice panel closes it.
        radius = cfg["PORTAL_MAJOR"] - cfg["PORTAL_MINOR"] * 0.5
        rim = venue.arc(center, radius, 0.0, 2.0 * math.pi, segments, axis="z")
        back = [p - Vector((0.0, 0.0, depth)) for p in rim]
        recess = parts["PortalRecess"]
        for i in range(segments):
            recess.quad_at(rim[i], rim[i + 1], back[i + 1], back[i])

        # The lattice at the back: a disc with its own 0-1 UVs, so the
        # perforated panel's picture lands on it once, square.
        panel = parts["PortalBack"]
        cap_center = center - Vector((0.0, 0.0, depth - 0.01))
        for i in range(segments):
            a, b = back[i] + Vector((0.0, 0.0, 0.01)), back[i + 1] + Vector((0.0, 0.0, 0.01))
            uv = [(0.5, 0.5)] + [(0.5 + 0.5 * (p.x - cap_center.x) / radius,
                                 0.5 + 0.5 * (p.y - cap_center.y) / radius) for p in (a, b)]
            face = panel.bm.faces.new([panel.vert(cap_center), panel.vert(a), panel.vert(b)])
            for loop, coord in zip(face.loops, uv):
                loop[panel.uv].uv = coord

        # The ring: a circle with the bottom cut off by the deck. The sweep
        # runs from where the circle meets the deck on the right, the long way
        # over the top, to where it meets it on the left -- 308 degrees. There
        # are no legs and no feet; the tube simply stops at the deck, which is
        # what a circle sunk a quarter of a metre into a stage does.
        path = venue.arc(center, cfg["PORTAL_MAJOR"], cut, math.pi - cut,
                         segments, axis="z")
        ring_tube(parts["PortalRing%s" % name], path, cfg["PORTAL_MINOR"], sides)

        # The light tunnel: LED bars from the inner wall at the ring, back and
        # in toward the lattice, on the OUTBOARD side and clear of the doorway. Seen head-on they fan
        # toward the tunnel's vanishing point -- the reference's "sunburst"
        # -- and they keep doing so from any other angle, which a fan drawn
        # flat in the ring's plane (the old build) did not: at three-quarter
        # it read as a decal.
        out = math.pi if sx < 0.0 else 0.0
        fan = parts["PortalFan%s" % name]
        wall = radius - TUNNEL_BAR_RADIUS * 1.5
        for i in range(TUNNEL_BARS):
            k = i / (TUNNEL_BARS - 1)
            theta = out + (TUNNEL_BARS_UP if sx > 0.0 else -TUNNEL_BARS_UP) * (1.0 - k) \
                - (TUNNEL_BARS_DOWN if sx > 0.0 else -TUNNEL_BARS_DOWN) * k
            offset = Vector((math.cos(theta) * wall, math.sin(theta) * wall, 0.0))
            inner = Vector((math.cos(theta) * wall * TUNNEL_BAR_INNER,
                            math.sin(theta) * wall * TUNNEL_BAR_INNER, 0.0))
            fan.tube([center + offset - Vector((0.0, 0.0, TUNNEL_BAR_FRONT)),
                      center + inner - Vector((0.0, 0.0, depth - TUNNEL_BAR_BACK))],
                     TUNNEL_BAR_RADIUS, sides=6)

        # The LED pods: a short row of small round fixtures on the deck at the
        # ring's foot, aimed up at it (dynamite_stage_wide.jpg) -- OUTBOARD of
        # the foot, out of the line a man walks out of the tunnel on.
        pods = parts["PortalPods"]
        y = cfg["STAGE_DECK_Y"]
        for i in range(TUNNEL_PODS):
            x = center.x + sx * (TUNNEL_POD_FROM + i * TUNNEL_POD_SPACING)
            pods.cylinder(Vector((x, y, center.z + 0.35)), Vector((0.0, 1.0, 0.25)),
                          TUNNEL_POD_RADIUS, 0.10, sides=10)


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
    wall_front = cfg["STAGE_BACK"] - 0.2
    face_z = wall_front + 0.012
    dot_z = wall_front + SIDE_PANEL_LIFT + 0.012   # on the side panels
    deck = cfg["STAGE_DECK_Y"]
    dots = parts["StageLedDots"]
    h = LED_DOT_SIZE * 0.5
    for sx in (-1.0, 1.0):
        for x in LED_COLUMNS_X:
            n = int((LED_DOT_TOP - LED_DOT_BOTTOM) / LED_DOT_PITCH)
            for k in range(n + 1):
                y = deck + LED_DOT_BOTTOM + k * LED_DOT_PITCH
                c = Vector((sx * x, y, dot_z))
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
    build_portals(cfg, d, parts)
    build_screen(cfg, d, parts)
    build_stage_leds(cfg, parts)
    build_screen_wings(cfg, d, parts)
    build_truss_frame(cfg, d, parts)
    # The picture face is an open sheet and must look at the ring (+Z); the
    # portal recess is an open bore and what is seen is its inner wall.
    venue.finish(parts, PART_COLORS, emissive=EMISSIVE, smooth=SMOOTH,
                 projected=PROJECTED,
                 face_toward={"StageScreen": (0.0, 0.0, 1.0),
                              "PortalBack": (0.0, 0.0, 1.0),
                              "StageSidePanels": (0.0, 0.0, 1.0),
                              "StageDrape": (0.0, 0.0, 1.0),
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
