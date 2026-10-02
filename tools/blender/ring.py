#!/usr/bin/env python3
"""Build the ring's steel and rope in Blender, and export it as glTF.

Run:  tools/blender/build_venue.sh ring

What this builds
----------------
The four corner posts, every rope termination on them, the twelve rope spans,
the apron frame the skirt hangs from, and the steel steps.

What it deliberately does not build, and why
--------------------------------------------
* **The canvas.** It stays generated in `ring_builder.gd`. Its mesh is two
  flat quads -- there is no shape here for Blender to improve -- while its
  substance is a 1024px procedural texture of weave, panel seams and wear, and
  its node path `Ring/Floor/MeshInstance3D` is what `capture_harness.gd` keys
  the silhouette mask off. Moving two quads would risk a load-bearing path to
  gain nothing.
* **Every collider.** The ring's physics -- `Floor/CollisionShape3D` and the
  four `RopeCollision*` bodies in the group `ring_ropes` -- stays in
  `scenes/ring.tscn` at its original extents. Rope sag is a displacement of
  the *rendered* mesh only; the bodies wrestlers bounce off have not moved.
* **Every material.** `ring_builder.gd` dresses each part below by name from
  `MaterialLibrary`, because the ring's tints are solved against measured
  luminance targets in `gauntlet/refs/VISUAL_BAR.md`.

What moving it to Blender actually buys
---------------------------------------
Three things GDScript's `SurfaceTool` could not reasonably do:

* **Bevelled arrises.** Posts, apron rails and steps carry a real chamfer.
  A perfectly sharp 90-degree edge takes no highlight from the house rig at
  all, and that is the clearest tell of geometry that was typed as eight
  corners. The reference (`gauntlet/refs/ring.md`) shows padded post edges
  and rolled steel, neither of which is sharp.
* **Round turnbuckle sleeves.** `ring_builder.gd` drew each one as a box,
  with the note that "at this size the silhouette is four pixels and a box
  costs a third of the triangles". A swept 8-sided tube costs about 900
  triangles across all 24 sleeves, which at this budget is nothing.
* **Step stringers.** The steps were three stacked slabs with open sides and
  nothing holding them together. They now carry a side panel down each flank,
  which is what makes a flight of ring steps read as one object.

Dimensions are READ OUT OF `game/core/ring/ring_builder.gd` (see
`venue.read_constants`), never retyped, so the mesh and the game cannot drift.
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
    "ROPE_SPAN", "ROPE_RADIUS", "ROPE_SEGMENTS", "ROPE_END",
    "ROPE_HEIGHT_BOTTOM", "ROPE_HEIGHT_MIDDLE", "ROPE_HEIGHT_TOP",
    "ROPE_SAG_BOTTOM", "ROPE_SAG_MIDDLE", "ROPE_SAG_TOP",
    "POST_XZ", "POST_RADIUS", "POST_SIDES", "POST_BOTTOM", "POST_TOP",
    "CLAMP_LENGTH", "CLAMP_RADIUS", "CLAMP_INSET",
    "PAD_FACE_WIDTH", "PAD_FACE_HEIGHT", "PAD_FACE_LIFT", "PAD_FACE_V_SPAN",
    "TURNBUCKLE_PAD_WIDTH", "TURNBUCKLE_PAD_HEIGHT", "TURNBUCKLE_PAD_DEPTH",
    "TURNBUCKLE_PAD_XZ", "TURNBUCKLE_PAD_BEVEL",
    "TURNBUCKLE_ROD_RADIUS", "TURNBUCKLE_BODY_LENGTH", "TURNBUCKLE_BODY_BAR_RADIUS",
    "TURNBUCKLE_BODY_HALF_GAP", "TURNBUCKLE_BOSS_RADIUS", "TURNBUCKLE_EYE_RADIUS",
    "POST_COLLAR_RADIUS", "POST_COLLAR_HEIGHT",
    "APRON_OUT", "APRON_TOP", "APRON_BOTTOM",
    "STEP_TREADS", "STEP_WIDTH", "STEP_RUN", "STEP_TOP_Y", "STEP_FLOOR_Y",
    "STEP_APRON_GAP", "STEP_PLATFORM", "APRON_OUT",
]

# Placeholder colours only; ring_builder.gd overrides all four by name.
PART_COLORS = {
    "PostMesh": (0.075, 0.075, 0.080, 1.0),
    "TurnbuckleFittings": (0.11, 0.11, 0.115, 1.0),
    "TurnbuckleHardware": (0.56, 0.57, 0.58, 1.0),
    "TurnbucklePads": (0.055, 0.055, 0.060, 1.0),
    "TurnbuckleFaces": (0.9, 0.9, 0.9, 1.0),
    "RopeMesh": (0.88, 0.88, 0.87, 1.0),
    "ApronRail": (0.105, 0.105, 0.112, 1.0),
    "StepsMesh": (0.62, 0.62, 0.63, 1.0),
    "StepTreads": (0.36, 0.36, 0.37, 1.0),
    "StepsTrim": (0.05, 0.05, 0.05, 1.0),
}
# Ropes and sleeves are round and must read that way; the posts, rails and
# steps are faceted steel and smoothing them only muddies the arris the bevel
# was added to catch.
SMOOTH = frozenset({"RopeMesh", "TurnbuckleFittings", "TurnbucklePads",
                    "TurnbuckleHardware"})
## Parts whose UVs AND winding are authored rather than derived. Both have to
## travel together: authored UVs are only meaningful on a face that is shown
## the right way round.
UNPROJECTED = frozenset({"TurnbuckleFaces"})

# Bevel widths, as a fraction of the smallest section each piece has. Small:
# these are chamfers that catch a highlight, not rounded-over furniture.
POST_BEVEL = 0.010
## The pad's rounding is NOT here with the others: it lives in
## ring_builder.gd as TURNBUCKLE_PAD_BEVEL, because it eats into the pad's
## clearance over the post and a test has to be able to see both numbers.
RAIL_BEVEL = 0.018
STEP_BEVEL = 0.012


def rope_heights(cfg: dict[str, float]) -> list[tuple[float, float]]:
    """(height, sag) per rope, bottom to top -- the same pairing
    `ring_builder.gd`'s ROPE_SAG dictionary makes."""
    return [
        (cfg["ROPE_HEIGHT_BOTTOM"], cfg["ROPE_SAG_BOTTOM"]),
        (cfg["ROPE_HEIGHT_MIDDLE"], cfg["ROPE_SAG_MIDDLE"]),
        (cfg["ROPE_HEIGHT_TOP"], cfg["ROPE_SAG_TOP"]),
    ]


