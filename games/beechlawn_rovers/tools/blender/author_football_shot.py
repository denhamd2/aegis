"""Author an in-place, event-marked instep shot on the shared Y-Bot rig.

Run from repository root:
  blender -b --python games/beechlawn_rovers/tools/blender/author_football_shot.py

The clip supplies the visible strike only. Godot owns player/root movement,
shot direction, power, and the physical ball impulse at the contact marker.
Temporary Blender IK is baked to bone curves before the GLB export.
"""
from pathlib import Path
from math import radians
import json
import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
BLEND = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
EVENTS = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_shot_contact.json"
RIG_NAME = "YBot_Armature"
ACTION_NAME = "AN_Beechlawn_ShotRight"
FPS = 60
START, CONTACT, END = 1, 18, 54

LEFT_FOOT = {
    1: (0.095, -0.113, 0.033), 5: (0.095, -0.113, 0.033),
    10: (0.095, -0.113, 0.033), 14: (0.095, -0.113, 0.033),
    CONTACT: (0.095, -0.113, 0.033), 22: (0.095, -0.113, 0.033),
    30: (0.095, -0.113, 0.033), 40: (0.095, -0.113, 0.033),
    END: (0.095, -0.113, 0.033),
}
RIGHT_FOOT = {
    1: (-0.095, -0.113, 0.033), 5: (-0.095, 0.10, 0.07),
    10: (-0.095, 0.23, 0.12), 14: (-0.07, 0.02, 0.08),
    CONTACT: (0.014, -0.519, 0.096), 22: (-0.14, -0.75, 0.24),
    30: (-0.16, -0.59, 0.36), 40: (-0.10, -0.18, 0.12),
    END: (-0.095, -0.113, 0.033),
}
LEFT_HAND = {
    1: (0.36, -0.06, 1.16), 5: (0.39, -0.12, 1.20),
    10: (0.43, -0.16, 1.23), 14: (0.46, -0.05, 1.24),
    CONTACT: (0.43, 0.00, 1.22), 22: (0.42, 0.02, 1.26),
    30: (0.39, -0.02, 1.20), 40: (0.36, -0.06, 1.16),
    END: (0.36, -0.06, 1.16),
}
RIGHT_HAND = {
    1: (-0.36, -0.06, 1.16), 5: (-0.41, 0.04, 1.20),
    10: (-0.47, 0.13, 1.23), 14: (-0.49, -0.08, 1.22),
    CONTACT: (-0.43, -0.22, 1.24), 22: (-0.42, -0.25, 1.28),
    30: (-0.39, -0.06, 1.20), 40: (-0.36, -0.06, 1.16),
    END: (-0.36, -0.06, 1.16),
}
POSES = {
    1: {},
    5: {"mixamorig:Hips": (2, -3, 0), "mixamorig:Spine": (-2, 1, 0),
        "mixamorig:LeftArm": (0, 0, -5), "mixamorig:RightArm": (0, 0, 5)},
    10: {"mixamorig:Hips": (7, -8, 0), "mixamorig:Spine": (-5, 4, 0),
         "mixamorig:Spine1": (-2, 2, 0), "mixamorig:Head": (2, 0, 0),
         "mixamorig:LeftArm": (0, 0, -12), "mixamorig:RightArm": (0, 0, 12),
         "mixamorig:LeftForeArm": (-8, 0, 0), "mixamorig:RightForeArm": (-8, 0, 0),
         "__hips_z__": -0.035},
    14: {"mixamorig:Hips": (4, -4, 0), "mixamorig:Spine": (-2, 2, 0),
         "mixamorig:Spine1": (-1, 1, 0), "mixamorig:Head": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -15), "mixamorig:RightArm": (0, 0, 15),
         "mixamorig:LeftForeArm": (-10, 0, 0), "mixamorig:RightForeArm": (-10, 0, 0),
         "__hips_z__": -0.02},
    CONTACT: {"mixamorig:Hips": (-4, 6, 0), "mixamorig:Spine": (7, -3, 0),
              "mixamorig:Spine1": (4, -1, 0), "mixamorig:Spine2": (2, 0, 0),
              "mixamorig:Head": (-2, 0, 0), "mixamorig:LeftArm": (0, 0, -18),
              "mixamorig:RightArm": (0, 0, 18),
              "mixamorig:LeftForeArm": (-13, 0, 0), "mixamorig:RightForeArm": (-13, 0, 0),
              "__hips_z__": -0.035},
    22: {"mixamorig:Hips": (-5, 8, 0), "mixamorig:Spine": (8, -3, 0),
         "mixamorig:Spine1": (5, -1, 0), "mixamorig:Spine2": (2, 0, 0),
         "mixamorig:Head": (-3, 0, 0), "mixamorig:LeftArm": (0, 0, -20),
         "mixamorig:RightArm": (0, 0, 20),
         "mixamorig:LeftForeArm": (-14, 0, 0), "mixamorig:RightForeArm": (-14, 0, 0),
         "__hips_z__": -0.04},
    30: {"mixamorig:Hips": (3, 4, 0), "mixamorig:Spine": (2, -1, 0),
         "mixamorig:Spine1": (1, 0, 0), "mixamorig:Head": (-1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -13), "mixamorig:RightArm": (0, 0, 13),
         "__hips_z__": -0.018},
    40: {"mixamorig:Hips": (1, 1, 0), "mixamorig:Spine": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -4), "mixamorig:RightArm": (0, 0, 4)},
    END: {},
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
                raise RuntimeError(f"Missing expected Y-Bot bone {name}")
            bone.rotation_mode = "QUATERNION"
            angles = pose.get(name, (0, 0, 0))
            bone.rotation_quaternion = Euler(tuple(radians(x) for x in angles), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
        hips = rig.pose.bones["mixamorig:Hips"]
        hips.location = (0.0, 0.0, float(pose.get("__hips_z__", 0.0)))
        hips.keyframe_insert(data_path="location", frame=frame, group="mixamorig:Hips")

    controls = [
        make_empty(scene, "TEMP_Shot_LeftFoot", LEFT_FOOT[START]),
        make_empty(scene, "TEMP_Shot_RightFoot", RIGHT_FOOT[START]),
        make_empty(scene, "TEMP_Shot_LeftFootPole", (0.28, -0.32, 0.48)),
        make_empty(scene, "TEMP_Shot_RightFootPole", (-0.28, -0.32, 0.48)),
        make_empty(scene, "TEMP_Shot_LeftHand", LEFT_HAND[START]),
        make_empty(scene, "TEMP_Shot_RightHand", RIGHT_HAND[START]),
        make_empty(scene, "TEMP_Shot_LeftHandPole", (0.30, 0.24, 1.25)),
        make_empty(scene, "TEMP_Shot_RightHandPole", (-0.30, 0.24, 1.25)),
    ]
    for bone, target, pole in (
            ("mixamorig:LeftFoot", controls[0], controls[2]),
            ("mixamorig:RightFoot", controls[1], controls[3]),
            ("mixamorig:LeftHand", controls[4], controls[6]),
            ("mixamorig:RightHand", controls[5], controls[7])):
        constraint = rig.pose.bones[bone].constraints.new("IK")
        constraint.name = "TEMP_ShotIK_" + bone.rsplit(":", 1)[-1]
        constraint.target = target
        constraint.pole_target = pole
        constraint.chain_count = 3
    for target, mapping in ((controls[0], LEFT_FOOT), (controls[1], RIGHT_FOOT),
                            (controls[4], LEFT_HAND), (controls[5], RIGHT_HAND)):
        key_target(scene, target, mapping)

    scene.frame_set(CONTACT)
    bpy.context.view_layer.update()
    support = rig.matrix_world @ rig.pose.bones["mixamorig:LeftFoot"].tail
    strike = rig.matrix_world @ rig.pose.bones["mixamorig:RightFoot"].tail
    if abs(support.z - LEFT_FOOT[CONTACT][2]) > 0.02:
        raise RuntimeError(f"Shot support foot lost its plant: {tuple(support)}")
    if (strike - Vector(RIGHT_FOOT[CONTACT])).length > 0.025:
        raise RuntimeError(f"Shot strike foot missed target: {tuple(strike)}")

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
        raise RuntimeError("Shot IK bake failed")
    for obj in controls:
        bpy.data.objects.remove(obj, do_unlink=True)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    action["ball_contact_frame"] = CONTACT
    action["source_note"] = "Original in-place instep shot with baked support/strike foot and arm IK"
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
    scene.timeline_markers.new("BALL_CONTACT", frame=CONTACT)
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
    EVENTS.write_text(json.dumps({
        "clip": ACTION_NAME, "event": "ball_contact", "frame": CONTACT,
        "fps": FPS, "time_seconds": CONTACT / FPS,
    }, indent=2) + "\n")
    print(f"SHOT_CLIP action={action.name} frames={START}-{END} contact={CONTACT/FPS:.3f}s duration={(END-START)/FPS:.3f}s")
    print(f"SHOT_CLIP output={GLB} bytes={GLB.stat().st_size}")


if __name__ == "__main__":
    main()
