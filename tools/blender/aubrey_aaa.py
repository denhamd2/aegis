#!/usr/bin/env python3
"""The referee, Aubrey Edwards, rebuilt to a AAA standard (character_aaa_plan.md
A1-A3) on a realistic human body, on her existing skeleton.

    python3 tools/blender/aubrey_aaa.py

Reads   game/assets/characters/aubrey_edwards.glb   (the kit build: skeleton,
                                                    uniform, hair)
Writes  game/assets/characters/aubrey_aaa.glb

Why: her kit body (Quaternius' Superhero_Female) is a cartoon -- 17 mm eyes,
painted lids, a toy's face -- and the owner's character sheet is a real woman.
The body is now MPFB's (MakeHuman for Blender, CC0 code and assets), shaped to
her, and everything the game relies on is kept:

* THE SKELETON is hers, untouched: the same 70 bones, names and rest pose, so
  every clip, paired move and the referee's own logic play on her as before
  (the plan's rule 1). MPFB's game-engine rig uses the same bone names (its
  "head" is her "Head"), so the body is FITTED to her skeleton rather than
  the other way round: each MPFB bone is pinned to her bone of the same name
  (Copy Location to its head, Damped Track to its tail) and that pose is
  baked into the mesh. Her joints then bend exactly where the clips bend
  them. Joints move and bones only aim -- no Stretch To, which would scale
  each bone's own region (her kit head bone is 20 cm to MPFB's 15) -- so the
  mesh between joints stretches through its blended weights while a head or
  a hand keeps its size.
* THE WEIGHTS are MPFB's own -- complete and smooth, fingers included --
  renamed onto her bones; her kit body cannot supply them (the skin under
  her uniform was deleted when the uniform was cut).
* Helpers (MakeHuman's joint cubes, tights, skirt, eye and teeth proxies) are
  measured and then deleted; the eyes are rebuilt as eyeballs where MPFB's
  eye helpers sit, for the head kit's eye texture (build_eyes.py, EyeKit).

Requires MPFB installed as a Blender extension (bl_ext.user_default.mpfb) and
its MakeHuman system assets and skin packs under ~/.cache/aegis_assets/mpfb;
see gauntlet/refs/character_aaa_plan.md. Deterministic.
"""

from __future__ import annotations

import importlib
import math
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import addon_utils
import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/assets/characters/aubrey_edwards.glb"
OUT = ROOT / "game/assets/characters/aubrey_aaa.glb"
MPFB = "bl_ext.user_default.mpfb"

## MPFB's macro sliders for her: a woman (MakeHuman's gender runs 0 female
## to 1 male -- the first build at 1.0 was a heavyset man) of about forty
## (age 0.5 is 25 and 1.0 is 90), lean and athletic -- she runs a ring for a
## living -- with idealised rather than average proportions.
MACROS = {
    "gender": 0.0, "age": 0.62, "muscle": 0.62, "weight": 0.42,
    "proportions": 0.75, "african": 0.0, "asian": 0.0, "caucasian": 1.0,
}
## MPFB bone -> her bone, where the names differ.
BONE_NAMES = {"head": "Head"}
## Bones that take her bone's direction but keep their own position. Her kit
## skeleton is a stylised one with a big head: its head joint sits 21.7 cm
## under the crown, where a real head's is ~15. Pinned there, a real head
## sank 8 cm onto a stub of a neck (eyes at 1.58 against 1.66). Left free, it
## rides MPFB's own neck; the head turns about her Head bone, ~3.5 cm lower
## in the neck, which no clip's head rotation shows.
FREE_JOINTS = {"head"}
## Eyeball radius over MPFB's eye helper's: the helper is the eye's visible
## front; a real eyeball is ~12 mm.
EYE_RADIUS = 0.0118
EYE_SEGMENTS = (32, 16)
## The eyes' front projection (build_eyes.py AUBREY_NEW): mm per UV unit.
EYE_MM_PER_UV = 30.0


def mpfb(module: str, name: str):
    return getattr(importlib.import_module(f"{MPFB}.{module}"), name)


