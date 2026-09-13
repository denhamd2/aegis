"""Authors wrestling animation clips on the CC0 base rig and exports them
as a glTF animation library.

Run with the bpy module (no Blender application required):

    python3 game/tools/blender/wrestling_clips.py

Why this exists
---------------
Every clip the game plays today is *sampled* out of the 42 actions that ship
on wrestler_base.glb, by resources/animations/strike_recipes.gd and
paired_recipes.gd. That library is a generic CC0 character set -- Pistol_*,
Sword_*, Spell_*, Swim_*, Sitting_*, Walk/Jog/Sprint, Death01 -- and it
contains no wrestling whatsoever. Sampling can only recombine poses that
already exist, so a bump, a lock-up, a cover or a celebration has to be
approximated from Push, PickUp_Table, Jump_* and Death01. That ceiling is
why resources/animations/paired_recipes.gd reads the way it does, and why a
win reaction could not be built at all.

This module authors poses directly on the armature instead, so a pose that
is not in the source library is simply keyframed.

Output is deterministic: the same input table produces a byte-identical glb,
which is what lets it be committed and diffed like the .tres bakes.
"""

import math
import os
import sys

import bpy

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RIG = os.path.join(REPO, "assets", "characters", "wrestler_base.glb")
OUT = os.path.join(REPO, "assets", "animations", "wrestling_clips.glb")

# Authored at 30 fps: the project's physics runs at 60, so every frame lands
# on a whole tick and nothing has to be resampled on import.
FPS = 30


def load_rig():
    """Fresh scene with just the base rig's armature in it."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RIG)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit("expected exactly one armature, got %d" % len(arms))
    bpy.context.scene.render.fps = FPS
    return arms[0]


def clear_actions():
    """Drop the 42 source actions so only authored ones are exported."""
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def author(arm, name, poses):
    """Keyframe one action from a list of (frame, {bone: (rx, ry, rz)}) poses.

    Rotations are Euler degrees applied in the bone's own space, on top of
    the rest pose -- the same convention the `bones` offsets in
    paired_recipes.gd already use, so values carry over between the two.
    """
    action = bpy.data.actions.new(name)
    arm.animation_data_clear()
    arm.animation_data_create()
    arm.animation_data.action = action

    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"

    touched = sorted({b for _, pose in poses for b in pose})
    for frame, pose in poses:
        for bone_name in touched:
            pb = arm.pose.bones.get(bone_name)
            if pb is None:
                raise SystemExit("%s: no bone %r on the rig" % (name, bone_name))
            rx, ry, rz = pose.get(bone_name, (0.0, 0.0, 0.0))
            pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
            pb.keyframe_insert("rotation_euler", frame=frame)
    return action


def export(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_apply=False,
        # Determinism: no timestamps, no generator string churn.
        export_yup=True,
    )
