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
    "ROPE_SPAN", "ROPE_RADIUS", "ROPE_SEGMENTS", "ROPE_OVERRUN",
    "ROPE_HEIGHT_BOTTOM", "ROPE_HEIGHT_MIDDLE", "ROPE_HEIGHT_TOP",
    "ROPE_SAG_BOTTOM", "ROPE_SAG_MIDDLE", "ROPE_SAG_TOP",
    "POST_XZ", "POST_SECTION", "POST_BOTTOM", "POST_TOP",
    "CLAMP_LENGTH", "CLAMP_RADIUS", "CLAMP_INSET",
    "PAD_FACE_WIDTH", "PAD_FACE_HEIGHT", "PAD_FACE_LIFT", "PAD_FACE_V_SPAN",
    "TURNBUCKLE_PAD_WIDTH", "TURNBUCKLE_PAD_HEIGHT", "TURNBUCKLE_PAD_DEPTH",
    "TURNBUCKLE_PAD_XZ", "TURNBUCKLE_PAD_BEVEL",
    "APRON_OUT", "APRON_TOP", "APRON_BOTTOM",
    "STEP_TREADS", "STEP_WIDTH", "STEP_RUN", "STEP_TOP_Y", "STEP_FLOOR_Y",
    "STEP_POST_GAP",
]

# Placeholder colours only; ring_builder.gd overrides all four by name.
PART_COLORS = {
    "PostMesh": (0.075, 0.075, 0.080, 1.0),
    "TurnbuckleFittings": (0.11, 0.11, 0.115, 1.0),
    "TurnbucklePads": (0.055, 0.055, 0.060, 1.0),
    "TurnbuckleFaces": (0.9, 0.9, 0.9, 1.0),
    "RopeMesh": (0.88, 0.88, 0.87, 1.0),
    "ApronRail": (0.105, 0.105, 0.112, 1.0),
    "StepsMesh": (0.62, 0.62, 0.63, 1.0),
}
# Ropes and sleeves are round and must read that way; the posts, rails and
# steps are faceted steel and smoothing them only muddies the arris the bevel
# was added to catch.
SMOOTH = frozenset({"RopeMesh", "TurnbuckleFittings", "TurnbucklePads"})
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
    """Four corner posts, axis-aligned, with a cap plate on top.

    The cap is new. The posts previously ended in a bare cut face at
    POST_TOP; a ring post has a plate over the tube, and a flat cut face there
    reads as unfinished. It matters more now than it did: the post stops just
    above the top turnbuckle pad rather than well clear of it, so the plate is
    the corner's top edge instead of something lost above the action.
    """
    post = parts["PostMesh"]
    section = cfg["POST_SECTION"]
    height = cfg["POST_TOP"] - cfg["POST_BOTTOM"]
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            center = Vector((cfg["POST_XZ"] * sx,
                             (cfg["POST_BOTTOM"] + cfg["POST_TOP"]) * 0.5,
                             cfg["POST_XZ"] * sz))
            post.box(center, Vector((section, height, section)),
                     bevel=POST_BEVEL, bevel_segments=2)
            post.box(
                Vector((center.x, cfg["POST_TOP"] + 0.012, center.z)),
                Vector((section * 1.22, 0.024, section * 1.22)),
                bevel=0.006,
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
    half = cfg["POST_XZ"] + cfg["ROPE_OVERRUN"]
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


def build_steps(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Two sets of steps, each at a CORNER and hard against a ring post.

    They used to sit halfway down each side, offset 0.35 m along Z for no
    reason the file gave. Steps belong at the corner: the regulation asks for
    "suitable steps for use of the contestants in their corners", and on
    television they stand tight against a post with the top tread level with
    the apron, so a wrestler climbing them steps over the top rope right
    beside the turnbuckle.

    Diagonally opposite -- +X beside the post at (+3, +3), -X beside the post
    at (-3, -3) -- so each half of the ring has a way in and neither set
    stands in the entrance walkway down the middle of -Z.

    The stringer down each flank is what makes the flight read as one object
    rather than three stacked slabs with daylight between them.
    """
    steps = parts["StepsMesh"]
    treads = int(cfg["STEP_TREADS"])
    rise = (cfg["STEP_TOP_Y"] - cfg["STEP_FLOOR_Y"]) / treads
    # Butt the near edge of the flight against the post.
    corner = cfg["POST_XZ"] - cfg["STEP_WIDTH"] * 0.5 - cfg["STEP_POST_GAP"]

    for sx, sz in ((1.0, 1.0), (-1.0, -1.0)):
        out = Vector((sx, 0.0, 0.0))
        tangent = Vector((0.0, 0.0, 1.0))
        along_z = corner * sz
        for i in range(treads):
            top = cfg["STEP_FLOOR_Y"] + rise * (i + 1)
            depth = cfg["STEP_RUN"] * (treads - i)
            center = out * (cfg["APRON_OUT"] + 0.06 + depth * 0.5) \
                + Vector((0.0, (cfg["STEP_FLOOR_Y"] + top) * 0.5, 0.0)) \
                + tangent * along_z
            steps.oriented_box(
                center, tangent, out,
                Vector((cfg["STEP_WIDTH"], top - cfg["STEP_FLOOR_Y"], depth)),
            )
        for side in (-1.0, 1.0):
            z = along_z + side * (cfg["STEP_WIDTH"] * 0.5 + 0.012)
            for i in range(treads):
                top = cfg["STEP_FLOOR_Y"] + rise * (i + 1)
                depth = cfg["STEP_RUN"] * (treads - i)
                center = out * (cfg["APRON_OUT"] + 0.06 + depth * 0.5) \
                    + Vector((0.0, (cfg["STEP_FLOOR_Y"] + top) * 0.5, 0.0)) \
                    + Vector((0.0, 0.0, z))
                steps.oriented_box(
                    center, Vector((0.0, 0.0, 1.0)), out,
                    Vector((0.024, top - cfg["STEP_FLOOR_Y"], depth)),
                )


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
