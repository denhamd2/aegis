"""Author a short, prone-to-ready recovery action for the shared Y-Bot.

Run from repository root with Blender 4.3.2:
  blender -b --python games/beechlawn_rovers/tools/blender/author_football_getup.py

The clip is visual only and has no root motion. Godot owns the actor's position
and downed/recovery timing; this action is available for a future explicit
downed-state transition. Temporary hand IK is baked to ordinary bone keys.
"""
from pathlib import Path
from math import radians

import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
BLEND = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
RIG_NAME = "YBot_Armature"
ACTION_NAME = "AN_Beechlawn_GetUpFromProne"
FPS = 60
START, END = 1, 55  # 0.9 seconds, sampled at 60 Hz.

# Local Mixamo bone rotations in degrees. The pelvis begins turned down and
# close to the turf, transfers weight through both hands and one knee, then
# drives over a planted foot into the same compact ready silhouette as idle.
POSES = {
    1: {
        "mixamorig:Hips": (82, 0, 7), "mixamorig:Spine": (-3, 0, -4),
        "mixamorig:Spine1": (-1, 0, -2), "mixamorig:Head": (8, 0, 0),
        "mixamorig:LeftUpLeg": (-38, 0, -8), "mixamorig:LeftLeg": (86, 0, 0),
        "mixamorig:RightUpLeg": (-18, 0, 12), "mixamorig:RightLeg": (72, 0, 0),
        "mixamorig:LeftArm": (0, 0, -18), "mixamorig:RightArm": (0, 0, 18),
        "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-18, 0, 0),
        "__hips_drop_m__": -0.68,
    },
    8: {
        "mixamorig:Hips": (82, 0, 6), "mixamorig:Spine": (-4, 0, -3),
        "mixamorig:Spine1": (-2, 0, -1), "mixamorig:Head": (9, 0, 0),
        "mixamorig:LeftUpLeg": (-42, 0, -10), "mixamorig:LeftLeg": (92, 0, 0),
        "mixamorig:RightUpLeg": (-20, 0, 12), "mixamorig:RightLeg": (76, 0, 0),
        "__hips_drop_m__": -0.68,
    },
    16: {
        "mixamorig:Hips": (58, 0, 4), "mixamorig:Spine": (-8, 0, -3),
        "mixamorig:Spine1": (-3, 0, -1), "mixamorig:Head": (8, 0, 0),
        "mixamorig:LeftUpLeg": (-28, 0, -5), "mixamorig:LeftLeg": (70, 0, 0),
        "mixamorig:RightUpLeg": (-2, 0, 8), "mixamorig:RightLeg": (96, 0, 0),
        "mixamorig:LeftArm": (0, 0, -10), "mixamorig:RightArm": (0, 0, 10),
        "__hips_drop_m__": -0.48,
    },
    25: {
        "mixamorig:Hips": (30, 0, 2), "mixamorig:Spine": (-14, 0, -2),
        "mixamorig:Spine1": (-5, 0, -1), "mixamorig:Head": (8, 0, 0),
        "mixamorig:LeftUpLeg": (-8, 0, -3), "mixamorig:LeftLeg": (42, 0, 0),
        "mixamorig:RightUpLeg": (14, 0, 8), "mixamorig:RightLeg": (102, 0, 0),
        "__hips_drop_m__": -0.26,
    },
    34: {
        "mixamorig:Hips": (17, 0, 0), "mixamorig:Spine": (-8, 0, 0),
        "mixamorig:Spine1": (-3, 0, 0), "mixamorig:Head": (5, 0, 0),
        "mixamorig:LeftUpLeg": (-8, 0, -2), "mixamorig:LeftLeg": (28, 0, 0),
        "mixamorig:RightUpLeg": (30, 0, 6), "mixamorig:RightLeg": (82, 0, 0),
        "mixamorig:LeftArm": (0, 0, -12), "mixamorig:RightArm": (0, 0, 12),
        "__hips_drop_m__": -0.12,
    },
    43: {
        "mixamorig:Hips": (9, 0, 0), "mixamorig:Spine": (-4, 0, 0),
        "mixamorig:Spine1": (-2, 0, 0), "mixamorig:Head": (3, 0, 0),
        "mixamorig:LeftUpLeg": (2, 0, -2), "mixamorig:LeftLeg": (10, 0, 0),
        "mixamorig:RightUpLeg": (8, 0, 4), "mixamorig:RightLeg": (12, 0, 0),
        "mixamorig:LeftArm": (0, 0, -5), "mixamorig:RightArm": (0, 0, 5),
        "mixamorig:LeftForeArm": (-8, 0, 0), "mixamorig:RightForeArm": (-8, 0, 0),
        "__hips_drop_m__": -0.04,
    },
    50: {
        "mixamorig:Hips": (3, 0, 0), "mixamorig:Spine": (-2, 0, 0),
        "mixamorig:Head": (2, 0, 0), "mixamorig:LeftArm": (0, 0, -4),
        "mixamorig:RightArm": (0, 0, 4), "__hips_drop_m__": -0.01,
    },
    END: {
        "mixamorig:Hips": (0, 0, 0), "mixamorig:Spine": (-1, 0, 0),
        "mixamorig:Spine1": (0, 0, 0), "mixamorig:Head": (0, 0, 0),
        "mixamorig:LeftArm": (0, 0, -7), "mixamorig:RightArm": (0, 0, 7),
        "mixamorig:LeftForeArm": (-9, 0, 0), "mixamorig:RightForeArm": (-9, 0, 0),
        "__hips_drop_m__": 0.0,
    },
}

