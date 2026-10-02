"""Kenny Omega, rebuilt to the owner's character sheet
(gauntlet/refs/characters/kenny_omega_sheet.png).

Run with the bpy module (no Blender application required):

    python3 tools/blender/kenny_aaa.py

What it replaces, and why
-------------------------
`kenny_omega.glb` is a photogrammetry scan of a 17.6 cm action figure -- in a
waistcoat and jeans, with a sculpted plastic head, the scanning room's light
baked into one 4K texture and a pointing hand frozen into the mesh
(core/match/kenny_model.gd). The sheet is a different man to look at:
shirtless, in white tights with a gold-and-black filigree, black-and-gold
kneepads and knee boots, white wrist tape, shoulder-length curly blond hair
and stubble.

The path is Aubrey's (tools/blender/aubrey_aaa.py, character_aaa_plan.md
section 3), which is proven in the game:

* KEEP THE SKELETON. The scan was rigged on the base rig's 65 bones
  (tools/assets/rig_static_wrestler.py); every clip, paired move, grip and
  collision test reads those bones. This script imports `kenny_omega.glb`,
  throws its mesh away and keeps its armature byte for byte -- its rest pose is
  near a T with a wide stance, which is what the new body is fitted to.
* A NEW BODY: MPFB's human (CC0), male, ~40, a heavyweight wrestler's build,
  fitted to that skeleton -- MPFB's game-engine rig is pinned joint for joint
  onto his and aimed bone for bone, the deformation applied, and MPFB's
  weights carried over onto his bone names (they are the same UE-style names
  bar `Head`).

This is stage 1 (the body). Later stages add the gear, the likeness and hair,
the skin and the in-game wiring; see README's work log.
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
SOURCE = ROOT / "game/assets/characters/kenny_omega.glb"
OUT = ROOT / "game/assets/characters/kenny_aaa.glb"
MPFB = "bl_ext.user_default.mpfb"
BODY_NAME = "Kenny_Body"
## The base rig, whose mannequin is skinned to these exact 65 bones by the
## rig's author.
BASE_RIG = ROOT / "game/assets/characters/wrestler_base.glb"
## Weight smoothing after the transfer (rig_static_wrestler.py's numbers).
WEIGHT_SMOOTH_PASSES = 6
WEIGHT_SMOOTH_FACTOR = 0.5

## His build (the sheet's turnaround): a heavyweight in his early forties --
## broad shoulders and lats, big arms and chest, a lean waist with the abs
## showing, thick thighs. MPFB macros first, then targets for what they do not
## reach.
MACROS = {
    "gender": 1.0, "age": 0.6, "muscle": 1.0, "weight": 0.62,
    "proportions": 0.75, "african": 0.0, "asian": 0.0, "caucasian": 1.0,
}
## Measured (tools: girth bands at chest, waist, hips, thigh and upper arm,
## rest pose): the macros alone gave a 0.31 x 0.20 m chest and a 0.10 m upper
## arm -- an ordinary fit man, smaller than the scan he replaces (0.37 m deep
## at the chest) and than Cody (0.20 m arm). Targets build him out toward the
## sheet's, inside what the scan already occupied, so the paired moves keep
## the clearances they were tuned on.
BODY = {
    "torso-vshape-incr": 0.6,
    "torso-scale-depth-incr": 0.2,
    "torso-scale-horiz-incr": 0.35,
    "torso-muscle-dorsi-incr": 1.0,
    "torso-muscle-pectoral-incr": 0.5,
    "measure-shoulder-dist-incr": 0.4,
    "measure-waist-circ-decr": 0.15,
    "stomach-tone-incr": 0.8,
    "upperarm-muscle-incr": 1.0,
    "upperarm-shoulder-muscle-incr": 0.9,
    "upperarm-scale-horiz-incr": 0.5,
    "upperarm-scale-depth-incr": 0.5,
    "lowerarm-muscle-incr": 0.6,
    "upperleg-muscle-incr": 0.6,
    "upperleg-scale-horiz-incr": 0.3,
    "lowerleg-muscle-incr": 0.4,
    "neck-scale-horiz-incr": 0.4,
    "neck-scale-depth-incr": 0.3,
}
FACE: dict[str, float] = {}
## MPFB bone -> his bone, where the names differ.
BONE_NAMES = {"head": "Head"}
## Bones that take his bone's direction but keep their own position.
## Measured, MPFB's joint against his, before fitting: the base rig's spine
## is a different anatomy from MPFB's -- spine_03 at 1.315 m against MPFB's
## 1.152 (16 cm), spine_02 8 cm, the clavicles starting 5-6 cm higher and
## further forward. Pinned, those joints dragged his whole upper chest up into
## a fold that read as a hump round his neck once the arms came down. The
## torso keeps MPFB's shape; his weights come from the base rig's mannequin
## (transfer_weights), which is skinned to these bones where they are. The
## head rides MPFB's own neck, as Aubrey's does. The limbs stay pinned: an
## arm must turn about his shoulder joint, not 8 cm in front of it.
FREE_JOINTS = {"head", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"}


def mpfb(module: str, name: str):
    return getattr(importlib.import_module(f"{MPFB}.{module}"), name)


def make_body(old_arm):
    """MPFB's human, shaped to him and fitted to his skeleton, weights on his
    bone names; returns (body object, {"l"/"r": (eye centre, eye forward)})."""
    HumanService = mpfb("services.humanservice", "HumanService")
    TargetService = mpfb("services.targetservice", "TargetService")
    Props = mpfb("entities.objectproperties", "HumanObjectProperties")
    human = HumanService.create_human()
    human.name = BODY_NAME
    for key, value in MACROS.items():
        Props.set_value(key, value, entity_reference=human)
    TargetService.reapply_macro_details(human)
    for name, weight in sorted({**FACE, **BODY}.items()):
        sided = TargetService.target_full_path(name) is None
        for full in ([f"l-{name}", f"r-{name}"] if sided else [name]):
            path = TargetService.target_full_path(full)
            if path is None or not pathlib.Path(path).name.startswith(full + "."):
                raise SystemExit(f"kenny_aaa: no MPFB target {full}")
            TargetService.load_target(human, path, weight=weight, name=full)
    rig = HumanService.add_builtin_rig(human, "game_engine")
    # Pin every MPFB bone onto his. Disconnected first: Blender ignores Copy
    # Location on a bone connected to its parent (aubrey_aaa.py).
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
    eyes = {}
    for side in ("l", "r"):
        group = human.vertex_groups[f"helper-{side}-eye"].index
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if any(g.group == group and g.weight > 0.5 for g in v.groups)]
        centre = sum(pts, Vector()) / len(pts)
        front = min(pts, key=lambda p: p.y)          # he faces -Y
        eyes[side] = (centre, (front - centre).normalized())
    body_group = human.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(human.data)
    deform = bm.verts.layers.deform.active
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if body_group not in v[deform]],
                     context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
    for vg in list(human.vertex_groups):
        name = BONE_NAMES.get(vg.name, vg.name)
        if name in old_arm.data.bones:
            vg.name = name
        else:
            human.vertex_groups.remove(vg)
    bpy.data.objects.remove(rig, do_unlink=True)
    human.parent = old_arm
    human.matrix_parent_inverse = old_arm.matrix_world.inverted()
    human.modifiers.new("Armature", "ARMATURE").object = old_arm
    return human, eyes


def transfer_weights(body, old_arm) -> None:
    """His skin weights from the base rig's mannequin, not MPFB's.

    MPFB's weights are authored for MPFB's A-pose. Bound at this skeleton's
    T-pose, every arms-down clip swings the arm 60-80 degrees from bind, and
    MPFB gives the upper arm the side of the chest and the lats below the
    armpit: rotated that far, that skin swung up and in, a slab down his back
    and a hump round his neck (Roman_Stand, Cody_Stand). Bone-heat weights did
    the same. The mannequin's weights were authored on this rig in this pose,
    and are what the scan was rigged with (tools/assets/rig_static_wrestler.py):
    the mannequin is posed into his rest (his wide stance), snapshotted, and its
    weights carried over by nearest surface, then smoothed.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(BASE_RIG))
    new = [o for o in bpy.data.objects if o not in before]
    base_arm = next(o for o in new if o.type == "ARMATURE")
    mannequin = max((o for o in new if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    bpy.context.view_layer.objects.active = base_arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in base_arm.pose.bones:
        if pb.name in old_arm.data.bones:
            c = pb.constraints.new("COPY_TRANSFORMS")
            c.target, c.subtarget = old_arm, pb.name
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    mannequin.select_set(True)
    bpy.context.view_layer.objects.active = mannequin
    for mod in list(mannequin.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # Clear his MPFB weights, keeping one empty group per bone.
    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    for vg in mannequin.vertex_groups:
        body.vertex_groups.new(name=vg.name)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    mannequin.select_set(True)
    bpy.context.view_layer.objects.active = mannequin
    bpy.ops.object.data_transfer(data_type="VGROUP_WEIGHTS", vert_mapping="POLY_NEAREST",
                                 layers_select_src="ALL", layers_select_dst="NAME",
                                 mix_mode="REPLACE")
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=WEIGHT_SMOOTH_FACTOR,
                                       repeat=WEIGHT_SMOOTH_PASSES)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for vg in list(body.vertex_groups):
        if vg.name not in old_arm.data.bones:
            body.vertex_groups.remove(vg)
    weighted = sum(1 for v in body.data.vertices if v.groups)
    print(f"transfer_weights: {weighted}/{len(body.data.vertices)} vertices weighted")
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable(MPFB, default_set=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    old_arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    # The scan goes; only its skeleton is kept.
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    body, eyes = make_body(old_arm)
    transfer_weights(body, old_arm)
    # A plain skin tone until stage 4 paints his skin, so the forms read.
    skin = bpy.data.materials.new("M_KennySkin")
    skin.use_nodes = True
    bsdf = skin.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.62, 0.40, 0.30, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    body.data.materials.clear()
    body.data.materials.append(skin)
    for o in bpy.context.scene.objects:
        o.select_set(o == old_arm or o.parent == old_arm)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_skins=True,
                              export_apply=False, export_image_format="AUTO")
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"kenny_aaa: body {tris} triangles, eyes at "
          f"{tuple(round(c, 3) for c in eyes['l'][0])} -> {OUT}")
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
