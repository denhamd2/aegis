"""Author a measured, in-place Y-Bot instep-pass clip with IK foot planting.

Run from the repository root:
  blender -b tools/blender/beechlawn/y_bot_animation_set.blend \
    --python games/beechlawn_rovers/tools/blender/author_football_kick.py

The CMU 10_03 capture is a timing/arc reference, not directly retargeted: the
BVH and Mixamo skeleton rest axes are incompatible, and a direct global-rotation
transfer visibly collapsed the pose. Temporary Blender IK targets are baked to
ordinary bone curves and removed before export. Godot remains authoritative for
player/root movement, input, ball simulation, and the actual kick impulse.
"""
from pathlib import Path
from math import radians
import json
import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "tools/blender/beechlawn/y_bot_animation_set.blend"
BLEND_OUT = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
EVENTS_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_pass_contact.json"
ARMATURE_NAME = "YBot_Armature"
FPS = 60
FRAME_START = 1
FRAME_END = 54
CONTACT_FRAME = 24

# A right-footed instep pass: support plant/load, backswing, drive/contact,
# follow-through, and recovery. Foot and hand coordinates are in world metres.
# The support foot stays locked through the contact window to avoid sliding.
LEFT_FOOT = {
    1: (0.095, -0.113, 0.033), 7: (0.095, -0.113, 0.033),
    13: (0.095, -0.113, 0.033), 18: (0.095, -0.113, 0.033),
    24: (0.095, -0.113, 0.033), 29: (0.095, -0.113, 0.033),
    36: (0.095, -0.113, 0.033), 44: (0.095, -0.113, 0.033),
    54: (0.095, -0.113, 0.033),
}
RIGHT_FOOT = {
    1: (-0.095, -0.113, 0.033),
    7: (-0.095, 0.12, 0.08),       # controlled backswing
    13: (-0.095, 0.24, 0.10),      # loaded, knee flexed
    18: (-0.085, 0.05, 0.08),      # accelerate toward the ball
    24: (-0.115, -0.48, 0.14),     # toe-base at ball contact
    29: (-0.14, -0.68, 0.24),      # follow-through through the ball
    36: (-0.16, -0.52, 0.36),      # controlled recoil/recovery arc
    44: (-0.10, -0.18, 0.12),
    54: (-0.095, -0.113, 0.033),
}

# Hands counterbalance the kick without retaining the imported T-pose. Elbows
# are solved with pole targets, then the IK is baked and removed.
LEFT_HAND = {
    1: (0.36, -0.06, 1.16), 7: (0.38, -0.18, 1.22),
    13: (0.42, -0.18, 1.22), 18: (0.44, -0.08, 1.24),
    24: (0.43, 0.00, 1.22), 29: (0.42, 0.00, 1.24),
    36: (0.39, -0.04, 1.20), 44: (0.36, -0.06, 1.16),
    54: (0.36, -0.06, 1.16),
}
RIGHT_HAND = {
    1: (-0.36, -0.06, 1.16), 7: (-0.40, 0.05, 1.18),
    13: (-0.44, 0.12, 1.20), 18: (-0.46, -0.10, 1.22),
    24: (-0.43, -0.22, 1.24), 29: (-0.42, -0.25, 1.28),
    36: (-0.39, -0.06, 1.20), 44: (-0.36, -0.06, 1.16),
    54: (-0.36, -0.06, 1.16),
}

