#!/usr/bin/env python3
"""Put people in the seats: the bowl's crowd, and the ringside fans' meshes.

Imported by `arena_bowl.py` (the bowl, baked into the hall's own mesh) and by
`floor_crowd.py` (the ringside chairs, instanced in Godot). It has no `main`
of its own; `tools/blender/build_arena.sh` builds both.

The people are real
-------------------
They used to be modelled here: nine rounded boxes in the shape of somebody
sitting down, with a cut of hair and a rolled posture. At the distance the
broadcast camera sits that read as a crowd of mannequins -- the 2K26 match
the owner measures against (`gauntlet/refs/cody_roman_2k26.md`) shows
"distinct people: faces, varied clothes, phones, signs", and no amount of
box variance gets there.

So every figure is now one of twenty Microsoft Rocketbox avatars (MIT;
`game/assets/environment/CREDITS.md`), posed from frames of Rocketbox's own
motion capture -- sitting, clapping, arms up, taking a picture, holding a
sign, on their feet -- with its textures baked into vertex colour and its
mesh decimated to what a crowd of six thousand can afford. All of that is
`rocketbox_crowd.py`; this file decides who sits where and what they wear.

What they wear
--------------
A wrestling crowd is mostly black tees, some merch colours, a lot of them
with a print on the chest. The avatars arrive in their own clothes (a pink
blouse, a red hoodie), so each figure's upper garment -- found from its skin
weights and kept as a mask with its own fold shading -- is re-dressed from
SHIRT_COLORS below, and about half of the dark ones get a lighter print
patch on the chest. One in twenty keeps the clothes the avatar came in, which
is where the odd hoodie and blouse in the stands come from.

Animation
---------
Unchanged, and still a vertex shader (`arena_builder.gd`, `_crowd_material`)
because ARCHITECTURE.md's cosmetic-motion rule was written for exactly this:
thousands of skinned spectators is not a thing that runs, and baked geometry
with a shader cannot touch gameplay state. Each figure carries its phase in
UV.x and its role (sit, clap, wave, jump) in UV.y; colour is COLOR_0.
"""

from __future__ import annotations

import math
import random

import numpy as np
from mathutils import Vector

import crowd_signs
import rocketbox_crowd as rb

# --- Palette ----------------------------------------------------------------
# The tees, in linear light. Sized against a measurement rather than chosen:
# the reference frames' crowd sits at relative luminance 0.014
# (VISUAL_BAR.md), so a bright crowd is not closer to the reference, it is
# further from it. Black and charcoal are most of a wrestling crowd -- in the
# 2K26 match frames almost all of it, with prints, and only a few white,
# grey, red and navy tees; the gold and green merch colours the first pass
# carried made the stands read yellow. Repeated entries are weights
# (rng.choice picks uniformly). `arena_builder.gd`'s CROWD_SHIRTS is this
# list in sRGB and must stay in step.
SHIRT_COLORS = [
    (0.012, 0.012, 0.014), (0.012, 0.012, 0.014), (0.012, 0.012, 0.014),
    (0.012, 0.012, 0.014), (0.012, 0.012, 0.014), (0.012, 0.012, 0.014),
    (0.016, 0.016, 0.018), (0.016, 0.016, 0.018), (0.016, 0.016, 0.018),
    (0.016, 0.016, 0.018), (0.016, 0.016, 0.018),
    (0.022, 0.022, 0.024), (0.022, 0.022, 0.024), (0.022, 0.022, 0.024),
    (0.022, 0.022, 0.024),
    (0.030, 0.030, 0.033), (0.030, 0.030, 0.033),
    (0.040, 0.040, 0.044), (0.040, 0.041, 0.045), (0.06, 0.06, 0.065),
    # Navy.
    (0.014, 0.020, 0.050), (0.020, 0.030, 0.065),
    # White and grey.
    (0.30, 0.30, 0.29), (0.16, 0.16, 0.16),
    # Red merch.
    (0.20, 0.014, 0.012), (0.12, 0.010, 0.012),
]
## The print on a tee's chest: mostly white and grey ink, some colour.
PRINT_COLORS = [
    (0.42, 0.42, 0.40), (0.42, 0.42, 0.40), (0.26, 0.26, 0.26),
    (0.55, 0.52, 0.45), (0.34, 0.05, 0.03), (0.30, 0.20, 0.04),
    (0.08, 0.14, 0.34),
]
## A tee darker than this can carry a print.
PRINT_UNDER = 0.07
## Of the dark tees, how many have one.
PRINT_FRACTION = 0.6
## How many keep the clothes their avatar came in.
OWN_CLOTHES_FRACTION = 0.05

