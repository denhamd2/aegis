"""Add mirrored, in-place 90-degree deceleration turns to the Y-Bot library.

Run from the repository root:
  blender -b --python games/beechlawn_rovers/tools/blender/author_football_turns.py

The character root remains Godot-authoritative. These short authored steps
only add anticipation, a support-leg catch, body counter-rotation and recovery.
"""
from pathlib import Path
from math import radians
import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
BLEND = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
RIG_NAME = "YBot_Armature"
FPS = 60
START, END = 1, 37  # 0.6 s sampled at 60 Hz


def make_turn(rig, scene, name, direction):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = action

    # Both turns share the same readable rhythm. The lead side changes to
    # match the turn direction; no armature/object root yaw is animated.
    # Values are local degrees for Mixamo's Hips/Spine/leg bones.
    poses = {
        1: {},
        5: {"mixamorig:Hips": (3, -direction * 3, 0),
            "mixamorig:Spine": (-2, direction * 2, 0),
            "mixamorig:LeftArm": (0, 0, -7), "mixamorig:RightArm": (0, 0, 7)},
        10: {"mixamorig:Hips": (7, -direction * 8, 0),
             "mixamorig:Spine": (-5, direction * 4, 0),
             "mixamorig:Spine1": (-2, direction * 2, 0),
             "mixamorig:Head": (1, 0, 0),
             "mixamorig:LeftArm": (0, 0, -12), "mixamorig:RightArm": (0, 0, 12),
             "mixamorig:LeftForeArm": (-8, 0, 0), "mixamorig:RightForeArm": (-8, 0, 0),
             "mixamorig:LeftUpLeg": (direction * 5, 0, 0),
             "mixamorig:RightUpLeg": (-direction * 8, 0, 0),
             "mixamorig:RightLeg": (14, 0, 0), "__hips_z__": -0.035},
        15: {"mixamorig:Hips": (10, -direction * 14, 0),
             "mixamorig:Spine": (-7, direction * 8, 0),
             "mixamorig:Spine1": (-3, direction * 4, 0),
             "mixamorig:Head": (2, 0, 0),
             "mixamorig:LeftArm": (0, 0, -17), "mixamorig:RightArm": (0, 0, 17),
             "mixamorig:LeftForeArm": (-12, 0, 0), "mixamorig:RightForeArm": (-12, 0, 0),
             "mixamorig:LeftUpLeg": (direction * 8, 0, 0),
             "mixamorig:RightUpLeg": (-direction * 14, 0, 0),
             "mixamorig:RightLeg": (22, 0, 0), "__hips_z__": -0.055},
        21: {"mixamorig:Hips": (5, -direction * 8, 0),
             "mixamorig:Spine": (-3, direction * 4, 0),
             "mixamorig:Spine1": (-1, direction * 2, 0),
             "mixamorig:Head": (1, 0, 0),
             "mixamorig:LeftArm": (0, 0, -12), "mixamorig:RightArm": (0, 0, 12),
             "mixamorig:LeftUpLeg": (-direction * 3, 0, 0),
             "mixamorig:RightUpLeg": (direction * 5, 0, 0),
             "mixamorig:RightLeg": (8, 0, 0), "__hips_z__": -0.025},
        28: {"mixamorig:Hips": (1, -direction * 2, 0),
             "mixamorig:Spine": (-1, direction, 0),
             "mixamorig:LeftArm": (0, 0, -5), "mixamorig:RightArm": (0, 0, 5),
             "__hips_z__": -0.008},
        END: {},
    }
    used = {bone for pose in poses.values() for bone in pose if not bone.startswith("__")}
    for frame, pose in poses.items():
        scene.frame_set(frame)
        for bone_name in used:
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Missing Mixamo bone {bone_name}")
            bone.rotation_mode = "QUATERNION"
            euler_degrees = pose.get(bone_name, (0, 0, 0))
            bone.rotation_quaternion = Euler(tuple(radians(v) for v in euler_degrees), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone_name)
        hips = rig.pose.bones["mixamorig:Hips"]
        hips.location = (0.0, 0.0, float(pose.get("__hips_z__", 0.0)))
        hips.keyframe_insert(data_path="location", frame=frame, group="mixamorig:Hips")

    # Lock the support foot through the loaded pivot, then bake the constraint
    # to ordinary bone curves so the Godot runtime has no IK cost.
    support_name = "mixamorig:LeftFoot" if direction < 0 else "mixamorig:RightFoot"
    support_point = (0.095, -0.113, 0.033) if direction < 0 else (-0.095, -0.113, 0.033)
    target = bpy.data.objects.new("TEMP_TurnSupportFoot", None)
    pole = bpy.data.objects.new("TEMP_TurnSupportPole", None)
    scene.collection.objects.link(target)
    scene.collection.objects.link(pole)
    target.location = Vector(support_point)
    pole.location = Vector((0.28 if direction < 0 else -0.28, -0.32, 0.48))
    constraint = rig.pose.bones[support_name].constraints.new("IK")
    constraint.name = "TEMP_TurnSupportIK"
    constraint.target = target
    constraint.pole_target = pole
    constraint.chain_count = 3
    # This one-shot action overrides the locomotion blend entirely, so key a
    # relaxed ready-arm silhouette too. Temporary hand IK supplies deliberate
    # hand positions and is baked together with the support-leg plant.
    left_hand = bpy.data.objects.new("TEMP_TurnLeftHand", None)
    right_hand = bpy.data.objects.new("TEMP_TurnRightHand", None)
    left_hand_pole = bpy.data.objects.new("TEMP_TurnLeftHandPole", None)
    right_hand_pole = bpy.data.objects.new("TEMP_TurnRightHandPole", None)
    for obj in (left_hand, right_hand, left_hand_pole, right_hand_pole):
        scene.collection.objects.link(obj)
    hand_keys = {
        1: (0.34, -0.06, 0.98), 5: (0.38, -0.08, 1.03),
        10: (0.46, -0.10, 1.12), 15: (0.50, -0.10, 1.16),
        21: (0.43, -0.08, 1.08), 28: (0.37, -0.06, 1.00),
        END: (0.34, -0.06, 0.98),
    }
    for frame, point in hand_keys.items():
        scene.frame_set(frame)
        # The turn side opens its arm slightly while the other arm checks the
        # torso rotation; keep both hands below shoulder height.
        opening = direction * (0.035 if frame in (10, 15) else 0.0)
        left_hand.location = Vector((point[0] + opening, point[1], point[2]))
        right_hand.location = Vector((-point[0] + opening, point[1], point[2]))
        for obj in (left_hand, right_hand):
            obj.keyframe_insert(data_path="location", frame=frame)
    for obj in (left_hand, right_hand):
        for curve in obj.animation_data.action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = "BEZIER"
                key.handle_left_type = "AUTO_CLAMPED"
                key.handle_right_type = "AUTO_CLAMPED"
    left_hand_pole.location = Vector((0.35, 0.22, 1.25))
    right_hand_pole.location = Vector((-0.35, 0.22, 1.25))
    for bone_name, hand_target, hand_pole in (
            ("mixamorig:LeftHand", left_hand, left_hand_pole),
            ("mixamorig:RightHand", right_hand, right_hand_pole)):
        hand_ik = rig.pose.bones[bone_name].constraints.new("IK")
        hand_ik.name = "TEMP_TurnHandIK_" + bone_name.rsplit(":", 1)[-1]
        hand_ik.target = hand_target
        hand_ik.pole_target = hand_pole
        hand_ik.chain_count = 3
    bpy.context.view_layer.update()
    planted = rig.matrix_world @ rig.pose.bones[support_name].tail
    if (planted - Vector(support_point)).length > 0.035:
        raise RuntimeError(f"Turn support-foot plant missed: {tuple(planted)}")
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
        raise RuntimeError(f"Turn support-foot bake failed for {name}")
    bpy.data.objects.remove(target, do_unlink=True)
    bpy.data.objects.remove(pole, do_unlink=True)
    for obj in (left_hand, right_hand, left_hand_pole, right_hand_pole):
        bpy.data.objects.remove(obj, do_unlink=True)

    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    action["source_note"] = "Original in-place 90-degree deceleration turn; mirrored left/right, no root motion"
    return action


def main():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    rig = bpy.data.objects.get(RIG_NAME)
    if rig is None or len(rig.data.bones) != 65:
        raise RuntimeError("Expected validated 65-bone shared Y-Bot rig")
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.filepaths.save_version = 0
    make_turn(rig, scene, "AN_Beechlawn_Turn90Left", -1)
    make_turn(rig, scene, "AN_Beechlawn_Turn90Right", 1)
    scene.frame_end = max(int(a.frame_range[1]) for a in bpy.data.actions)
    scene.frame_set(1)
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
    for name in ("AN_Beechlawn_Turn90Left", "AN_Beechlawn_Turn90Right"):
        action = bpy.data.actions[name]
        print(f"TURN_CLIP action={name} frames={START}-{END} duration={(END-START)/FPS:.3f}s root_motion=none")
    print(f"TURN_CLIPS output={GLB} bytes={GLB.stat().st_size}")


if __name__ == "__main__":
    main()