LEFT_HAND = {
    1: (0.37, -0.05, 0.05), 8: (0.37, -0.05, 0.05),
    16: (0.35, -0.16, 0.05), 25: (0.34, -0.20, 0.05),
    34: (0.34, -0.10, 0.05), 43: (0.36, -0.05, 0.28),
    50: (0.34, -0.05, 0.78), END: (0.34, -0.06, 0.98),
}
RIGHT_HAND = {
    1: (-0.37, -0.05, 0.05), 8: (-0.37, -0.05, 0.05),
    16: (-0.35, -0.16, 0.05), 25: (-0.35, -0.20, 0.05),
    34: (-0.35, -0.10, 0.05), 43: (-0.36, -0.05, 0.34),
    50: (-0.34, -0.05, 0.80), END: (-0.34, -0.06, 0.98),
}
LEFT_FOOT = {
    1: (0.095, -0.20, 0.10), 8: (0.095, -0.20, 0.10),
    16: (0.13, -0.20, 0.06), 25: (0.15, -0.18, 0.033),
    34: (0.14, -0.15, 0.033), 43: (0.095, -0.113, 0.033),
    50: (0.095, -0.113, 0.033), END: (0.095, -0.113, 0.033),
}
RIGHT_FOOT = {
    1: (-0.095, -0.20, 0.13), 8: (-0.095, -0.20, 0.13),
    16: (-0.12, -0.17, 0.08), 25: (-0.095, -0.16, 0.033),
    34: (-0.095, -0.14, 0.033), 43: (-0.095, -0.113, 0.033),
    50: (-0.095, -0.113, 0.033), END: (-0.095, -0.113, 0.033),
}


def _empty(scene, name, location):
    target = bpy.data.objects.new(name, None)
    scene.collection.objects.link(target)
    target.location = Vector(location)
    return target


def _key_target(scene, target, mapping):
    for frame, point in mapping.items():
        scene.frame_set(frame)
        target.location = Vector(point)
        target.keyframe_insert("location", frame=frame)
    for curve in target.animation_data.action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"