def build_posts(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Four corner posts: a round tube with a disc cap.

    These were 0.155m square columns carrying a cap plate 1.22x their own
    section. A real ring post is a length of 4-inch pipe -- slim enough that
    the turnbuckle pads are obviously the widest thing at a corner, and capped
    with a disc barely proud of the tube. The square version read as a
    structural pillar with wings, and the overhanging plate gave every corner
    a lid.

    Built as a tube rather than a bevelled box so the highlight travels round
    it as the house rig moves, which is the whole reason the reference's posts
    read as metal at all.
    """
    post = parts["PostMesh"]
    radius = cfg["POST_RADIUS"]
    sides = int(cfg["POST_SIDES"])
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            x = cfg["POST_XZ"] * sx
            z = cfg["POST_XZ"] * sz
            post.tube(
                [Vector((x, cfg["POST_BOTTOM"], z)),
                 Vector((x, cfg["POST_TOP"], z))],
                radius, sides=sides,
            )
            # The cap: a short, slightly wider disc closing the tube. Proud by
            # 6mm, not by a quarter of the post's width.
            post.tube(
                [Vector((x, cfg["POST_TOP"], z)),
                 Vector((x, cfg["POST_TOP"] + 0.020, z))],
                radius * 1.12, sides=sides,
            )


def build_terminations(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The clamp each rope visibly ends in, where it runs into its pad.

    This used to be a sleeve and a clevis mounted on the POST, pointing in at
    the mat. That was right for a bare corner and wrong for a padded one --
    long, it broke out through the cushion's rounded edge; short, it vanished
    inside it. Either way the reference shows something the post-mounted
    version could never show: a dark clamp on the white rope itself, at the
    point the rope meets the pad.

    So the fitting sits on the rope now. Each corner carries two ropes per
    height -- one down X, one down Z -- so it carries two clamps per height,
    straddling the line where the pad's edge crosses the rope.
    """
    fitting = parts["TurnbuckleFittings"]
    # Where the pad's edge crosses a rope. The pad is turned to the diagonal,
    # so half its width projects onto the rope's axis by a factor of sqrt(2).
    pad_edge = cfg["ROPE_SPAN"] - cfg["TURNBUCKLE_PAD_WIDTH"] * 0.5 * math.sqrt(2.0)
    at = pad_edge - cfg["CLAMP_INSET"]
    half = cfg["CLAMP_LENGTH"] * 0.5
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            for height, _ in rope_heights(cfg):
                # The rope running down X at this corner, then the one down Z.
                for along, across in ((Vector((1.0, 0.0, 0.0)), sz),
                                      (Vector((0.0, 0.0, 1.0)), sx)):
                    sign = sx if along.x != 0.0 else sz
                    offset = Vector((0.0, 0.0, cfg["ROPE_SPAN"] * across)) \
                        if along.x != 0.0 \
                        else Vector((cfg["ROPE_SPAN"] * across, 0.0, 0.0))
                    centre = offset + Vector((0.0, height, 0.0)) \
                        + along * (at * sign)
                    fitting.tube(
                        [centre - along * (half * sign),
                         centre + along * (half * sign)],
                        cfg["CLAMP_RADIUS"], sides=8,
                    )


def build_turnbuckle_pads(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Three cushions on every corner, turned to face the ring centre.

    Each pad is one rounded box on the corner diagonal at a rope's height, so
    twelve in all. The rope ends are already inside it -- TURNBUCKLE_PAD_XZ is
    chosen so the X and Z terminations land within the pad's own depth -- which
    is what makes a rope read as ATTACHED rather than as passing a pole.

    The pad is the one piece here that does not share the post's frame. The
    post is axis-aligned because its flat face reads down a side-on camera;
    the pad is diagonal because it is mounted on the corner and faces the mat.
    `oriented_box` takes that frame directly: `along` is the tangent across the
    corner, `out` is the inward diagonal.
    """
    pads = parts["TurnbucklePads"]
    offset = cfg["TURNBUCKLE_PAD_XZ"]
    size = Vector((cfg["TURNBUCKLE_PAD_WIDTH"],
                   cfg["TURNBUCKLE_PAD_HEIGHT"],
                   cfg["TURNBUCKLE_PAD_DEPTH"]))
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            # Toward the ring centre, and the tangent across it. Both are
            # normalised by oriented_box, so the raw diagonal is enough.
            inward = Vector((-sx, 0.0, -sz))
            tangent = Vector((-sx, 0.0, sz))
            for height, _ in rope_heights(cfg):
                center = Vector((offset * sx, height, offset * sz))
                pads.oriented_box(center, tangent, inward, size,
                                  bevel=cfg["TURNBUCKLE_PAD_BEVEL"],
                                  bevel_segments=2)


def build_turnbuckles(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """What joins each pad to its post: hook rod, turnbuckle body, eye bolt.

    A real rope ends in a forged turnbuckle; the pad is laced round it, and the
    turnbuckle hooks an eye bolt through a collar on the post. So between the
    back of every pad and the post there is bare galvanised hardware -- the
    connector the owner asked for, in place of the pads wrapped round the post
    they replaced. Built along the corner diagonal at each rope height:

    * a collar round the post, which the eye bolt goes through;
    * the eye bolt: a rod from inside the post out to an eye;
    * the turnbuckle body: two side bars between two end bosses;
    * the hook rod from the body into the back of the pad.
    """
    hw = parts["TurnbuckleHardware"]
    diagonal = math.sqrt(2.0)
    post_u = cfg["POST_XZ"] * diagonal
    back_u = cfg["TURNBUCKLE_PAD_XZ"] * diagonal + cfg["TURNBUCKLE_PAD_DEPTH"] * 0.5
    post_face_u = post_u - cfg["POST_RADIUS"]
    rod = cfg["TURNBUCKLE_ROD_RADIUS"]
    body = cfg["TURNBUCKLE_BODY_LENGTH"]
    # The body sits in the middle of the gap, the eye just off the post.
    mid_u = (back_u + post_face_u) * 0.5
    b0, b1 = mid_u - body * 0.5, mid_u + body * 0.5
    eye_r = cfg["TURNBUCKLE_EYE_RADIUS"]
    eye_u = post_face_u - eye_r - 0.004
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            d = Vector((sx, 0.0, sz)).normalized()
            side = Vector((-sz, 0.0, sx)).normalized()
            up = Vector((0.0, 1.0, 0.0))
            post = Vector((cfg["POST_XZ"] * sx, 0.0, cfg["POST_XZ"] * sz))
            for height, _ in rope_heights(cfg):
                h = up * height

                def at(u, _d=d, _h=h):
                    return _d * u + _h

                # Collar round the post.
                hw.tube([post + h - up * (cfg["POST_COLLAR_HEIGHT"] * 0.5),
                         post + h + up * (cfg["POST_COLLAR_HEIGHT"] * 0.5)],
                        cfg["POST_COLLAR_RADIUS"], sides=12)
                # Eye bolt: from inside the post out to its eye.
                hw.tube([at(post_u), at(eye_u + eye_r)], rod, sides=8)
                # The eye: a ring in the vertical plane of the diagonal.
                loop = []
                for k in range(13):
                    a = 2.0 * math.pi * k / 12
                    loop.append(at(eye_u) + d * (math.cos(a) * eye_r)
                                + up * (math.sin(a) * eye_r))
                hw.tube(loop, rod * 0.7, sides=6, caps=False)
                # Hook from the body's outer boss through the eye.
                hw.tube([at(b1), at(eye_u - eye_r * 0.4)], rod, sides=8)
                # The turnbuckle body: end bosses and two side bars.
                for u in (b0, b1):
                    hw.tube([at(u - 0.007), at(u + 0.007)],
                            cfg["TURNBUCKLE_BOSS_RADIUS"], sides=10)
                for s in (-1.0, 1.0):
                    off = side * (cfg["TURNBUCKLE_BODY_HALF_GAP"] * s)
                    hw.tube([at(b0) + off, at(b1) + off],
                            cfg["TURNBUCKLE_BODY_BAR_RADIUS"], sides=6)
                # Into the back of the pad, where the rope ends meet it.
                hw.tube([at(back_u - 0.03), at(b0)], rod, sides=8)


def build_pad_faces(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The AEW artwork on the front of each cushion, as a flat quad.

    A decal, not a mapping of the pad itself. `_beveled` boxes get `venue.py`'s
    planar world projection, which tiles by world position -- right for cloth,
    useless for landing one logo the right way up, once, on one face of twelve
    boxes. Explicit UVs on a quad are smaller and fully controllable, and the
    cushion's rounded silhouette is left alone behind it.

    Wound top-left, bottom-left, bottom-right, top-right so the normal comes
    out along `inward`; the other order faces the quad at the crowd and it
    renders as nothing from the mat.
    """
    faces = parts["TurnbuckleFaces"]
    diagonal = math.sqrt(2.0)
    # Just proud of the cushion's flat front, to stay out of a depth fight.
    face_u = cfg["TURNBUCKLE_PAD_XZ"] * diagonal \
        - cfg["TURNBUCKLE_PAD_DEPTH"] * 0.5 - cfg["PAD_FACE_LIFT"]
    per_axis = face_u / diagonal
    half_w = cfg["PAD_FACE_WIDTH"] * 0.5
    half_h = cfg["PAD_FACE_HEIGHT"] * 0.5
    # Crop the artwork's height to the quad's aspect -- see PAD_FACE_V_SPAN.
    v0 = (1.0 - cfg["PAD_FACE_V_SPAN"]) * 0.5
    v1 = v0 + cfg["PAD_FACE_V_SPAN"]
    up = Vector((0.0, 1.0, 0.0))
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            # (-sz, 0, sx), NOT the (-sx, 0, sz) the pads themselves use.
            # Both are perpendicular to the inward diagonal and either will do
            # for placing a symmetric box, but the quad's winding is a cross
            # product and its SIGN follows the parity of sx*sz: with
            # (-sx, 0, sz) two of the four corners come out facing the crowd.
            # That is why half the pads rendered their logo mirrored and half
            # did not -- and with a two-sided material, nothing vanished to
            # say so.
            tangent = Vector((-sz, 0.0, sx)).normalized()
            for height, _ in rope_heights(cfg):
                centre = Vector((per_axis * sx, height, per_axis * sz))
                faces.quad_at(
                    centre - tangent * half_w + up * half_h,
                    centre - tangent * half_w - up * half_h,
                    centre + tangent * half_w - up * half_h,
                    centre + tangent * half_w + up * half_h,
                    [(0.0, v1), (0.0, v0), (1.0, v0), (1.0, v1)],
                )


def build_ropes(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Twelve spans, each swept along a parabola.

    A catenary and a parabola differ by less than a millimetre over 6 m at
    this sag, and the parabola is the one that can be written down. The sag
    is rendered only -- the collision bodies are straight and unmoved.
    """
    rope = parts["RopeMesh"]
    # To the rope's end inside its pad (ROPE_END), not to the post.
    half = cfg["ROPE_END"]
    segments = int(cfg["ROPE_SEGMENTS"])
    for height, sag in rope_heights(cfg):
        for side in range(4):
            along = Vector((1.0, 0.0, 0.0)) if side < 2 else Vector((0.0, 0.0, 1.0))
            out = Vector((0.0, 0.0, 1.0)) if side < 2 else Vector((1.0, 0.0, 0.0))
            sign_out = 1.0 if side % 2 == 0 else -1.0
            base = out * (cfg["ROPE_SPAN"] * sign_out) + Vector((0.0, height, 0.0))
            path = []
            for seg in range(segments + 1):
                t = seg / segments
                s = -half + (half - -half) * t
                drop = sag * 4.0 * t * (1.0 - t)
                path.append(base + along * s - Vector((0.0, drop, 0.0)))
            rope.tube(path, cfg["ROPE_RADIUS"], sides=8, caps=True)


def build_apron(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The frame the skirt hangs from: a lip under the mat edge and a hem.

    Everything here is dark on purpose. A bright surface hung in this strip
    lit the one part of the wide frame that was still pure black and took
    `void_fraction` from 0.023 to 0.002, outside VISUAL_BAR.md's 0.010-0.066
    floor. A real arena is dark under the ring apron, and the ring reference
    agrees -- the comfortable case where both constraints point one way.
    """
    rail = parts["ApronRail"]
    for out in (Vector((0.0, 0.0, 1.0)), Vector((0.0, 0.0, -1.0)),
                Vector((1.0, 0.0, 0.0)), Vector((-1.0, 0.0, 0.0))):
        tangent = Vector((out.z, 0.0, -out.x))
        mid = out * cfg["APRON_OUT"]
        # The TOP lip is gone. It was a dark box 0.17 deep centred on the skirt
        # plane, which put its outer face at 3.285 -- further out than the roll
        # (3.20) and the skirt (3.20) both -- so once ring_builder.gd grew a
        # padded apron roll, this drew IN FRONT of it as a black bar running
        # the whole way round the ring, directly under the blue.
        #
        # Nothing replaces it, because the roll is the apron edge now and does
        # the job this was standing in for. Its other purpose, keeping this
        # strip dark for VISUAL_BAR.md's void_fraction floor, is unaffected in
        # the direction that matters: removing a lit surface can only let more
        # dark through, and the floor is a MINIMUM.
        rail.oriented_box(mid + Vector((0.0, cfg["APRON_BOTTOM"] + 0.03, 0.0)),
                          tangent, out, Vector((6.58, 0.07, 0.13)))


## The two corners the flights stand on (ring_builder.gd STEP_CORNERS): the
## hard camera's top-left and bottom-right.
STEP_CORNERS = ((1.0, -1.0), (-1.0, 1.0))
## The raised nosing along each tread's front edge.
STEP_NOSE = 0.018
## The flank's horizontal seam (one per side, where the casting's two
## halves meet in the owner's reference), and the two hand slots below it.
STEP_SEAM_HEIGHT = 0.012
STEP_SLOT = (0.16, 0.045)
STEP_TREAD_PLATE = 0.006


def _solid(part: Part, footprint: list[Vector], base_y: float, top_y: float,
           bevel: float = 0.0) -> None:
    """A closed prism over a (possibly concave) floor polygon, optionally
    bevelled through the part's own `_beveled`."""
    n = len(footprint)
    corners = [Vector((p.x, base_y, p.z)) for p in footprint] + \
        [Vector((p.x, top_y, p.z)) for p in footprint]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    if bevel > 0.0:
        part._beveled(corners, faces, bevel, 1)
        return
    v = [part.vert(c) for c in corners]
    for face in faces:
        try:
            part.bm.faces.new([v[i] for i in face])
        except ValueError:
            pass


def step_footprint(cfg: dict[str, float], cx: float, cz: float, front: float,
                   inset: float = 0.0) -> list[Vector]:
    """One tier's floor plan: from the V cut against the apron corner out to
    `front` (metres along the diagonal from the apron's corner).

    The owner's reference (and every televised ring): the top of the flight
    is cut at an angle on both sides so it fits snugly into the corner, the
    ring post standing in the notch. In the flight's frame -- `o` out along
    the diagonal from the apron corner, `a` across it -- the apron's two
    sides are the lines o = -|a|; the cut runs STEP_APRON_GAP off each of
    them, at o = -|a| + gap * sqrt(2). So each tier is a pentagon: the two
    front corners, the two back corners where the cut meets the flanks, and
    the notch's apex on the diagonal."""
    out = Vector((cx, 0.0, cz)).normalized()
    across = Vector((-cz, 0.0, cx)).normalized()
    corner = Vector((cx * cfg["APRON_OUT"], 0.0, cz * cfg["APRON_OUT"]))
    # `inset` pulls every edge in by that much, square to itself (the tread
    # plates sit inside the bevelled arrises).
    half = cfg["STEP_WIDTH"] * 0.5 - inset
    apex = (cfg["STEP_APRON_GAP"] + inset) * math.sqrt(2.0)
    front -= inset

    def at(o: float, a: float) -> Vector:
        return corner + out * o + across * a

    return [at(front, -half), at(front, half), at(-half + apex, half),
            at(apex, 0.0), at(-half + apex, -half)]


def build_steps(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Two flights of steel steps on the corner diagonals, cut to fit the
    corner (see ring_builder.gd "Steel steps" for the why).

    Four tiers, each a solid from the floor to its own top over the same
    V-cut footprint (step_footprint), stepping out from the ring by STEP_RUN
    per tier below the top, so they stack into one stepped casting whose
    back wraps the apron's corner with the post in the notch. On each:

    * a raised nose along the tread's front edge (StepsMesh);
    * a separate tread plate on top, darker and rough (StepTreads) -- the
      reference's walking surfaces read a shade under the cast sides;
    * on both flanks, a dark seam at mid-height and two hand slots
      (StepsTrim), which is what reads as a casting rather than a box.
    """
    steps = parts["StepsMesh"]
    treads_part = parts["StepTreads"]
    trim = parts["StepsTrim"]
    treads = int(cfg["STEP_TREADS"])
    floor_y = cfg["STEP_FLOOR_Y"]
    rise = (cfg["STEP_TOP_Y"] - floor_y) / treads
    run = cfg["STEP_RUN"]
    width = cfg["STEP_WIDTH"]
    half = width * 0.5
    apex = cfg["STEP_APRON_GAP"] * math.sqrt(2.0)
    top_front = apex + cfg["STEP_PLATFORM"]
    for cx, cz in STEP_CORNERS:
        out = Vector((cx, 0.0, cz)).normalized()
        across = Vector((-cz, 0.0, cx)).normalized()
        corner = Vector((cx * cfg["APRON_OUT"], 0.0, cz * cfg["APRON_OUT"]))
        for i in range(treads):
            top = floor_y + rise * (i + 1)
            front = top_front + run * (treads - 1 - i)
            _solid(steps, step_footprint(cfg, cx, cz, front), floor_y, top,
                   bevel=STEP_BEVEL)
            # The tread plate: the part of this tier's top the tier above
            # does not cover -- the whole platform for the top one.
            back = -half + apex if i == treads - 1 else front - run
            inset = 0.025
            if i == treads - 1:
                plate = step_footprint(cfg, cx, cz, front, inset=inset)
            else:
                plate = [corner + out * (front - inset) + across * (-half + inset),
                         corner + out * (front - inset) + across * (half - inset),
                         corner + out * (back + 0.005) + across * (half - inset),
                         corner + out * (back + 0.005) + across * (-half + inset)]
            _solid(treads_part, plate, top - 0.001, top + STEP_TREAD_PLATE)
            nose = corner + out * (front - 0.02) + Vector((0.0, top + STEP_NOSE * 0.5, 0.0))
            steps.oriented_box(nose, across, out, Vector((width - 0.01, STEP_NOSE, 0.04)),
                               bevel=0.006)
        # The flanks: a dark seam running the full stepped length at half the
        # flight's height, and two hand slots on the tall back half.
        seam_y = floor_y + (cfg["STEP_TOP_Y"] - floor_y) * 0.42
        flank_back = -half + apex
        bottom_front = top_front + run * (treads - 1)
        for side in (-1.0, 1.0):
            face = across * side * (half + 0.0015)
            # Only as far out as the tiers that reach the seam's height.
            reach = top_front + run * (treads - 1 - int((seam_y - floor_y) / rise))
            centre = corner + face + out * ((flank_back + min(reach, bottom_front)) * 0.5) \
                + Vector((0.0, seam_y, 0.0))
            trim.oriented_box(centre, out, across * side,
                              Vector((min(reach, bottom_front) - flank_back - 0.03,
                                      STEP_SEAM_HEIGHT, 0.003)))
            for k, o in enumerate((flank_back + 0.24, flank_back + 0.24 + STEP_SLOT[0] + 0.14)):
                slot = corner + face + out * o + Vector((0.0, seam_y + 0.16, 0.0))
                trim.oriented_box(slot, out, across * side,
                                  Vector((STEP_SLOT[0], STEP_SLOT[1], 0.003)), bevel=0.001)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(venue.ASSET_DIR / "ring.glb"))
    args = parser.parse_args(argv)

    cfg = venue.read_constants(venue.RING_GD, WANTED)
    venue.reset_scene()
    parts = {name: Part(name) for name in PART_COLORS}
    build_posts(cfg, parts)
    build_terminations(cfg, parts)
    build_turnbuckle_pads(cfg, parts)
    build_turnbuckles(cfg, parts)
    build_pad_faces(cfg, parts)
    build_ropes(cfg, parts)
    build_apron(cfg, parts)
    build_steps(cfg, parts)
    # TurnbuckleFaces is excluded from the planar projection. Everything else
    # here is boxes and tubes wearing tiled library surfaces, for which a
    # world-metre projection is right; the pad faces carry ONE logo placed by
    # hand, and cube_project would overwrite the UVs that put it there.
    venue.finish(parts, PART_COLORS, smooth=SMOOTH,
                 projected=frozenset(PART_COLORS) - SMOOTH - UNPROJECTED,
                 keep_winding=UNPROJECTED)

    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("ring: %d triangles, %s" % (venue.triangle_count(), out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
