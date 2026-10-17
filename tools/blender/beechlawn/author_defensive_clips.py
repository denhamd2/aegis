"""Author small, in-place football defensive clips on the supplied Mixamo Y-Bot.

Usage from repository root:
    blender -b tools/blender/beechlawn/y_bot_source.blend --python tools/blender/beechlawn/author_defensive_clips.py

The match controller remains responsible for translation, tackle contact, and ball
response. These actions are presentation-only proxy clips for the future AnimationTree.
"""
from pathlib import Path
import bpy
from math import radians
from mathutils import Euler

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tools/blender/beechlawn/y_bot_source.blend"
BLEND_OUT = ROOT / "tools/blender/beechlawn/y_bot_animation_set.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_set.glb"
ARMATURE_NAME = "YBot_Armature"

# Per frame, local Euler rotations in degrees. Clip roots stay in place so the
# Godot CharacterBody remains the sole authority for locomotion and contact.
SLIDE = {
    1: {},
    4: {"mixamorig:Hips": (3, 0, -2), "mixamorig:Spine": (-4, 0, 0),
        "mixamorig:LeftUpLeg": (8, 0, -3), "mixamorig:RightUpLeg": (6, 0, 3),
        "mixamorig:LeftArm": (0, 0, 10), "mixamorig:RightArm": (0, 0, -10), "__hips_y__": -5},
    8: {"mixamorig:Hips": (8, 0, -5), "mixamorig:Spine": (-8, 0, 2),
        "mixamorig:Spine1": (-5, 0, 0), "mixamorig:LeftUpLeg": (15, 0, -4),
        "mixamorig:LeftLeg": (-20, 0, 0), "mixamorig:RightUpLeg": (-10, 0, 3),
        "mixamorig:RightLeg": (24, 0, 0), "mixamorig:LeftArm": (0, 0, 16),
        "mixamorig:LeftForeArm": (-16, 0, 0), "mixamorig:RightArm": (0, 0, -16),
        "mixamorig:RightForeArm": (-16, 0, 0), "__hips_y__": -26},
    12: {"mixamorig:Hips": (11, 0, -7), "mixamorig:Spine": (-11, 0, 3),
         "mixamorig:Spine1": (-6, 0, 0), "mixamorig:LeftUpLeg": (19, 0, -5),
         "mixamorig:LeftLeg": (-34, 0, 0), "mixamorig:RightUpLeg": (-14, 0, 5),
         "mixamorig:RightLeg": (28, 0, 0), "mixamorig:LeftArm": (0, 0, 20),
         "mixamorig:LeftForeArm": (-22, 0, 0), "mixamorig:RightArm": (0, 0, -18),
         "mixamorig:RightForeArm": (-20, 0, 0), "mixamorig:Head": (-3, 0, 3), "__hips_y__": -38},
    19: {"mixamorig:Hips": (8, 0, -10), "mixamorig:Spine": (-8, 0, 5),
         "mixamorig:LeftUpLeg": (13, 0, -5), "mixamorig:LeftLeg": (-27, 0, 0),
         "mixamorig:RightUpLeg": (-7, 0, 5), "mixamorig:RightLeg": (19, 0, 0),
         "mixamorig:LeftArm": (0, 0, 24), "mixamorig:RightArm": (0, 0, -25),
         "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-17, 0, 0), "__hips_y__": -34},
    26: {"mixamorig:Hips": (3, 0, -4), "mixamorig:Spine": (-4, 0, 1),
         "mixamorig:LeftUpLeg": (8, 0, -3), "mixamorig:RightUpLeg": (6, 0, 3),
         "mixamorig:LeftArm": (0, 0, 12), "mixamorig:RightArm": (0, 0, -12), "__hips_y__": -14},
    30: {},
}

SHOULDER_SELL = {
    1: {},
    3: {"mixamorig:Hips": (0, 0, -2), "mixamorig:Spine": (-4, 0, 2),
        "mixamorig:Spine1": (-3, 0, 0), "mixamorig:LeftArm": (0, 0, 12),
        "mixamorig:RightArm": (0, 0, -12)},
    6: {"mixamorig:Hips": (1, 0, -5), "mixamorig:Spine": (-8, 0, 7),
        "mixamorig:Spine1": (-5, 0, 2), "mixamorig:Head": (2, 0, -5),
        "mixamorig:LeftArm": (0, 0, 25), "mixamorig:LeftForeArm": (-24, 0, 0),
        "mixamorig:RightArm": (0, 0, -23), "mixamorig:RightForeArm": (-21, 0, 0),
        "mixamorig:LeftUpLeg": (4, 0, -3), "mixamorig:RightUpLeg": (-3, 0, 3)},
    10: {"mixamorig:Hips": (1, 0, -3), "mixamorig:Spine": (-5, 0, 4),
         "mixamorig:Spine1": (-3, 0, 2), "mixamorig:Head": (1, 0, -3),
         "mixamorig:LeftArm": (0, 0, 18), "mixamorig:LeftForeArm": (-30, 0, 0),
         "mixamorig:RightArm": (0, 0, -16), "mixamorig:RightForeArm": (-26, 0, 0),
         "mixamorig:LeftUpLeg": (2, 0, -2), "mixamorig:RightUpLeg": (-1, 0, 1)},
    16: {"mixamorig:Hips": (0, 0, -1), "mixamorig:Spine": (-2, 0, 2),
         "mixamorig:LeftArm": (0, 0, 10), "mixamorig:LeftForeArm": (-16, 0, 0),
         "mixamorig:RightArm": (0, 0, -10), "mixamorig:RightForeArm": (-15, 0, 0)},
    22: {},
}

# Locomotion clips are in-place. The root stays fixed; the CharacterBody drives
# travel and speed in Godot while this shared skeleton presents the gait.
IDLE = {
    1: {},
    12: {"mixamorig:Spine": (1, 0, 0), "mixamorig:Spine1": (2, 0, 0),
         "mixamorig:Spine2": (1, 0, 0), "mixamorig:Head": (-1, 0, 0)},
    23: {},
    34: {"mixamorig:Spine": (-1, 0, 0), "mixamorig:Spine1": (-2, 0, 0),
         "mixamorig:Spine2": (-1, 0, 0), "mixamorig:Head": (1, 0, 0)},
    45: {},
}

JOG = {
    1: {"mixamorig:LeftUpLeg": (22, 0, 0), "mixamorig:RightUpLeg": (-22, 0, 0),
        "mixamorig:LeftLeg": (6, 0, 0), "mixamorig:RightLeg": (31, 0, 0),
        "mixamorig:Spine": (2, 0, 0), "mixamorig:Spine1": (1, 0, 0),
        "mixamorig:LeftArm": (0, 0, -22), "mixamorig:RightArm": (0, 0, 22),
        "mixamorig:LeftForeArm": (-17, 0, 0), "mixamorig:RightForeArm": (-17, 0, 0)},
    7: {"mixamorig:LeftUpLeg": (4, 0, 0), "mixamorig:RightUpLeg": (-4, 0, 0),
        "mixamorig:LeftLeg": (11, 0, 0), "mixamorig:RightLeg": (11, 0, 0),
        "mixamorig:Spine": (1, 0, 0), "mixamorig:Spine1": (0, 0, 0),
        "mixamorig:LeftArm": (0, 0, -4), "mixamorig:RightArm": (0, 0, 4),
        "__hips_y__": 2},
    13: {"mixamorig:LeftUpLeg": (-22, 0, 0), "mixamorig:RightUpLeg": (22, 0, 0),
         "mixamorig:LeftLeg": (31, 0, 0), "mixamorig:RightLeg": (6, 0, 0),
         "mixamorig:Spine": (2, 0, 0), "mixamorig:Spine1": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, 22), "mixamorig:RightArm": (0, 0, -22),
         "mixamorig:LeftForeArm": (-17, 0, 0), "mixamorig:RightForeArm": (-17, 0, 0)},
    19: {"mixamorig:LeftUpLeg": (-4, 0, 0), "mixamorig:RightUpLeg": (4, 0, 0),
         "mixamorig:LeftLeg": (11, 0, 0), "mixamorig:RightLeg": (11, 0, 0),
         "mixamorig:Spine": (1, 0, 0), "mixamorig:Spine1": (0, 0, 0),
         "mixamorig:LeftArm": (0, 0, 4), "mixamorig:RightArm": (0, 0, -4),
         "__hips_y__": 2},
    25: {"mixamorig:LeftUpLeg": (22, 0, 0), "mixamorig:RightUpLeg": (-22, 0, 0),
         "mixamorig:LeftLeg": (6, 0, 0), "mixamorig:RightLeg": (31, 0, 0),
         "mixamorig:Spine": (2, 0, 0), "mixamorig:Spine1": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -22), "mixamorig:RightArm": (0, 0, 22),
         "mixamorig:LeftForeArm": (-17, 0, 0), "mixamorig:RightForeArm": (-17, 0, 0)},
}