## Fraction of seats occupied. 0.86 is the figure the removed crowd used.
CROWD_FILL = 0.86
## Of those, the fraction on their feet. People stand up at a wrestling
## show, and a row where every head is at exactly one height is the single
## most obviously generated thing a stadium crowd can do.
STANDING_FRACTION = 0.07
## Seed. Fixed so the same build produces the same arena every run --
## ARCHITECTURE.md's determinism contract applies to the committed .glb as
## much as to gameplay: a capture is only comparable between rounds if the
## hall is identical.
CROWD_SEED = 20260914

## How many rows from the front of the lower tier are the `Crowd` part (the
## `near` level of detail, rocketbox_crowd.LODS); everyone else is
## `CrowdFar` -- `mid` for the rest of the lower tier, `far` upstairs.
## Four rows is what the broadcast camera actually gets close to: ART_SHOTS'
## nearest bowl framing is `crowd_bank`.
DETAILED_ROWS = 4

## What a figure is doing, in UV.y, for the crowd shader: sitting, clapping,
## arms up and waving, on their feet and jumping.
ROLE_SIT, ROLE_CLAP, ROLE_WAVE, ROLE_JUMP = (rb.ROLE_SIT, rb.ROLE_CLAP,
                                             rb.ROLE_WAVE, rb.ROLE_JUMP)

## Seated poses and their weights. Most people sit; some clap, some have
## their arms up, some film it, a few hold a sign.
SEATED_POSES = (("sit_a", 24), ("sit_b", 20), ("sit_c", 20), ("sit_clap", 16),
                ("sit_cheer", 5), ("sit_phone", 6), ("sit_sign", 1.2))
STANDING_POSES = (("stand", 4), ("stand_clap", 3), ("stand_cheer", 2),
                  ("stand_phone", 2), ("stand_sign", 0.6))
## Sign boards, linear: white card, yellow, red, grey.
## In the first DETAILED_ROWS the sign weight is this much higher: the near
## rows are where 2K26's signs are, and the ones a camera can read.
NEAR_SIGN_BOOST = 4.0

## The rows behind are baked darker. 2K26's match frames: "front rows are
## warm-lit, readable faces; the rows behind fade darker", and "the far bowl
## is a dark field" (cody_roman_2k26.md). The first DETAILED_ROWS keep full
## level, the rest of the lower tier fades to BACK_ROW_LEVEL, and the upper
## tier sits at UPPER_TIER_LEVEL. This shapes the stand front-to-back; the
## frame's overall level on the hard camera is held by its exposure, not by
## these numbers.
BACK_ROW_LEVEL = 0.65
UPPER_TIER_LEVEL = 0.6


def row_level(row: dict, lower_rows: int) -> float:
    if row["tier"] == 1:
        return UPPER_TIER_LEVEL
    if row["index"] < DETAILED_ROWS:
        return 1.0
    t = (row["index"] - DETAILED_ROWS + 1) / max(lower_rows - DETAILED_ROWS, 1)
    return 1.0 + (BACK_ROW_LEVEL - 1.0) * min(t, 1.0)


## Where in a row's depth (0 front edge, 1 back) a person stands or sits.
## The seat box is at 0.62 of the depth; a seated figure's origin is under
## its hip joint, just forward of the seat's middle.
SEATED_DEPTH = 0.58
STANDING_DEPTH = 0.36


def _shade(rng: random.Random, base) -> tuple:
    """A colour, jittered. Two people in the same shirt are still not the same
    colour under the same light, and without this the palette reads as
    fourteen uniforms rather than as a crowd."""
    k = rng.uniform(0.82, 1.18)
    return (base[0] * k, base[1] * k, base[2] * k)


def _weighted(rng: random.Random, table) -> str:
    total = sum(w for _, w in table)
    roll = rng.uniform(0.0, total)
    for name, weight in table:
        roll -= weight
        if roll <= 0.0:
            return name
    return table[-1][0]


