#!/usr/bin/env python3
"""Model the crowd that fills the seating bowl, seat by seat.

Imported by `arena_bowl.py`; it has no `main` of its own and is built and
exported by `tools/blender/build_arena.sh` along with the rest of the hall.

Why this is modelled rather than impostered
-------------------------------------------
The bowl carried a crowd once (removed in 7b91d0e) and it was two boxes per
person: a 0.42 x 0.58 x 0.30 torso with a 0.21 cube on top. At the distance
the broadcast camera sits that reads as a field of blocks, not as people --
there is no head-on-neck, no shoulder line, no lap, and every single one of
them is the same block.

What a crowd has to supply, and what a pair of boxes cannot, is VARIANCE: a
bowl of people is legible because no two silhouettes agree. So each figure
here is built from nine boxes -- hips, torso, head, two arms, two thighs, two
shins -- posed as somebody sitting down, and every one of them is a different
size, leaning a different way, with its arms somewhere else.

`gauntlet/refs/arena.md` measures an EMPTY bowl and that is why the crowd was
taken out. `gauntlet/refs/lighting.md` measures four full ones. The two
reference sets disagree about whether this building has people in it; this
file follows the second, and `build_seat_row`'s docstring in `arena_bowl.py`
records what the first one bought.

Budget
------
A bowl is ~3,500 seats. At 132 triangles a figure that is 460k triangles for
the crowd alone, against 102k for the entire hall, so the count is bought
back two ways, both of which the hall already does somewhere:

  * FILL. Real arenas are not full and a solid wall of heads reads as one
    surface again. CROWD_FILL leaves gaps, and the gaps are what make the
    rows countable.
  * LOD. `arena_builder.gd` already splits its floor chairs into a detailed
    near set and a proxy far set (FLOOR_CHAIR_DETAIL_ROWS). The lower tier
    gets the nine-box figure; the upper tier, which is never closer than
    ~25m to any camera in ART_SHOTS, gets a four-box one that keeps the head
    and the shoulder line and drops the limbs.

Animation
---------
Baked geometry cannot carry a skeleton per person -- thousands of skinned
characters is not a thing that runs -- and ARCHITECTURE.md requires cosmetic
motion to be incapable of touching gameplay state or a replay's end-state
hash. The crowd is therefore animated by a vertex shader in
`arena_builder.gd`, which is what the old impostors did and is the reason
that clause is worded the way it is.

That shader phased its motion off `INSTANCE_ID`, which worked while the crowd
was a MultiMesh. These are baked into the bowl's own mesh, so every figure
shares one instance id. The per-figure phase is written here instead, into
**vertex colour alpha**, where glTF carries it through as COLOR_0.a and the
shader reads it directly. Colour rgb is the shirt.
"""

from __future__ import annotations

import math
import random

from mathutils import Vector

# --- Palette ----------------------------------------------------------------
# Recovered from the removed crowd, which sized it against a measurement:
# the reference frames' crowd sits at relative luminance 0.014
# (VISUAL_BAR.md), so a bright crowd is not closer to the reference, it is
# further from it. What the crowd is for is variance, not brightness.
#
# Widened from eight to fourteen because eight repeats visibly once the
# figures are big enough to tell apart, and because the AEW references in
# gauntlet/refs/lighting/ are not monochrome -- there is warmth in a real
# crowd even at this level.
SHIRT_COLORS = [
    (0.20, 0.21, 0.26), (0.28, 0.24, 0.24), (0.17, 0.20, 0.24),
    (0.31, 0.29, 0.27), (0.22, 0.26, 0.28), (0.26, 0.22, 0.29),
    (0.15, 0.16, 0.19), (0.33, 0.31, 0.33), (0.19, 0.23, 0.21),
    (0.30, 0.26, 0.22), (0.24, 0.20, 0.22), (0.18, 0.19, 0.27),
    (0.29, 0.30, 0.31), (0.21, 0.18, 0.18),
]
## Skin is a separate, narrower palette: heads and forearms are small and a
## wide spread there reads as noise rather than as people.
SKIN_COLORS = [
    (0.38, 0.28, 0.22), (0.30, 0.21, 0.16), (0.44, 0.33, 0.26),
    (0.22, 0.15, 0.12), (0.35, 0.25, 0.19), (0.48, 0.37, 0.30),
]

