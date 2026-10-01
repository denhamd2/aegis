#!/usr/bin/env python3
"""Gives Cody eye bones, so his eyes can look (gauntlet/refs/aaa_gap.md item 12).

His eyes were counted as "part of his body mesh" and left out of EyeAim. They
are not painted on: measured on the committed
`game/assets/characters/cody_rhodes.glb`, each eye is two separate closed
pieces of the body mesh at eye height (z ~1.714) --

  * an eyeball, ~120 verts, radius 0.016
  * a cornea shell in front of it, 36 verts, radius 0.0145

-- weighted to the Head bone like the skin around them, so they could only
ever turn with the skull. This adds `Eye_L` and `Eye_R` under Head, each at
its eyeball's centre and pointing at its cornea, and moves the eyeball's and
cornea's weight wholly onto it. Nothing else in the mesh changes; the eyelids
and the socket stay on Head.

Which pieces are eyes is decided by shape, not by index, so the script keeps
working if the mesh is re-exported: connected components whose centre sits
in the eye band (z 1.69-1.74, |x| < 0.06) and whose radius is 0.010-0.020 m.
There must be exactly two eyeballs and two corneas, or it stops.

Character left/right: he faces +Y in Blender (the corneas sit in front of the
eyeballs on +Y), so his right is +X.

CodyModel sets base-rig bone poses directly and has no track for these, so
the rest pose is what the clips leave them at; EyeAim moves them.

Run:  python3 tools/assets/rig_cody_eyes.py
Rewrites game/assets/characters/cody_rhodes.glb in place. Idempotent: on a
file that already has the eye bones it exits without writing.
"""

from __future__ import annotations

import pathlib
import sys

import bpy
import bmesh  # after bpy: bpy is what puts it on the path
from mathutils import Vector

REPO = pathlib.Path(__file__).resolve().parents[2]
GLB = REPO / "game/assets/characters/cody_rhodes.glb"

EYE_BAND_Z = (1.69, 1.74)
EYE_BAND_X = 0.06
PIECE_RADIUS = (0.010, 0.020)
BONE_LENGTH = 0.02


def components(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen: set[int] = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            comp.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        out.append(comp)
    bm.free()
    return out


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GLB))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    if "Eye_L" in arm.data.bones:
        print("already has eye bones; nothing to do")
        return 0

    pieces = []   # (obj, verts, centre, radius)
    for o in bpy.data.objects:
        if o.type != "MESH" or o.parent != arm and o.find_armature() != arm:
            continue
        mw = o.matrix_world
        for comp in components(o):
            pts = [mw @ o.data.vertices[i].co for i in comp]
            c = sum(pts, Vector()) / len(pts)
            if not (EYE_BAND_Z[0] < c.z < EYE_BAND_Z[1] and abs(c.x) < EYE_BAND_X):
                continue
            r = max((p - c).length for p in pts)
            if PIECE_RADIUS[0] <= r <= PIECE_RADIUS[1]:
                pieces.append((o, comp, c, r))
    # Eyeballs sit further back than corneas.
    pieces.sort(key=lambda p: p[2].y)
    if len(pieces) != 4:
        print(f"expected 2 eyeballs + 2 corneas, found {len(pieces)}: "
              + ", ".join(f"{p[2]} r={p[3]:.4f}" for p in pieces))
        return 1
    balls, corneas = pieces[:2], pieces[2:]
    eyes = {}
    for side, sign in (("R", 1.0), ("L", -1.0)):
        ball = next(p for p in balls if (p[2].x > 0) == (sign > 0))
        cornea = next(p for p in corneas if (p[2].x > 0) == (sign > 0))
        eyes[side] = (ball, cornea)
        print(f"Eye_{side}: ball {tuple(round(v, 4) for v in ball[2])} r={ball[3]:.4f}, "
              f"cornea {tuple(round(v, 4) for v in cornea[2])}")

    inv = arm.matrix_world.inverted()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    head = arm.data.edit_bones["Head"]
    for side, (ball, cornea) in eyes.items():
        b = arm.data.edit_bones.new(f"Eye_{side}")
        b.head = inv @ ball[2]
        b.tail = b.head + (inv.to_3x3() @ (cornea[2] - ball[2])).normalized() * BONE_LENGTH
        b.roll = 0.0
        b.parent = head
        b.use_deform = True
    bpy.ops.object.mode_set(mode="OBJECT")

    for side, (ball, cornea) in eyes.items():
        for obj, comp, _, _ in (ball, cornea):
            group = obj.vertex_groups.get(f"Eye_{side}") \
                or obj.vertex_groups.new(name=f"Eye_{side}")
            for i in comp:
                for g in list(obj.data.vertices[i].groups):
                    obj.vertex_groups[g.group].remove([i])
                group.add([i], 1.0, "REPLACE")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(GLB),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=False,
        export_yup=True,
        export_image_format="AUTO",
    )
    print(f"wrote {GLB} ({GLB.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