class ArrayPart:
    """A crowd object assembled from whole figures as arrays, in the GAME's
    frame (+Y up), and written to a Blender mesh in one go.

    The hall's other parts are bmesh solids built a face at a time
    (`arena_bowl.Part`); six thousand people of a few hundred triangles each
    are a million triangles, which is numpy's job, not bmesh's."""

    def __init__(self, name: str, uv_name: str = "Phase") -> None:
        self.name = name
        self.uv_name = uv_name
        self._co: list = []
        self._tris: list = []
        self._colour: list = []
        self._uv: list = []
        self._uv2: list = []
        self._count = 0

    def add(self, co: np.ndarray, tris: np.ndarray, colour: np.ndarray,
            uv: np.ndarray, uv2: np.ndarray | None = None) -> None:
        self._co.append(co)
        self._tris.append(tris + self._count)
        self._colour.append(colour)
        self._uv.append(uv)
        if uv2 is not None:
            self._uv2.append(uv2)
        self._count += len(co)

    def write(self, mesh) -> None:
        """Fill `mesh`: positions converted Godot -> Blender the way
        `arena_bowl.to_blender` does, colour as a point attribute "Col",
        the first UV layer (`uv_name`: the crowd's (phase, role), a sign's
        atlas UV) and, when given, a second layer "Arm" -- (arm membership,
        side), which glTF carries as TEXCOORD_1 and Godot as UV2."""
        co = np.concatenate(self._co) if self._co else np.zeros((0, 3))
        tris = np.concatenate(self._tris) if self._tris else np.zeros((0, 3), int)
        colour = np.concatenate(self._colour) if self._colour else np.zeros((0, 3))
        uv = np.concatenate(self._uv) if self._uv else np.zeros((0, 2))
        blender = np.stack([co[:, 0], -co[:, 2], co[:, 1]], axis=1)
        mesh.vertices.add(len(blender))
        mesh.vertices.foreach_set("co", blender.astype(np.float32).ravel())
        mesh.loops.add(tris.size)
        mesh.loops.foreach_set("vertex_index", tris.astype(np.int32).ravel())
        mesh.polygons.add(len(tris))
        mesh.polygons.foreach_set("loop_start",
                                  (np.arange(len(tris)) * 3).astype(np.int32))
        mesh.polygons.foreach_set("loop_total", np.full(len(tris), 3, np.int32))
        mesh.polygons.foreach_set("use_smooth", np.ones(len(tris), bool))
        mesh.update(calc_edges=True)
        attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        rgba = np.concatenate([colour, np.ones((len(colour), 1))], axis=1)
        attr.data.foreach_set("color", rgba.astype(np.float32).ravel())
        mesh.color_attributes.active_color = attr
        layer = mesh.uv_layers.new(name=self.uv_name)
        layer.data.foreach_set("uv", uv[tris.ravel()].astype(np.float32).ravel())
        if self._uv2:
            uv2 = np.concatenate(self._uv2)
            arm = mesh.uv_layers.new(name="Arm")
            arm.data.foreach_set("uv", uv2[tris.ravel()].astype(np.float32).ravel())
        mesh.uv_layers.active_index = 0
        mesh.validate()

    def triangle_count(self) -> int:
        return sum(len(t) for t in self._tris)


def _dress(fig: dict, rng: random.Random) -> np.ndarray:
    """The figure's vertex colours, in whatever this person is wearing."""
    colour = fig["colour"].copy()
    shirt, fold, chest = fig["shirt"], fig["fold"][:, None], fig["chest"]
    if rng.random() >= OWN_CLOTHES_FRACTION:
        tee = np.array(_shade(rng, rng.choice(SHIRT_COLORS)))
        colour[shirt] = tee * fold[shirt]
        lum = 0.2126 * tee[0] + 0.7152 * tee[1] + 0.0722 * tee[2]
        if lum < PRINT_UNDER and rng.random() < PRINT_FRACTION:
            ink = np.array(_shade(rng, rng.choice(PRINT_COLORS)))
            colour[chest] = ink * fold[chest]
    return colour