def author(rig, scene):
    old = bpy.data.actions.get(ACTION_NAME)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(ACTION_NAME)
    rig.animation_data_create()
    rig.animation_data.action = action
    used = {name for pose in POSES.values() for name in pose if not name.startswith("__")}
    for frame, pose in POSES.items():
        scene.frame_set(frame)
        for bone_name in used:
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Missing expected Mixamo bone {bone_name}")
            bone.rotation_mode = "QUATERNION"
            angles = pose.get(bone_name, (0, 0, 0))
            bone.rotation_quaternion = Euler(tuple(radians(v) for v in angles), "XYZ").to_quaternion()
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
        hips = rig.pose.bones["mixamorig:Hips"]
        # The imported rig is 100 Blender units per metre and the Hips local
        # Y axis follows its bone length; this is the vertical displacement.
        hips.location = (0.0, float(pose.get("__hips_drop_m__", 0.0)) * 100.0, 0.0)
        hips.keyframe_insert("location", frame=frame, group="mixamorig:Hips")

    left = _empty(scene, "TEMP_GetUp_LeftHand", LEFT_HAND[START])
    right = _empty(scene, "TEMP_GetUp_RightHand", RIGHT_HAND[START])
    left_pole = _empty(scene, "TEMP_GetUp_LeftPole", (0.34, 0.22, 1.25))
    right_pole = _empty(scene, "TEMP_GetUp_RightPole", (-0.34, 0.22, 1.25))
    left_foot = _empty(scene, "TEMP_GetUp_LeftFoot", LEFT_FOOT[START])
    right_foot = _empty(scene, "TEMP_GetUp_RightFoot", RIGHT_FOOT[START])
    left_foot_pole = _empty(scene, "TEMP_GetUp_LeftFootPole", (0.28, -0.40, 0.48))
    right_foot_pole = _empty(scene, "TEMP_GetUp_RightFootPole", (-0.28, -0.40, 0.48))
    for name, target, pole in (
            ("mixamorig:LeftHand", left, left_pole),
            ("mixamorig:RightHand", right, right_pole),
            ("mixamorig:LeftFoot", left_foot, left_foot_pole),
            ("mixamorig:RightFoot", right_foot, right_foot_pole)):
        constraint = rig.pose.bones[name].constraints.new("IK")
        constraint.name = "TEMP_GetUp_IK_" + name.rsplit(":", 1)[-1]
        constraint.target = target
        constraint.pole_target = pole
        constraint.chain_count = 3
    _key_target(scene, left, LEFT_HAND)
    _key_target(scene, right, RIGHT_HAND)
    _key_target(scene, left_foot, LEFT_FOOT)
    _key_target(scene, right_foot, RIGHT_FOOT)

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    baked = bpy.ops.nla.bake(
        frame_start=START, frame_end=END, step=1, only_selected=True,
        visual_keying=True, clear_constraints=True, use_current_action=True,
        bake_types={"POSE"}, channel_types={"LOCATION", "ROTATION"},
        clean_curves=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if "FINISHED" not in baked:
        raise RuntimeError("Get-up hand-support IK bake failed")
    for frame in (25, 34, 43, 50, END):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for bone_name, expected in (("mixamorig:LeftFoot", LEFT_FOOT[frame]),
                                    ("mixamorig:RightFoot", RIGHT_FOOT[frame])):
            actual = rig.matrix_world @ rig.pose.bones[bone_name].tail
            if (actual - Vector(expected)).length > 0.05:
                raise RuntimeError(f"Get-up support-foot plant missed for {bone_name} at {frame}: {tuple(actual)}")
    for obj in (left, right, left_pole, right_pole, left_foot, right_foot,
                left_foot_pole, right_foot_pole):
        bpy.data.objects.remove(obj, do_unlink=True)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    action["source_note"] = "Original side-down recovery to ready stance; baked hand support, no root motion"
    return action


def main():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    rig = bpy.data.objects.get(RIG_NAME)
    if rig is None or len(rig.data.bones) != 65:
        raise RuntimeError("Expected validated 65-bone shared Y-Bot rig")
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.filepaths.save_version = 0
    action = author(rig, scene)
    scene.frame_start, scene.frame_end = START, END
    scene.timeline_markers.clear()
    for label, frame in (("LOW_SUPPORT", 8), ("KNEE_UNDER", 25),
                         ("HALF_KNEEL", 34), ("READY", END)):
        scene.timeline_markers.new(label, frame=frame)
    scene.frame_end = max(int(item.frame_range[1]) for item in bpy.data.actions)
    scene.frame_set(START)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(GLB), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_cameras=False,
        export_lights=False, export_animations=True, export_animation_mode="ACTIONS",
        export_skins=True, export_influence_nb=4, export_leaf_bone=False,
        export_rest_position_armature=True, export_force_sampling=True,
        export_frame_range=True, export_frame_step=1,
        export_optimize_animation_size=False)
    print(f"GETUP_CLIP action={action.name} frames={START}-{END} duration={(END-START)/FPS:.3f}s root_motion=none")
    print(f"GETUP_CLIP output={GLB} bytes={GLB.stat().st_size}")


if __name__ == "__main__":
    main()