## Fraction of seats occupied. 0.86 is the figure the removed crowd used.
CROWD_FILL = 0.86
## Of those, the fraction standing rather than seated. People stand up at a
## wrestling show, and a row where every head is at exactly one height is the
## single most obviously generated thing a stadium crowd can do.
STANDING_FRACTION = 0.07
## Seed. Fixed so the same build produces the same arena every run --
## ARCHITECTURE.md's determinism contract applies to the committed .glb as
## much as to gameplay: a capture is only comparable between rounds if the
## hall is identical.
CROWD_SEED = 20260914

## How many rows from the front get the full nine-box figure.
##
## By ROW rather than by tier, and four rather than twelve, because the cost
## is not in the triangles -- it is in the vertices. A flat-shaded box cannot
## share a vertex between two faces (they need different normals), so each
## nine-box figure is 216 vertices of position + normal + colour. At the
## whole lower tier that was a 52 MB .glb against the hall's 5.6, which is not
## a committable asset.
##
## Four rows is what the broadcast camera actually gets close to: ART_SHOTS'
## nearest bowl framing is `crowd_bank`, and past the fourth row a nine-box
## figure and a four-box one are the same handful of pixels.
DETAILED_ROWS = 4


def _shade(rng: random.Random, base: tuple[float, float, float]) -> tuple:
    """A colour, jittered. Two people in the same shirt are still not the same
    colour under the same light, and without this the palette reads as
    fourteen uniforms rather than as a crowd."""
    k = rng.uniform(0.82, 1.18)
    return (base[0] * k, base[1] * k, base[2] * k)


class Figure:
    """One person, as a stack of oriented boxes in the row's own frame.

    `along` runs down the row, `out` points away from the ring, and the
    figure is built around `seat`, the point on the tread its backside is
    over. Everything is expressed in those two vectors rather than in world
    axes, for the same reason `build_seat_row` is: on the bowl's curved ends
    an axis-aligned person sits skewed to the row.
    """

    def __init__(self, part, seat: Vector, along: Vector, out: Vector,
                 colour, phase: float, lift: float = 0.0) -> None:
        self.part = part
        # `lift` raises the whole figure off its reference point. The bowl
        # sits people on the tread (0); a ringside folding chair puts its seat
        # pan most of half a metre up, and a figure built for one and placed
        # on the other is either buried or hovering.
        self.seat = seat + Vector((0.0, lift, 0.0))
        self.along = along.normalized()
        # Toward the ring. A spectator faces the action, not the concourse.
        self.face = -out.normalized()
        self.colour = colour
        self.phase = phase

    def box(self, offset: Vector, size: Vector, colour=None,
            lean: float = 0.0) -> None:
        """A box at `offset` from the seat, in (across, up, toward-ring).

        `lean` tips it forward about the across-axis, which is what makes a
        torso lean in and a thigh lie flat.
        """
        up = Vector((0.0, 1.0, 0.0))
        centre = (self.seat
                  + self.along * offset.x
                  + up * offset.y
                  + self.face * offset.z)
        # Rotate the up/forward pair by `lean` about the row axis.
        c, s = math.cos(lean), math.sin(lean)
        axis_u = up * c + self.face * s
        axis_f = self.face * c - up * s
        ea = self.along * (size.x * 0.5)
        eu = axis_u * (size.y * 0.5)
        eo = axis_f * (size.z * 0.5)
        corners = [
            centre + ea * sa + eu * su + eo * so
            for sa, su, so in (
                (-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1),
            )
        ]
        self.part.coloured_box(corners, colour or self.colour, self.phase)