def arm_uv(fig: dict) -> np.ndarray:
    """UV2 for a figure: (arm membership, side), side 1 on the figure's +X."""
    return np.stack([fig["arm"], fig["side"]], axis=1)


def sign_board(centre: np.ndarray, width: float, cell: int):
    """A sign board in the figure's frame (facing +Z): its front and its back
    as two quads, the front carrying atlas cell `cell` and the back the same
    cell mirrored (nobody reads the back). Returns (co, tris, uv)."""
    hw, hh, t = width * 0.5, width * 0.25, 0.006
    u0, v0, u1, v1 = crowd_signs.cell_uv(cell)
    co, uv = [], []
    for z, flip in ((t, False), (-t, True)):
        for x, y in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)):
            co.append(centre + np.array([x, y, z]))
            u = (u0 if x < 0 else u1) if not flip else (u1 if x < 0 else u0)
            uv.append((u, v0 if y < 0 else v1))
    tris = np.array([(0, 1, 2), (0, 2, 3), (4, 6, 5), (4, 7, 6)])
    return np.array(co), tris, np.array(uv)


def _place(fig, at: Vector, along: Vector, face: Vector,
           scale: float) -> np.ndarray:
    """A figure built facing +Z at the origin, put at `at` facing `face`."""
    up = np.array([0.0, 1.0, 0.0])
    f = np.array([face.x, 0.0, face.z])
    f /= max(np.linalg.norm(f), 1e-9)
    x = np.cross(up, f)
    basis = np.stack([x, up, f], axis=1) * scale
    co = fig["co"] if isinstance(fig, dict) else fig
    return co @ basis.T + np.array([at.x, at.y, at.z])


def build_crowd(cfg, parts, rows, plan_loop, aisle_indices, stage_gap) -> dict:
    """Fill the bowl. Returns a count per part, for the build's own report.

    Walks each seated row exactly as `build_seat_row` does -- same curve, same
    pitch, same aisle and stage-gap exclusions -- so a person lands on a seat
    rather than near one.

    `parts` must map "Crowd", "CrowdFar" and "CrowdSigns" to `ArrayPart`s.
    The signs are a part of their own because they carry a picture (a cell
    of `crowd_signs.png`) in their UVs; they ride their holder's phase and
    role in COLOR (r, g) so the shader moves them with the holder's hands,
    and COLOR.b carries the row's level.
    """
    lib = rb.library()
    rng = random.Random(CROWD_SEED)
    pitch = cfg["SEAT_PITCH"]
    clearance = cfg["AISLE_CLEARANCE"]
    built = {"Crowd": 0, "CrowdFar": 0, "standing": 0, "signs": 0, "phones": 0}

    for row in rows:
        if row["kind"] != "seated":
            continue
        detailed = row["tier"] == 0 and row["index"] < DETAILED_ROWS
        lod = "near" if detailed else ("mid" if row["tier"] == 0 else "far")
        part = parts["Crowd" if detailed else "CrowdFar"]
        level = row_level(row, int(cfg["LOWER_ROWS"]))
        seated_poses = tuple((n, w * (NEAR_SIGN_BOOST if detailed and n.endswith("sign") else 1.0))
                             for n, w in SEATED_POSES)
        depth = row["outer"] - row["inner"]
        loop = plan_loop(cfg, row["inner"] + depth * SEATED_DEPTH)
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

                standing = rng.random() < STANDING_FRACTION
                pose = _weighted(rng, STANDING_POSES if standing else seated_poses)
                avatar = rng.choice(rb.AVATARS)
                fig = lib[(avatar, pose, lod)]
                # Golden-ratio phase, the spread the old shader used: adjacent
                # seats never move together and the pattern never repeats
                # along a row.
                phase = ((built["Crowd"] + built["CrowdFar"]) * 0.6180339887) % 1.0
                # Not every head points at the ring's centre: +-20 degrees.
                yaw = math.radians(rng.uniform(-20.0, 20.0))
                face = -normal.normalized()
                c, s = math.cos(yaw), math.sin(yaw)
                face = Vector((face.x * c - face.z * s, 0.0, face.x * s + face.z * c))
                scale = rng.uniform(0.92, 1.06)
                spot = Vector((point.x, row["tread_y"], point.z))
                if standing:
                    spot += normal.normalized() * (depth * (STANDING_DEPTH - SEATED_DEPTH))
                colour = _dress(fig, rng)
                colour = colour * level
                co = _place(fig, spot, along, face, scale)
                uv = np.tile([phase, fig["role"]], (len(co), 1))
                part.add(co, fig["tris"], colour, uv, arm_uv(fig))
                if "sign" in fig:
                    centre, width = fig["sign"]
                    bco, btris, buv = sign_board(centre, width,
                                                 rng.randrange(crowd_signs.COUNT))
                    parts["CrowdSigns"].add(
                        _place(bco, spot, along, face, scale), btris,
                        np.tile([phase, fig["role"], level], (len(bco), 1)), buv)
                built["Crowd" if detailed else "CrowdFar"] += 1
                built["standing"] += int(standing)
                built["signs"] += int(pose.endswith("sign"))
                built["phones"] += int(pose.endswith("phone"))
            carry = span - (at - pitch)
    return built