SPRINT = {
    1: {"mixamorig:LeftUpLeg": (32, 0, 0), "mixamorig:RightUpLeg": (-32, 0, 0),
        "mixamorig:LeftLeg": (10, 0, 0), "mixamorig:RightLeg": (44, 0, 0),
        "mixamorig:LeftArm": (0, 0, -31), "mixamorig:RightArm": (0, 0, 31),
        "mixamorig:LeftForeArm": (-27, 0, 0), "mixamorig:RightForeArm": (-27, 0, 0),
        "mixamorig:Spine": (5, 0, 0), "mixamorig:Spine1": (2, 0, 0)},
    5: {"mixamorig:LeftUpLeg": (4, 0, 0), "mixamorig:RightUpLeg": (-4, 0, 0),
        "mixamorig:LeftLeg": (17, 0, 0), "mixamorig:RightLeg": (17, 0, 0),
        "mixamorig:LeftArm": (0, 0, -8), "mixamorig:RightArm": (0, 0, 8),
        "mixamorig:Spine": (3, 0, 0), "mixamorig:Spine1": (1, 0, 0), "__hips_y__": 3},
    9: {"mixamorig:LeftUpLeg": (-32, 0, 0), "mixamorig:RightUpLeg": (32, 0, 0),
        "mixamorig:LeftLeg": (44, 0, 0), "mixamorig:RightLeg": (10, 0, 0),
        "mixamorig:LeftArm": (0, 0, 31), "mixamorig:RightArm": (0, 0, -31),
        "mixamorig:LeftForeArm": (-27, 0, 0), "mixamorig:RightForeArm": (-27, 0, 0),
        "mixamorig:Spine": (5, 0, 0), "mixamorig:Spine1": (2, 0, 0)},
    13: {"mixamorig:LeftUpLeg": (-4, 0, 0), "mixamorig:RightUpLeg": (4, 0, 0),
         "mixamorig:LeftLeg": (17, 0, 0), "mixamorig:RightLeg": (17, 0, 0),
         "mixamorig:LeftArm": (0, 0, 8), "mixamorig:RightArm": (0, 0, -8),
         "mixamorig:Spine": (3, 0, 0), "mixamorig:Spine1": (1, 0, 0), "__hips_y__": 3},
    17: {"mixamorig:LeftUpLeg": (32, 0, 0), "mixamorig:RightUpLeg": (-32, 0, 0),
         "mixamorig:LeftLeg": (10, 0, 0), "mixamorig:RightLeg": (44, 0, 0),
         "mixamorig:LeftArm": (0, 0, -31), "mixamorig:RightArm": (0, 0, 31),
         "mixamorig:LeftForeArm": (-27, 0, 0), "mixamorig:RightForeArm": (-27, 0, 0),
         "mixamorig:Spine": (5, 0, 0), "mixamorig:Spine1": (2, 0, 0)},
}