def _seated(fig: Figure, rng: random.Random, scale: float, skin) -> None:
    """The nine-box seated figure: hips, torso, head, two arms, two thighs,
    two shins. Proportions are a real seated adult scaled by `scale`; the
    lean, the arm angle and the knee spread are all rolled per person."""
    lean = rng.uniform(0.05, 0.38)          # forward, radians
    s = scale

    # Hips on the seat.
    fig.box(Vector((0.0, 0.10 * s, 0.02 * s)),
            Vector((0.34 * s, 0.20 * s, 0.30 * s)))
    # Torso, leaning in toward the ring.
    fig.box(Vector((0.0, 0.38 * s, 0.05 * s + lean * 0.10 * s)),
            Vector((0.36 * s, 0.42 * s, 0.24 * s)), lean=lean)
    # Neck and head. The head carries the lean plus a little of its own, so
    # nobody is looking at their own lap.
    head_lean = lean * rng.uniform(0.35, 0.8)
    fig.box(Vector((0.0, 0.66 * s, 0.07 * s + lean * 0.18 * s)),
            Vector((0.12 * s, 0.08 * s, 0.12 * s)), colour=skin)
    fig.box(Vector((0.0, 0.77 * s, 0.08 * s + lean * 0.22 * s)),
            Vector((0.19 * s, 0.22 * s, 0.20 * s)), colour=skin,
            lean=head_lean)

    # Arms. Four postures, because a crowd all holding the same pose is the
    # other half of the block problem the old impostors had.
    posture = rng.random()
    for side in (-1.0, 1.0):
        x = side * 0.23 * s
        if posture < 0.12:
            # Both up -- somebody reacting to the match.
            fig.box(Vector((x, 0.62 * s, 0.06 * s)),
                    Vector((0.11 * s, 0.38 * s, 0.11 * s)))
            fig.box(Vector((x * 1.15, 0.86 * s, 0.04 * s)),
                    Vector((0.10 * s, 0.30 * s, 0.10 * s)), colour=skin)
        elif posture < 0.30:
            # Forearms on knees, leaning in.
            fig.box(Vector((x, 0.38 * s, 0.10 * s)),
                    Vector((0.11 * s, 0.34 * s, 0.12 * s)), lean=lean * 1.2)
            fig.box(Vector((x * 0.85, 0.22 * s, 0.30 * s)),
                    Vector((0.10 * s, 0.10 * s, 0.30 * s)), colour=skin)
        elif posture < 0.48:
            # Arms folded across the chest.
            fig.box(Vector((x, 0.44 * s, 0.12 * s)),
                    Vector((0.11 * s, 0.30 * s, 0.12 * s)), lean=0.9 * side)
            fig.box(Vector((x * 0.35, 0.40 * s, 0.17 * s)),
                    Vector((0.26 * s, 0.10 * s, 0.11 * s)), colour=skin)
        else:
            # Hanging at the side, which is most people most of the time.
            fig.box(Vector((x, 0.40 * s, 0.02 * s)),
                    Vector((0.11 * s, 0.38 * s, 0.13 * s)))
            fig.box(Vector((x, 0.18 * s, 0.08 * s)),
                    Vector((0.10 * s, 0.26 * s, 0.11 * s)), colour=skin)

    # Legs. Thighs forward off the seat, shins down off the knee, with the
    # knees spread by a per-person amount.
    spread = rng.uniform(0.9, 1.45)
    for side in (-1.0, 1.0):
        x = side * 0.11 * s * spread
        fig.box(Vector((x, 0.06 * s, 0.22 * s)),
                Vector((0.15 * s, 0.15 * s, 0.38 * s)))
        fig.box(Vector((x, -0.18 * s, 0.38 * s)),
                Vector((0.13 * s, 0.40 * s, 0.14 * s)))