# --- Ringside fans, for instancing -----------------------------------------
#
# The bowl's crowd is baked into the hall's own mesh because it sits on twenty
# different rows of a curve. The ringside floor is the opposite case:
# `arena_builder.gd` already computes a transform per folding chair, so those
# figures are INSTANCED, and an instance needs one mesh. So the variety is a
# set of distinct people, each built at the origin facing +Z -- the frame the
# chair prop is modelled in -- with shirt, size and yaw varying per instance
# in Godot on top.
#
# These are the closest crowd to any camera in the game, so they get the
# `floor` level of detail (hair cards and all) and keep their real colours.
# What varies per instance is the upper garment, and the mesh says which
# vertices those are:
#
#   COLOR   the baked colour; on garment vertices, the garment's FOLD
#           SHADING as a grey at half scale (the instance supplies the hue)
#   UV.x    0 own colour, 0.5 garment, 1.0 the chest print area
#   UV.y    the role, as in the bowl
#
# `arena_builder.gd`'s floor-fan shader branch is the other half of this.

## (avatar, pose) for each ringside mesh: every avatar once, seated, in a
## spread of poses, then STANDING_VARIANTS on their feet.
FLOOR_SEATED = (
    ("Male_Adult_01", "sit_a"), ("Male_Adult_04", "sit_clap"),
    ("Male_Adult_06", "sit_b"), ("Male_Adult_07", "sit_c"),
    ("Male_Adult_09", "sit_phone"), ("Male_Adult_10", "sit_a"),
    ("Male_Adult_11", "sit_cheer"), ("Male_Adult_12", "sit_b"),
    ("Male_Adult_14", "sit_clap"), ("Male_Adult_16", "sit_c"),
    ("Male_Adult_17", "sit_a"), ("Male_Adult_18", "sit_b"),
    ("Male_Adult_20", "sit_clap"), ("Female_Adult_03", "sit_a"),
    ("Female_Adult_07", "sit_phone"), ("Female_Adult_08", "sit_c"),
    ("Female_Adult_12", "sit_clap"), ("Female_Adult_13", "sit_b"),
    ("Female_Adult_17", "sit_cheer"), ("Female_Party_02", "sit_a"),
)
FLOOR_STANDING = (
    ("Male_Adult_09", "stand_cheer"), ("Male_Adult_17", "stand_clap"),
    ("Male_Adult_04", "stand"), ("Female_Adult_12", "stand_phone"),
)
FLOOR_VARIANTS = len(FLOOR_SEATED) + len(FLOOR_STANDING)
## The last STANDING_VARIANTS meshes are on their feet in front of the chair
## (`arena_builder.gd`'s FLOOR_STANDING_VARIANTS must match).
STANDING_VARIANTS = len(FLOOR_STANDING)
## Height of a folding chair's seat pan. The seated poses put the hip joint
## ~0.6 m over the feet, so a figure whose feet are on the floor sits on a
## pan this high without any lift of its own.
CHAIR_SEAT_HEIGHT = 0.45


## The two sets of ringside meshes: (name prefix, level of detail). The
## front FLOOR_CHAIR_DETAIL_ROWS rows (arena_builder.gd) get `Fan##`; the
## floor further back, which no camera is near, gets the bowl's `mid`
## figures as `FanFar##`. Same people, same order, same contract.
FLOOR_SETS = (("Fan", "floor"), ("FanFar", "mid"))