def make_action(armature, name, poses):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action
    used = sorted({bone for pose in poses.values() for bone in pose if not bone.startswith("__")})
    for frame, pose in poses.items():
        bpy.context.scene.frame_set(frame)
        for bone_name in used:
            bone = armature.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Missing expected Mixamo bone: {bone_name}")
            bone.rotation_mode = "QUATERNION"
            degrees = pose.get(bone_name, (0, 0, 0))
            bone.rotation_quaternion = Euler(tuple(radians(v) for v in degrees), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone_name)
        hips = armature.pose.bones["mixamorig:Hips"]
        hips.location = (0.0, float(pose.get("__hips_y__", 0.0)), 0.0)
        hips.keyframe_insert(data_path="location", frame=frame, group="mixamorig:Hips")
    # Smooth organic transitions, with preserved overshoot only where explicitly keyed.
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    return action


def main():
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    armature = bpy.data.objects.get(ARMATURE_NAME)
    if armature is None or len(armature.data.bones) != 65:
        raise RuntimeError("Expected the verified 65-bone YBot_Armature")

    bpy.context.scene.render.fps = 30
    idle = make_action(armature, "AN_Beechlawn_Idle", IDLE)
    jog = make_action(armature, "AN_Beechlawn_Jog", JOG)
    sprint = make_action(armature, "AN_Beechlawn_Sprint", SPRINT)
    slide = make_action(armature, "AN_Beechlawn_SlideTackle", SLIDE)
    sell = make_action(armature, "AN_Beechlawn_ShoulderImpactSell", SHOULDER_SELL)
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 30
    bpy.context.scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version = 0
    BLEND_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))

    # Include the rig and skinned proxy so Godot's importer can validate the
    # skeleton/action relationship before runtime integration.
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [armature, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    GLB_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_OUT), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_cameras=False,
        export_lights=False, export_animations=True,
        export_animation_mode="ACTIONS", export_skins=True,
        export_influence_nb=4, export_leaf_bone=False,
        export_rest_position_armature=True, export_force_sampling=True,
        export_optimize_animation_size=True,
    )
    print(f"ANIMATION_SET actions={[idle.name, jog.name, sprint.name, slide.name, sell.name]} output={GLB_OUT}")
    print(f"ANIMATION_SET bytes={GLB_OUT.stat().st_size}")


if __name__ == "__main__":
    main()
