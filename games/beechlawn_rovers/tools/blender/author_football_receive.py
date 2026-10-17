"""Author a cushioned right-foot receive on the shared Y-Bot proxy rig.

Run from the repository root:
  blender -b --python games/beechlawn_rovers/tools/blender/author_football_receive.py

This is an in-place blocking clip. Blender IK is baked into ordinary bone
curves and removed; Godot retains player motion and ball physics authority.
"""
from pathlib import Path
import json
import bpy
from math import radians
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
LIBRARY = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
EVENT_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_receive_contact.json"
ARMATURE_NAME = "YBot_Armature"
ACTION_NAME = "AN_Beechlawn_ReceiveRight"
FPS = 60
START = 1
END = 42
CONTACT = 20

# A right-foot receive: small readiness shift, reach without a giant leg swing,
# soft withdrawal at impact, then a balanced reset. The Y-Bot front faces
# Blender -Y. GLTF maps that to Godot +Z; the reusable rig's 180-degree local
# correction aligns it with the game's -Z forward axis.
LEFT_FOOT = {
    1: (0.095, -0.113, 0.033), 6: (0.095, -0.113, 0.033),
    12: (0.095, -0.113, 0.033), 17: (0.095, -0.113, 0.033),
    20: (0.095, -0.113, 0.033), 22: (0.095, -0.113, 0.033),
    26: (0.095, -0.113, 0.033), 33: (0.095, -0.113, 0.033),
    END: (0.095, -0.113, 0.033),
}
RIGHT_FOOT = {
    1: (-0.095, -0.113, 0.033),
    6: (-0.095, -0.13, 0.04),
    12: (-0.11, -0.29, 0.085),
    17: (-0.05, -0.41, 0.11),
    CONTACT: (0.05, -0.49, 0.08),
    22: (0.04, -0.43, 0.085),
    26: (-0.02, -0.35, 0.055),
    33: (-0.11, -0.19, 0.035),
    END: (-0.095, -0.113, 0.033),
}
LEFT_HAND = {
    1: (0.36, -0.06, 1.16), 6: (0.38, -0.03, 1.19),
    12: (0.43, 0.00, 1.23), 17: (0.46, 0.03, 1.24),
    CONTACT: (0.47, 0.04, 1.24), 22: (0.46, 0.04, 1.23),
    26: (0.42, -0.02, 1.20), 33: (0.38, -0.05, 1.17),
    END: (0.36, -0.06, 1.16),
}
RIGHT_HAND = {
    1: (-0.36, -0.06, 1.16), 6: (-0.39, -0.04, 1.18),
    12: (-0.43, 0.01, 1.20), 17: (-0.45, 0.04, 1.21),
    CONTACT: (-0.46, 0.06, 1.21), 22: (-0.44, 0.04, 1.20),
    26: (-0.40, -0.02, 1.18), 33: (-0.37, -0.05, 1.16),
    END: (-0.36, -0.06, 1.16),
}
BODY_POSES = {
    1: {},
    6: {"mixamorig:Hips": (0, 0, 0), "mixamorig:Spine": (-1, 0, 0),
        "mixamorig:Head": (1, 0, 0)},
    12: {"mixamorig:Hips": (1, -3, 0), "mixamorig:Spine": (-3, 1, 0),
         "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (2, 0, 0)},
    17: {"mixamorig:Hips": (1, -4, 0), "mixamorig:Spine": (-4, 1, 0),
         "mixamorig:Spine1": (-2, 0, 0), "mixamorig:Spine2": (-1, 0, 0),
         "mixamorig:Head": (2, 0, 0)},
    CONTACT: {"mixamorig:Hips": (2, -2, 0), "mixamorig:Spine": (-5, 1, 0),
              "mixamorig:Spine1": (-2, 0, 0), "mixamorig:Spine2": (-1, 0, 0),
              "mixamorig:Head": (2, 0, 0)},
    22: {"mixamorig:Hips": (1, -1, 0), "mixamorig:Spine": (-4, 1, 0),
         "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0)},
    26: {"mixamorig:Hips": (0, 1, 0), "mixamorig:Spine": (-2, 0, 0),
         "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0)},
    33: {"mixamorig:Hips": (0, 0, 0), "mixamorig:Spine": (-1, 0, 0)},
    END: {},
}


def add_empty(scene, name, location):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.empty_display_type = "SPHERE"
    obj.empty_display_size = 0.025
    obj.location = Vector(location)
    return obj


def key_target(obj, pose_map):
    for frame, location in pose_map.items():
        bpy.context.scene.frame_set(frame)
        obj.location = Vector(location)
        obj.keyframe_insert(data_path="location", frame=frame)
    for curve in obj.animation_data.action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"


def add_ik(rig, bone_name, target, pole, label):
    constraint = rig.pose.bones[bone_name].constraints.new("IK")
    constraint.name = label
    constraint.target = target
    constraint.pole_target = pole
    constraint.chain_count = 3
    constraint.pole_angle = 0.0


def author(rig, scene):
    previous = bpy.data.actions.get(ACTION_NAME)
    if previous:
        bpy.data.actions.remove(previous)
    action = bpy.data.actions.new(ACTION_NAME)
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame, pose in BODY_POSES.items():
        scene.frame_set(frame)
        for bone_name, angles in pose.items():
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Missing expected Y-Bot bone: {bone_name}")
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = Euler(tuple(radians(v) for v in angles), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone_name)

    left = add_empty(scene, "TEMP_Receive_LeftFoot", LEFT_FOOT[START])
    right = add_empty(scene, "TEMP_Receive_RightFoot", RIGHT_FOOT[START])
    left_pole = add_empty(scene, "TEMP_Receive_LeftPole", (0.28, -0.32, 0.48))
    right_pole = add_empty(scene, "TEMP_Receive_RightPole", (-0.28, 0.34, 0.48))
    left_hand = add_empty(scene, "TEMP_Receive_LeftHand", LEFT_HAND[START])
    right_hand = add_empty(scene, "TEMP_Receive_RightHand", RIGHT_HAND[START])
    left_hand_pole = add_empty(scene, "TEMP_Receive_LeftHandPole", (0.30, 0.24, 1.25))
    right_hand_pole = add_empty(scene, "TEMP_Receive_RightHandPole", (-0.30, 0.24, 1.25))
    add_ik(rig, "mixamorig:LeftFoot", left, left_pole, "TEMP_Receive_IK_LeftFoot")
    add_ik(rig, "mixamorig:RightFoot", right, right_pole, "TEMP_Receive_IK_RightFoot")
    add_ik(rig, "mixamorig:LeftHand", left_hand, left_hand_pole, "TEMP_Receive_IK_LeftHand")
    add_ik(rig, "mixamorig:RightHand", right_hand, right_hand_pole, "TEMP_Receive_IK_RightHand")
    for target, keys in ((left, LEFT_FOOT), (right, RIGHT_FOOT),
                         (left_hand, LEFT_HAND), (right_hand, RIGHT_HAND)):
        key_target(target, keys)

    scene.frame_set(CONTACT)
    bpy.context.view_layer.update()
    support = rig.matrix_world @ rig.pose.bones["mixamorig:LeftFoot"].tail
    receive_foot = rig.matrix_world @ rig.pose.bones["mixamorig:RightFoot"].tail
    if abs(support.z - LEFT_FOOT[CONTACT][2]) > 0.015:
        raise RuntimeError(f"Support foot lost its plant: {tuple(support)}")
    if (receive_foot - Vector(RIGHT_FOOT[CONTACT])).length > 0.02:
        raise RuntimeError(f"Receive foot missed target: {tuple(receive_foot)}")

    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    for obj in bpy.context.selected_objects:
        if obj != rig:
            obj.select_set(False)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    baked = bpy.ops.nla.bake(
        frame_start=START, frame_end=END, step=1,
        only_selected=True, visual_keying=True, clear_constraints=True,
        use_current_action=True, bake_types={"POSE"},
        channel_types={"LOCATION", "ROTATION"}, clean_curves=False,
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    if "FINISHED" not in baked:
        raise RuntimeError("First-touch bake failed")
    for obj in (left, right, left_pole, right_pole, left_hand, right_hand,
                left_hand_pole, right_hand_pole):
        bpy.data.objects.remove(obj, do_unlink=True)
    action.use_fake_user = True
    action["ball_contact_frame"] = CONTACT
    action["source_note"] = "Original Y-Bot controlled first-touch blocking clip"
    return action


def main():
    if not LIBRARY.is_file():
        raise FileNotFoundError(LIBRARY)
    bpy.ops.wm.open_mainfile(filepath=str(LIBRARY))
    rig = bpy.data.objects.get(ARMATURE_NAME)
    if rig is None or len(rig.data.bones) != 65:
        raise RuntimeError("Expected the verified 65-bone Y-Bot rig")
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = START, END
    bpy.context.preferences.filepaths.save_version = 0
    action = author(rig, scene)
    scene.frame_end = max(int(item.frame_range[1]) for item in bpy.data.actions)
    scene.frame_set(START)
    scene.timeline_markers.clear()
    scene.timeline_markers.new("BALL_CONTACT", frame=CONTACT)
    bpy.ops.wm.save_as_mainfile(filepath=str(LIBRARY))

    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_OUT), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_cameras=False,
        export_lights=False, export_animations=True,
        export_animation_mode="ACTIONS", export_skins=True,
        export_influence_nb=4, export_leaf_bone=False,
        export_rest_position_armature=True, export_force_sampling=True,
        export_frame_range=True, export_frame_step=1,
        export_optimize_animation_size=False,
    )
    EVENT_OUT.write_text(json.dumps({
        "clip": ACTION_NAME, "event": "ball_contact",
        "frame": CONTACT, "fps": FPS, "time_seconds": CONTACT / FPS,
    }, indent=2) + "\n")
    print(f"RECEIVE_CLIP action={ACTION_NAME} contact={CONTACT / FPS:.3f}s duration={END / FPS:.3f}s")
    print(f"RECEIVE_CLIP output={GLB_OUT} bytes={GLB_OUT.stat().st_size}")


if __name__ == "__main__":
    main()