def build_floor_variants(make_part) -> list:
    """Build the ringside meshes, each into its own part from
    `make_part(name)` (which must return an `ArrayPart`). Returns the names
    in order."""
    lib = rb.library()
    names = []
    for prefix, lod in FLOOR_SETS:
        names += _floor_set(lib, make_part, prefix, lod)
    return names


def _floor_set(lib, make_part, prefix: str, lod: str) -> list:
    names = []
    for index, (avatar, pose) in enumerate(FLOOR_SEATED + FLOOR_STANDING):
        name = "%s%02d" % (prefix, index)
        part = make_part(name)
        fig = lib[(avatar, pose, lod)]
        colour = fig["colour"].copy()
        mask = np.zeros(len(colour))
        garment = fig["shirt"]
        colour[garment] = (fig["fold"][garment] * 0.5)[:, None]
        mask[garment] = 0.5
        mask[garment & fig["chest"]] = 1.0
        uv = np.stack([mask, np.full(len(colour), fig["role"])], axis=1)
        part.add(fig["co"], fig["tris"], colour, uv, arm_uv(fig))
        names.append(name)
    return names


# --- Packing the exported file ---------------------------------------------

_COMPONENTS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16,
               5125: np.uint32, 5126: np.float32}
_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
## The most vertices a primitive may have and still index them in 16 bits.
CHUNK_VERTICES = 65535