def _standing(fig: Figure, rng: random.Random, scale: float, skin) -> None:
    """Upright, on their feet in front of the seat. Same part list, straighter
    and a head higher, so a standing figure breaks the row's head line."""
    s = scale
    lean = rng.uniform(-0.04, 0.12)
    fig.box(Vector((0.0, 0.48 * s, 0.20 * s)),
            Vector((0.32 * s, 0.24 * s, 0.24 * s)))
    fig.box(Vector((0.0, 0.82 * s, 0.20 * s)),
            Vector((0.36 * s, 0.46 * s, 0.24 * s)), lean=lean)
    fig.box(Vector((0.0, 1.12 * s, 0.20 * s)),
            Vector((0.12 * s, 0.09 * s, 0.12 * s)), colour=skin)
    fig.box(Vector((0.0, 1.24 * s, 0.21 * s)),
            Vector((0.19 * s, 0.22 * s, 0.20 * s)), colour=skin, lean=lean)
    arms_up = rng.random() < 0.35
    for side in (-1.0, 1.0):
        x = side * 0.23 * s
        if arms_up:
            fig.box(Vector((x, 1.06 * s, 0.18 * s)),
                    Vector((0.11 * s, 0.40 * s, 0.11 * s)))
            fig.box(Vector((x * 1.1, 1.32 * s, 0.16 * s)),
                    Vector((0.10 * s, 0.32 * s, 0.10 * s)), colour=skin)
        else:
            fig.box(Vector((x, 0.82 * s, 0.19 * s)),
                    Vector((0.11 * s, 0.40 * s, 0.13 * s)))
            fig.box(Vector((x, 0.56 * s, 0.20 * s)),
                    Vector((0.10 * s, 0.28 * s, 0.11 * s)), colour=skin)
    for side in (-1.0, 1.0):
        fig.box(Vector((side * 0.10 * s, 0.18 * s, 0.20 * s)),
                Vector((0.14 * s, 0.62 * s, 0.16 * s)))


def _distant(fig: Figure, rng: random.Random, scale: float, skin) -> None:
    """The upper-tier figure: head, shoulders, torso, lap. Four boxes.

    What survives is what is still legible at 25m -- the head-neck-shoulder
    silhouette and the break between torso and lap. The limbs are gone
    because at that distance they are sub-pixel and cost 60% of the figure.
    """
    s = scale
    lean = rng.uniform(0.04, 0.30)
    fig.box(Vector((0.0, 0.12 * s, 0.06 * s)),
            Vector((0.36 * s, 0.24 * s, 0.34 * s)))
    fig.box(Vector((0.0, 0.40 * s, 0.06 * s + lean * 0.10 * s)),
            Vector((0.40 * s, 0.40 * s, 0.26 * s)), lean=lean)
    fig.box(Vector((0.0, 0.64 * s, 0.08 * s + lean * 0.18 * s)),
            Vector((0.13 * s, 0.09 * s, 0.13 * s)), colour=skin)
    fig.box(Vector((0.0, 0.76 * s, 0.09 * s + lean * 0.22 * s)),
            Vector((0.20 * s, 0.22 * s, 0.21 * s)), colour=skin, lean=lean)