def make_body(old_arm):
    """MPFB's human, shaped to her and fitted to her skeleton, weights on her
    bone names; returns (body object, {"l"/"r": (eye centre, eye forward)})."""
    HumanService = mpfb("services.humanservice", "HumanService")
    TargetService = mpfb("services.targetservice", "TargetService")
    Props = mpfb("entities.objectproperties", "HumanObjectProperties")
    human = HumanService.create_human()
    human.name = "Aubrey_Body"
    for key, value in MACROS.items():
        Props.set_value(key, value, entity_reference=human)
    TargetService.reapply_macro_details(human)
    rig = HumanService.add_builtin_rig(human, "game_engine")
    # Pin every MPFB bone onto hers. Disconnected first: Blender ignores Copy
    # Location on a bone connected to its parent, and the first build kept
    # MPFB's own (shorter) spine -- her head 8 cm low.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        eb.use_connect = False
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        target = BONE_NAMES.get(pb.name, pb.name)
        if target not in old_arm.data.bones:
            continue
        if pb.name not in FREE_JOINTS:
            loc = pb.constraints.new("COPY_LOCATION")
            loc.target, loc.subtarget = old_arm, target
        aim = pb.constraints.new("DAMPED_TRACK")
        aim.target, aim.subtarget = old_arm, target
        aim.head_tail = 1.0
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    # Bake: shape keys (the macro targets), then the fitting pose.
    bpy.context.view_layer.objects.active = human
    for o in bpy.context.selected_objects:
        o.select_set(False)
    human.select_set(True)
    for mod in list(human.modifiers):
        if mod.type == "MASK":
            human.modifiers.remove(mod)
    if human.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for mod in list(human.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # The eyes, from MPFB's eye helpers, before the helpers go.
    eyes = {}
    for side in ("l", "r"):
        group = human.vertex_groups[f"helper-{side}-eye"].index
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if any(g.group == group and g.weight > 0.5 for g in v.groups)]
        centre = sum(pts, Vector()) / len(pts)
        front = min(pts, key=lambda p: p.y)          # she faces -Y
        eyes[side] = (centre, (front - centre).normalized())
    # Keep only the body.
    body_group = human.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(human.data)
    deform = bm.verts.layers.deform.active
    doomed = [v for v in bm.verts if body_group not in v[deform]]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
    # Weights onto her bones: rename, and drop every group that is not one
    # of her bones (MPFB's own helper and joint groups).
    for vg in list(human.vertex_groups):
        name = BONE_NAMES.get(vg.name, vg.name)
        if name in old_arm.data.bones:
            vg.name = name
        else:
            human.vertex_groups.remove(vg)
    bpy.data.objects.remove(rig, do_unlink=True)
    human.parent = old_arm
    human.matrix_parent_inverse = old_arm.matrix_world.inverted()
    arm_mod = human.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = old_arm
    return human, eyes


def make_eyes(old_arm, eyes):
    """Two eyeballs, front-projected UVs centred on the line of sight, rigid
    on her Head bone."""
    objs = []
    for side, (centre, forward) in eyes.items():
        bpy.ops.mesh.primitive_uv_sphere_add(segments=EYE_SEGMENTS[0], ring_count=EYE_SEGMENTS[1],
                                             radius=EYE_RADIUS, location=centre)
        eye = bpy.context.active_object
        eye.name = f"Aubrey_Eye_{side.upper()}"
        # Line of sight on -Y: rotate the sphere's pole onto it so the UV
        # projection below is symmetric about the pupil.
        eye.rotation_mode = "QUATERNION"
        eye.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(forward)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        uv = eye.data.uv_layers.active.data
        right = Vector((1.0, 0.0, 0.0))
        up = forward.cross(right).normalized()
        right = up.cross(forward).normalized()
        for loop in eye.data.loops:
            p = eye.data.vertices[loop.vertex_index].co
            uv[loop.index].uv = (0.5 + p.dot(right) * 1000.0 / EYE_MM_PER_UV,
                                 0.5 - p.dot(up) * 1000.0 / EYE_MM_PER_UV)
        bpy.ops.object.shade_smooth()
        group = eye.vertex_groups.new(name="Head")
        group.add(list(range(len(eye.data.vertices))), 1.0, "REPLACE")
        eye.parent = old_arm
        eye.matrix_parent_inverse = old_arm.matrix_world.inverted()
        mod = eye.modifiers.new("Armature", "ARMATURE")
        mod.object = old_arm
        objs.append(eye)
    return objs


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable(MPFB, default_set=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    old_arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for name in ("Aubrey_Body", "Eyes", "Eyebrows"):
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    body, eyes = make_body(old_arm)
    make_eyes(old_arm, eyes)
    for o in bpy.context.scene.objects:
        o.select_set(o == old_arm or o.parent == old_arm)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_skins=True,
                              export_apply=False, export_image_format="AUTO")
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"aubrey_aaa: body {tris} triangles -> {OUT}")
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