def optimise_glb(glb_path, crowd_meshes, flat_meshes) -> None:
    """Rewrite the named meshes of an exported .glb, in place, smaller.

    Blender's exporter writes every attribute as 32-bit floats and the crowd's
    indices as 32-bit, and at 1.5 million triangles that is a file nobody
    can commit. Everything done here is core glTF 2.0 (no extension), and
    Godot's importer reads all of it:

    * COLOR_0 as normalized unsigned bytes. Godot keeps vertex colour in
      eight bits per channel whatever the file says, so this loses nothing.
    * For `crowd_meshes`, TEXCOORD_0 (phase, role) and TEXCOORD_1 (arm, side)
      as normalized unsigned shorts. The phase needs the 16 bits: CrowdFlashes
      tells one person from the next by it. `flat_meshes` (the sign boards)
      keep float UVs, which are atlas coordinates.
    * Meshes split into primitives of at most CHUNK_VERTICES vertices, each
      indexed in 16 bits -- six bytes a triangle, a quarter of the crowd's
      file. Godot imports each primitive as a surface of the same mesh, under
      the same material override; whole figures are contiguous in the
      vertex buffer, so a chunk boundary never splits a person.

    Deterministic: the output depends only on the input bytes."""
    import json
    import pathlib
    import struct
    path = pathlib.Path(glb_path)
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    bin_len = struct.unpack_from("<I", data, 20 + json_len)[0]
    blob = data[20 + json_len + 8:20 + json_len + 8 + bin_len]
    views = doc["bufferViews"]
    accessors = doc["accessors"]
    chunks: list = [None] * len(views)   # replacement bytes per view

    def view_bytes(index: int) -> bytes:
        if chunks[index] is not None:
            return chunks[index]
        v = views[index]
        start = v.get("byteOffset", 0)
        return blob[start:start + v["byteLength"]]

    def read(index: int) -> np.ndarray:
        acc = accessors[index]
        if "byteStride" in views[acc["bufferView"]]:
            raise SystemExit("optimise_glb: interleaved views are not handled")
        width = _WIDTH[acc["type"]]
        raw = view_bytes(acc["bufferView"])
        arr = np.frombuffer(raw, _COMPONENTS[acc["componentType"]],
                            acc["count"] * width, acc.get("byteOffset", 0))
        return arr.reshape(acc["count"], width)

    def add(array: np.ndarray, component: int, kind: str, normalized=False,
            target=None, bounds=False) -> int:
        views.append({"buffer": 0, "byteLength": array.nbytes})
        chunks.append(array.tobytes())
        if target:
            views[-1]["target"] = target
        acc = {"bufferView": len(views) - 1, "componentType": component,
               "count": int(array.shape[0]), "type": kind}
        if normalized:
            acc["normalized"] = True
        if bounds:
            acc["min"] = [float(v) for v in array.min(axis=0)]
            acc["max"] = [float(v) for v in array.max(axis=0)]
        accessors.append(acc)
        return len(accessors) - 1

    def unorm(values: np.ndarray, dtype) -> np.ndarray:
        top = float(np.iinfo(dtype).max)
        return np.round(np.clip(values, 0.0, 1.0) * top).astype(dtype)

    for mesh in doc["meshes"]:
        name = mesh["name"]
        if name not in crowd_meshes and name not in flat_meshes:
            continue
        out_prims = []
        for prim in mesh["primitives"]:
            arrays = {key: read(index) for key, index in prim["attributes"].items()}
            if "COLOR_0" in arrays:
                c = arrays["COLOR_0"].astype(np.float32)
                if c.shape[1] == 3:
                    c = np.concatenate([c, np.ones((len(c), 1), np.float32)], axis=1)
                arrays["COLOR_0"] = unorm(c, np.uint8)
            for key in ("TEXCOORD_0", "TEXCOORD_1"):
                if key in arrays and name in crowd_meshes:
                    arrays[key] = unorm(arrays[key].astype(np.float32), np.uint16)
            tris = read(prim["indices"]).reshape(-1, 3).astype(np.int64)
            lo = tris.min(axis=1)
            hi = tris.max(axis=1)
            start = 0
            while start < len(tris):
                vmin, vmax = int(lo[start]), int(hi[start])
                end = start + 1
                while end < len(tris):
                    nmin = min(vmin, int(lo[end]))
                    nmax = max(vmax, int(hi[end]))
                    if nmax - nmin + 1 > CHUNK_VERTICES:
                        break
                    vmin, vmax = nmin, nmax
                    end += 1
                attrs = {}
                for key, arr in arrays.items():
                    part = np.ascontiguousarray(arr[vmin:vmax + 1])
                    component = {np.dtype(np.float32): 5126, np.dtype(np.uint8): 5121,
                                 np.dtype(np.uint16): 5123}[part.dtype]
                    kind = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}[part.shape[1]]
                    attrs[key] = add(part, component, kind,
                                     normalized=component != 5126, target=34962,
                                     bounds=key == "POSITION")
                index = add((tris[start:end] - vmin).astype(np.uint16).reshape(-1, 1),
                            5123, "SCALAR", target=34963)
                new = {k: v for k, v in prim.items() if k not in ("attributes", "indices")}
                new["attributes"] = attrs
                new["indices"] = index
                out_prims.append(new)
                start = end
        mesh["primitives"] = out_prims

    # Keep only what is still referenced, in a stable order, and re-pack.
    if doc.get("skins") or doc.get("animations"):
        raise SystemExit("optimise_glb: skins and animations are not handled")
    used_acc = sorted({i for m in doc["meshes"] for p in m["primitives"]
                       for i in list(p["attributes"].values()) + [p["indices"]]})
    acc_map = {old: new for new, old in enumerate(used_acc)}
    used_views = sorted({accessors[i]["bufferView"] for i in used_acc}
                        | {img["bufferView"] for img in doc.get("images", [])
                           if "bufferView" in img})
    view_map = {old: new for new, old in enumerate(used_views)}
    out = bytearray()
    new_views = []
    for old in used_views:
        chunk = view_bytes(old)
        while len(out) % 4:
            out.append(0)
        v = dict(views[old])
        v["byteOffset"] = len(out)
        v["byteLength"] = len(chunk)
        new_views.append(v)
        out += chunk
    while len(out) % 4:
        out.append(0)
    new_acc = []
    for old in used_acc:
        acc = dict(accessors[old])
        acc["bufferView"] = view_map[acc["bufferView"]]
        new_acc.append(acc)
    for m in doc["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
            p["indices"] = acc_map[p["indices"]]
    for img in doc.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = view_map[img["bufferView"]]
    doc["accessors"] = new_acc
    doc["bufferViews"] = new_views
    doc["buffers"][0]["byteLength"] = len(out)
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(out)
    path.write_bytes(b"".join([
        struct.pack("<4sII", b"glTF", 2, total),
        struct.pack("<I4s", len(text), b"JSON"), text,
        struct.pack("<I4s", len(out), b"BIN\x00"), bytes(out),
    ]))