def build_crowd(cfg, parts, rows, plan_loop, aisle_indices, stage_gap) -> dict:
    """Fill the bowl. Returns a count per part, for the build's own report.

    Walks each seated row exactly as `build_seat_row` does -- same curve, same
    pitch, same aisle and stage-gap exclusions -- so a person lands on a seat
    rather than near one. The only difference is the offset: the seat box sits
    at 0.62 of the row's depth and a person sits slightly in front of it.
    """
    rng = random.Random(CROWD_SEED)
    pitch = cfg["SEAT_PITCH"]
    clearance = cfg["AISLE_CLEARANCE"]
    built = {"Crowd": 0, "CrowdFar": 0, "standing": 0}

    for row in rows:
        if row["kind"] != "seated":
            continue
        detailed = row["tier"] == 0 and row["index"] < DETAILED_ROWS
        part = parts["Crowd" if detailed else "CrowdFar"]
        depth = row["outer"] - row["inner"]
        # 0.48 rather than the seat's 0.62: a seated person's mass is forward
        # of the seat back they are against.
        loop = plan_loop(cfg, row["inner"] + depth * 0.48)
        avoid = [loop[i][0] for i in aisle_indices(cfg)]

        carry = 0.0
        for i in range(len(loop)):
            here, normal = loop[i]
            nxt = loop[(i + 1) % len(loop)][0]
            run = nxt - here
            span = run.length
            if span <= 0.0:
                continue
            along = run / span
            at = pitch - carry
            while at < span:
                point = here + run * (at / span)
                at += pitch
                if stage_gap(cfg, point):
                    continue
                if any((point - gap).length < clearance for gap in avoid):
                    continue
                if rng.random() > CROWD_FILL:
                    continue

                shirt = _shade(rng, rng.choice(SHIRT_COLORS))
                skin = _shade(rng, rng.choice(SKIN_COLORS))
                # Golden-ratio phase, the spread the old shader used: adjacent
                # seats never move together and the pattern never repeats
                # along a row.
                phase = (built["Crowd"] + built["CrowdFar"]) * 0.6180339887
                seat = Vector((point.x, row["tread_y"], point.z))
                figure = Figure(part, seat, along, normal, shirt, phase % 1.0)
                scale = rng.uniform(0.88, 1.08)

                if detailed and rng.random() < STANDING_FRACTION:
                    _standing(figure, rng, scale, skin)
                    built["standing"] += 1
                elif detailed:
                    _seated(figure, rng, scale, skin)
                else:
                    _distant(figure, rng, scale, skin)
                built["Crowd" if detailed else "CrowdFar"] += 1
            carry = span - (at - pitch)
    return built


# --- Standalone figures, for instancing ------------------------------------
#
# The bowl's crowd is baked into the hall's own mesh because it sits on twenty
# different rows of a curve and no two people are alike. The ringside floor is
# the opposite case: `arena_builder.gd` already computes a transform per
# folding chair, so those figures want to be INSTANCED, and an instance needs
# one mesh.
#
# The compromise is a handful of distinct people rather than one. Each variant
# below is a full figure built at the origin facing +Z -- the frame the chair
# prop is modelled in, so a figure drops onto a chair's transform unchanged --
# and `arena_builder.gd` spreads the seats across them. Pose variety comes
# from there being several; size and shirt vary per instance on top.

## How many distinct ringside people to export. Six is enough that a bank of
## chairs does not read as a repeat at the distance `ringside_low` frames it,
## and few enough that each is still one draw call.
FLOOR_VARIANTS = 6
## Height of a folding chair's seat pan. The figures are lifted by this so
## they sit ON the chair rather than through it.
CHAIR_SEAT_HEIGHT = 0.45
## Separate seed: the bowl's placement and these poses are different rolls,
## and sharing one would couple "re-pose the ringside fans" to "re-seat the
## entire bowl".
FLOOR_SEED = 20260915


def build_floor_variants(make_part) -> list:
    """Build FLOOR_VARIANTS seated people, each into its own Part.

    `make_part(name)` is supplied by the caller so this file does not need to
    know how a Part is constructed or registered. Returns the part names in
    order.

    Colour is left FLAT here and overridden per instance in Godot: a MultiMesh
    carries a colour per instance, which is a better place for it than the
    mesh, and it means six meshes can dress a thousand different people.
    """
    rng = random.Random(FLOOR_SEED)
    names = []
    for index in range(FLOOR_VARIANTS):
        name = "Fan%02d" % index
        part = make_part(name)
        figure = Figure(
            part,
            Vector((0.0, 0.0, 0.0)),
            Vector((1.0, 0.0, 0.0)),   # along the row
            Vector((0.0, 0.0, -1.0)),  # out; face is -out, so +Z
            (1.0, 1.0, 1.0),
            0.0,
            lift=CHAIR_SEAT_HEIGHT,
        )
        # White shirt, mid skin: the instance colour multiplies this, so the
        # mesh has to be neutral or every fan comes out tinted twice.
        figure.colour = (1.0, 1.0, 1.0)
        _seated(figure, rng, rng.uniform(0.94, 1.06), (0.72, 0.72, 0.72))
        names.append(name)
    return names
