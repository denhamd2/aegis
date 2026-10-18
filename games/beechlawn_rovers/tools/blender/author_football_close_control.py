"""Author a subtle, loopable close-control footwork cycle for Y-Bot.

Run from repository root:
  blender -b --python games/beechlawn_rovers/tools/blender/author_football_close_control.py

It is visual footwork only. Player/root movement and the free rigid-body ball
remain owned by Godot. Temporary Blender IK is baked to bone curves.
"""
from pathlib import Path
from math import radians
import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
BLEND = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
RIG_NAME = "YBot_Armature"
ACTION_NAME = "AN_Beechlawn_CloseControl"
FPS = 60
START, END = 1, 60

POSES = {
    1: {},
    8: {"mixamorig:Hips": (3, -2, 0), "mixamorig:Spine": (-3, 1, 0),
        "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0),
        "__hips_z__": -0.025},
    15: {"mixamorig:Hips": (4, -3, 0), "mixamorig:Spine": (-4, 2, 0),
         "mixamorig:Spine1": (-2, 1, 0), "mixamorig:Head": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -7), "mixamorig:RightArm": (0, 0, 7),
         "mixamorig:LeftForeArm": (-9, 0, 0), "mixamorig:RightForeArm": (-9, 0, 0),
         "__hips_z__": -0.035},
    22: {"mixamorig:Hips": (3, -2, 0), "mixamorig:Spine": (-3, 1, 0),
         "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0),
         "__hips_z__": -0.025},
    30: {},
    38: {"mixamorig:Hips": (3, 2, 0), "mixamorig:Spine": (-3, -1, 0),
         "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, 7), "mixamorig:RightArm": (0, 0, -7),
         "mixamorig:LeftForeArm": (-9, 0, 0), "mixamorig:RightForeArm": (-9, 0, 0),
         "__hips_z__": -0.035},
    45: {"mixamorig:Hips": (4, 3, 0), "mixamorig:Spine": (-4, -2, 0),
         "mixamorig:Spine1": (-2, -1, 0), "mixamorig:Head": (1, 0, 0),
         "__hips_z__": -0.035},
    52: {"mixamorig:Hips": (3, 2, 0), "mixamorig:Spine": (-3, -1, 0),
         "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0),
         "__hips_z__": -0.02},
    END: {},
}

LEFT_FOOT = {
    1: (0.095, -0.113, 0.033), 8: (0.095, -0.113, 0.033),
    15: (0.15, -0.25, 0.055), 22: (0.15, -0.25, 0.033),
    30: (0.095, -0.113, 0.033), 38: (0.095, -0.113, 0.033),
    45: (0.095, -0.113, 0.033), 52: (0.095, -0.113, 0.033),
    END: (0.095, -0.113, 0.033),
}
RIGHT_FOOT = {
    1: (-0.095, -0.113, 0.033), 8: (-0.095, -0.113, 0.033),
    15: (-0.095, -0.113, 0.033), 22: (-0.095, -0.113, 0.033),
    30: (-0.095, -0.113, 0.033), 38: (-0.15, -0.25, 0.055),
    45: (-0.15, -0.25, 0.033), 52: (-0.095, -0.113, 0.033),
    END: (-0.095, -0.113, 0.033),
}
LEFT_HAND = {
    1: (0.34, -0.06, 0.98), 8: (0.36, -0.09, 1.00),
    15: (0.39, -0.10, 1.03), 22: (0.38, -0.08, 1.00),
    30: (0.34, -0.06, 0.98), 38: (0.31, -0.04, 1.02),
    45: (0.31, -0.04, 1.03), 52: (0.33, -0.05, 1.00),
    END: (0.34, -0.06, 0.98),
}
RIGHT_HAND = {
    frame: (-point[0], point[1], point[2])
    for frame, point in LEFT_HAND.items()
}


def make_empty(scene, name, location):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.location = Vector(location)
    return obj


def key_target(scene, obj, mapping):
    for frame, location in mapping.items():
        scene.frame_set(frame)
        obj.location = Vector(location)
        obj.keyframe_insert(data_path="location", frame=frame)
    for curve in obj.animation_data.action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"