# Body anticipation and follow-through in local degrees. Rotation X leans over
# the ball; rotation Y adds a restrained hip/spine turn. Root translation stays
# fixed so these clips remain compatible with CharacterBody locomotion.
BODY_POSES = {
    1: {},
    7: {"mixamorig:Hips": (1, -3, 0), "mixamorig:Spine": (-2, 0, 0),
        "mixamorig:Spine1": (-1, 0, 0), "mixamorig:Head": (1, 0, 0)},
    13: {"mixamorig:Hips": (2, -7, 0), "mixamorig:Spine": (-4, 2, 0),
         "mixamorig:Spine1": (-2, 1, 0), "mixamorig:Spine2": (-1, 0, 0),
         "mixamorig:Head": (2, 0, 0)},
    18: {"mixamorig:Hips": (0, -2, 0), "mixamorig:Spine": (1, 0, 0),
         "mixamorig:Spine1": (1, 0, 0), "mixamorig:Head": (0, 0, 0)},
    CONTACT_FRAME: {"mixamorig:Hips": (-1, 5, 0), "mixamorig:Spine": (4, -2, 0),
                    "mixamorig:Spine1": (2, -1, 0), "mixamorig:Spine2": (1, 0, 0),
                    "mixamorig:Head": (-1, 0, 0)},
    29: {"mixamorig:Hips": (-1, 7, 0), "mixamorig:Spine": (5, -2, 0),
         "mixamorig:Spine1": (2, -1, 0), "mixamorig:Spine2": (1, 0, 0),
         "mixamorig:Head": (-2, 0, 0)},
    36: {"mixamorig:Hips": (1, 3, 0), "mixamorig:Spine": (2, 0, 0),
         "mixamorig:Spine1": (1, 0, 0), "mixamorig:Head": (-1, 0, 0)},
    44: {"mixamorig:Hips": (0, 1, 0), "mixamorig:Spine": (1, 0, 0)},
    FRAME_END: {},
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


def add_ik(rig, bone_name, target, pole, constraint_name):
    constraint = rig.pose.bones[bone_name].constraints.new("IK")
    constraint.name = constraint_name
    constraint.target = target
    constraint.pole_target = pole
    constraint.chain_count = 3
    constraint.pole_angle = 0.0
    return constraint


def bake_clip(rig, scene):
    action_name = "AN_Beechlawn_PassRight"
    old = bpy.data.actions.get(action_name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(action_name)
    rig.animation_data_create()
    rig.animation_data.action = action

    scene.frame_set(FRAME_START)
    for frame, pose in BODY_POSES.items():
        scene.frame_set(frame)
        for bone_name, degrees in pose.items():
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Missing expected Y-Bot bone: {bone_name}")
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = Euler(tuple(radians(value) for value in degrees), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone_name)

    left_foot = add_empty(scene, "TEMP_CTRL_LeftFoot", LEFT_FOOT[FRAME_START])
    right_foot = add_empty(scene, "TEMP_CTRL_RightFoot", RIGHT_FOOT[FRAME_START])
    left_foot_pole = add_empty(scene, "TEMP_POLE_LeftFoot", (0.28, -0.32, 0.48))
    right_foot_pole = add_empty(scene, "TEMP_POLE_RightFoot", (-0.28, -0.32, 0.48))
    left_hand = add_empty(scene, "TEMP_CTRL_LeftHand", LEFT_HAND[FRAME_START])
    right_hand = add_empty(scene, "TEMP_CTRL_RightHand", RIGHT_HAND[FRAME_START])
    left_hand_pole = add_empty(scene, "TEMP_POLE_LeftHand", (0.30, 0.24, 1.25))
    right_hand_pole = add_empty(scene, "TEMP_POLE_RightHand", (-0.30, 0.24, 1.25))

    add_ik(rig, "mixamorig:LeftFoot", left_foot, left_foot_pole, "TEMP_IK_LeftFoot")
    add_ik(rig, "mixamorig:RightFoot", right_foot, right_foot_pole, "TEMP_IK_RightFoot")
    add_ik(rig, "mixamorig:LeftHand", left_hand, left_hand_pole, "TEMP_IK_LeftHand")
    add_ik(rig, "mixamorig:RightHand", right_hand, right_hand_pole, "TEMP_IK_RightHand")
    for control, key_data in ((left_foot, LEFT_FOOT), (right_foot, RIGHT_FOOT),
                              (left_hand, LEFT_HAND), (right_hand, RIGHT_HAND)):
        key_target(control, key_data)

    scene.frame_set(CONTACT_FRAME)
    bpy.context.view_layer.update()
    # Lightweight checks guard the key events: support toe stays on the turf;
    # the kicking foot reaches the measured contact point without root motion.
    support_tail = rig.matrix_world @ rig.pose.bones["mixamorig:LeftFoot"].tail
    kick_tail = rig.matrix_world @ rig.pose.bones["mixamorig:RightFoot"].tail
    if abs(support_tail.z - LEFT_FOOT[CONTACT_FRAME][2]) > 0.015:
        raise RuntimeError(f"Support foot lost its plant: {tuple(support_tail)}")
    expected = Vector(RIGHT_FOOT[CONTACT_FRAME])
    if (kick_tail - expected).length > 0.02:
        raise RuntimeError(f"Kick contact target missed: got {tuple(kick_tail)}, wanted {tuple(expected)}")

    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    for obj in bpy.context.selected_objects:
        if obj != rig:
            obj.select_set(False)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    result = bpy.ops.nla.bake(
        frame_start=FRAME_START, frame_end=FRAME_END, step=1,
        only_selected=True, visual_keying=True, clear_constraints=True,
        use_current_action=True, bake_types={"POSE"},
        channel_types={"LOCATION", "ROTATION"}, clean_curves=False,
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    if "FINISHED" not in result:
        raise RuntimeError(f"Pose bake failed: {result}")
    for control in (left_foot, right_foot, left_foot_pole, right_foot_pole,
                    left_hand, right_hand, left_hand_pole, right_hand_pole):
        bpy.data.objects.remove(control, do_unlink=True)
    action.use_fake_user = True
    action["ball_contact_frame"] = CONTACT_FRAME
    action["source_note"] = "Original Y-Bot keyed animation; CMU 10_03 used as movement reference only"
    # Keep the already-authored locomotion and defensive clips in the runtime
    # library, but remove the source FBX's empty placeholder action.
    for other in list(bpy.data.actions):
        if other.name.startswith("Armature|mixamo.com|Layer0"):
            bpy.data.actions.remove(other)
    return action


def resample_existing_actions_to_60fps():
    """Preserve seconds while exporting the existing 30 fps clips at 60 fps."""
    for existing in bpy.data.actions:
        if existing.name == "AN_Beechlawn_PassRight":
            continue
        for curve in existing.fcurves:
            for key in curve.keyframe_points:
                key.co.x *= 2.0
                key.handle_left.x *= 2.0
                key.handle_right.x *= 2.0
            curve.update()


def main():
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig = bpy.data.objects.get(ARMATURE_NAME)
    if rig is None or len(rig.data.bones) != 65:
        raise RuntimeError("Expected the validated 65-bone YBot_Armature")
    scene = bpy.context.scene
    resample_existing_actions_to_60fps()
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = FRAME_START, FRAME_END
    scene.frame_set(FRAME_START)
    bpy.context.preferences.filepaths.save_version = 0
    action = bake_clip(rig, scene)
    # ACTIONS export still respects the scene's frame range, so include the
    # longest retained clip (the 60 fps idle is longer than this pass).
    scene.frame_start = FRAME_START
    scene.frame_end = max(int(a.frame_range[1]) for a in bpy.data.actions)
    scene.frame_set(FRAME_START)
    scene.timeline_markers.clear()
    scene.timeline_markers.new("BALL_CONTACT", frame=CONTACT_FRAME)

    BLEND_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))

    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    GLB_OUT.parent.mkdir(parents=True, exist_ok=True)
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
    duration = FRAME_END / FPS
    contact_time = CONTACT_FRAME / FPS
    EVENTS_OUT.write_text(json.dumps({
        "clip": action.name,
        "event": "ball_contact",
        "frame": CONTACT_FRAME,
        "fps": FPS,
        "time_seconds": contact_time,
    }, indent=2) + "\n")
    print(f"KICK_CLIP action={action.name} fps={FPS} frames={FRAME_START}-{FRAME_END} "
          f"contact_frame={CONTACT_FRAME} contact_time={contact_time:.3f}s duration={duration:.3f}s")
    print(f"KICK_CLIP output={GLB_OUT} bytes={GLB_OUT.stat().st_size}")
    print(f"KICK_CLIP event_metadata={EVENTS_OUT}")


if __name__ == "__main__":
    main()