def author(rig, scene):
    previous = bpy.data.actions.get(ACTION_NAME)
    if previous:
        bpy.data.actions.remove(previous)
    action = bpy.data.actions.new(ACTION_NAME)
    rig.animation_data_create()
    rig.animation_data.action = action
    used = {name for pose in POSES.values() for name in pose if not name.startswith("__")}
    for frame, pose in POSES.items():
        scene.frame_set(frame)
        for name in used:
            bone = rig.pose.bones.get(name)
            if bone is None:
                raise RuntimeError(f"Missing expected Mixamo bone {name}")
            bone.rotation_mode = "QUATERNION"
            angles = pose.get(name, (0, 0, 0))
            bone.rotation_quaternion = Euler(tuple(radians(x) for x in angles), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
        hips = rig.pose.bones["mixamorig:Hips"]
        hips.location = (0.0, 0.0, float(pose.get("__hips_z__", 0.0)))
        hips.keyframe_insert(data_path="location", frame=frame, group="mixamorig:Hips")

    controls = [
        make_empty(scene, "TEMP_Close_LeftFoot", LEFT_FOOT[START]),
        make_empty(scene, "TEMP_Close_RightFoot", RIGHT_FOOT[START]),
        make_empty(scene, "TEMP_Close_LeftFootPole", (0.28, -0.32, 0.48)),
        make_empty(scene, "TEMP_Close_RightFootPole", (-0.28, -0.32, 0.48)),
        make_empty(scene, "TEMP_Close_LeftHand", LEFT_HAND[START]),
        make_empty(scene, "TEMP_Close_RightHand", RIGHT_HAND[START]),
        make_empty(scene, "TEMP_Close_LeftHandPole", (0.30, 0.24, 1.25)),
        make_empty(scene, "TEMP_Close_RightHandPole", (-0.30, 0.24, 1.25)),
    ]
    for bone, target, pole in (
            ("mixamorig:LeftFoot", controls[0], controls[2]),
            ("mixamorig:RightFoot", controls[1], controls[3]),
            ("mixamorig:LeftHand", controls[4], controls[6]),
            ("mixamorig:RightHand", controls[5], controls[7])):
        constraint = rig.pose.bones[bone].constraints.new("IK")
        constraint.name = "TEMP_CloseIK_" + bone.rsplit(":", 1)[-1]
        constraint.target = target
        constraint.pole_target = pole
        constraint.chain_count = 3
    for target, mapping in ((controls[0], LEFT_FOOT), (controls[1], RIGHT_FOOT),
                            (controls[4], LEFT_HAND), (controls[5], RIGHT_HAND)):
        key_target(scene, target, mapping)

    for frame in (1, 30, END):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for bone_name, expected in (("mixamorig:LeftFoot", LEFT_FOOT[frame]),
                                    ("mixamorig:RightFoot", RIGHT_FOOT[frame])):
            actual = rig.matrix_world @ rig.pose.bones[bone_name].tail
            if (actual - Vector(expected)).length > 0.04:
                raise RuntimeError(f"Close-control cycle foot plant missed for {bone_name}: {tuple(actual)}")

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
        raise RuntimeError("Close-control IK bake failed")
    for obj in controls:
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.frame_set(START)
    bpy.context.view_layer.update()
    start_pose = {bone.name: (bone.matrix.copy(), bone.matrix.to_quaternion())
                  for bone in rig.pose.bones}
    scene.frame_set(END)
    bpy.context.view_layer.update()
    for bone in rig.pose.bones:
        start_matrix, start_rotation = start_pose[bone.name]
        if (bone.matrix.translation - start_matrix.translation).length > 0.025 \
				or bone.matrix.to_quaternion().rotation_difference(start_rotation).angle > radians(3.0):
            raise RuntimeError(f"Close-control loop seam pops on {bone.name}")
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    action["source_note"] = "Original close-control footwork loop; stationary root, alternating small touches"
    return action


def main():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    rig = bpy.data.objects.get(RIG_NAME)
    if rig is None or len(rig.data.bones) != 65:
        raise RuntimeError("Expected validated 65-bone shared Y-Bot rig")
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = START, END
    bpy.context.preferences.filepaths.save_version = 0
    action = author(rig, scene)
    scene.timeline_markers.clear()
    scene.timeline_markers.new("LOOP_WRAP", frame=END)
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
    print(f"CLOSE_CONTROL_CLIP action={action.name} frames={START}-{END} duration={(END-START)/FPS:.3f}s loop=yes root_motion=none")
    print(f"CLOSE_CONTROL_CLIP output={GLB} bytes={GLB.stat().st_size}")


if __name__ == "__main__":
    main()
