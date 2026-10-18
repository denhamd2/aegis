"""Author a short, in-place braking/settle clip for the shared Y-Bot rig.

Run from repository root:
  blender -b --python games/beechlawn_rovers/tools/blender/author_football_stop.py

This is presentation only. Godot still owns horizontal movement and stopping
distance; the planted-foot targets are Blender controls baked into bone keys.
"""
from pathlib import Path
from math import radians
import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[4]
LIBRARY = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
ARMATURE_NAME = "YBot_Armature"
ACTION_NAME = "AN_Beechlawn_StopFromRun"
FPS = 60
START = 1
END = 36

# Stop sequence: absorb over a bent support leg, catch with the trailing foot,
# then let hips/shoulders settle. Blender axes are Y-forward, Z-up on this rig.
LEFT_FOOT = {
    1: (0.095, -0.113, 0.033), 5: (0.095, -0.113, 0.033),
    9: (0.095, -0.113, 0.033), 14: (0.095, -0.113, 0.033),
    19: (0.095, -0.113, 0.033), 24: (0.105, -0.120, 0.033),
    30: (0.095, -0.113, 0.033), END: (0.095, -0.113, 0.033),
}
RIGHT_FOOT = {
    1: (-0.095, 0.125, 0.033), 5: (-0.095, 0.075, 0.033),
    9: (-0.095, -0.110, 0.045), 14: (-0.095, -0.340, 0.033),
    19: (-0.095, -0.340, 0.033), 24: (-0.095, -0.260, 0.033),
    30: (-0.095, -0.113, 0.033), END: (-0.095, -0.113, 0.033),
}
POSES = {
    1: {},
    5: {"mixamorig:Hips": (2, -2, 0), "mixamorig:Spine": (-2, 0, 0),
        "mixamorig:LeftArm": (0, 0, -4), "mixamorig:RightArm": (0, 0, 4)},
    9: {"mixamorig:Hips": (7, -3, 0), "mixamorig:Spine": (-7, 1, 0),
        "mixamorig:Spine1": (-3, 0, 0), "mixamorig:Head": (1, 0, 0),
        "mixamorig:LeftArm": (0, 0, -14), "mixamorig:RightArm": (0, 0, 14),
        "mixamorig:LeftForeArm": (-10, 0, 0), "mixamorig:RightForeArm": (-10, 0, 0),
        "__hips_z__": -0.035},
    14: {"mixamorig:Hips": (10, -5, 0), "mixamorig:Spine": (-9, 2, 0),
         "mixamorig:Spine1": (-4, 0, 0), "mixamorig:Spine2": (-2, 0, 0),
         "mixamorig:Head": (2, 0, 0), "mixamorig:LeftArm": (0, 0, -20),
         "mixamorig:RightArm": (0, 0, 20), "mixamorig:LeftForeArm": (-14, 0, 0),
         "mixamorig:RightForeArm": (-14, 0, 0), "__hips_z__": -0.055},
    19: {"mixamorig:Hips": (6, -3, 0), "mixamorig:Spine": (-5, 1, 0),
         "mixamorig:Spine1": (-2, 0, 0), "mixamorig:Head": (1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -13), "mixamorig:RightArm": (0, 0, 13),
         "mixamorig:LeftForeArm": (-9, 0, 0), "mixamorig:RightForeArm": (-9, 0, 0),
         "__hips_z__": -0.035},
    24: {"mixamorig:Hips": (2, -1, 0), "mixamorig:Spine": (-2, 0, 0),
         "mixamorig:LeftArm": (0, 0, -7), "mixamorig:RightArm": (0, 0, 7),
         "__hips_z__": -0.012},
    30: {"mixamorig:Hips": (0, 0, 0), "mixamorig:Spine": (-1, 0, 0),
         "mixamorig:LeftArm": (0, 0, -2), "mixamorig:RightArm": (0, 0, 2)},
    END: {},
}
LEFT_HAND = {
    1: (0.32, -0.06, 0.96), 5: (0.40, -0.09, 1.06),
    9: (0.49, -0.10, 1.15), 14: (0.52, -0.10, 1.19),
    19: (0.47, -0.08, 1.12), 24: (0.39, -0.06, 1.04),
    30: (0.32, -0.06, 0.96), END: (0.32, -0.06, 0.96),
}
RIGHT_HAND = {frame: (-point[0], point[1], point[2])
	for frame, point in LEFT_HAND.items()}


def add_empty(scene, name, location):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.location = Vector(location)
    return obj


def key_target(scene, obj, values):
    for frame, location in values.items():
        scene.frame_set(frame)
        obj.location = Vector(location)
        obj.keyframe_insert(data_path="location", frame=frame)
    for curve in obj.animation_data.action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"


def refine_idle_arms(rig, scene):
	"""Replace the imported T-pose arm silhouette with a relaxed ready stance."""
	idle = bpy.data.actions.get("AN_Beechlawn_Idle")
	if idle is None:
		raise RuntimeError("The shared animation library has no idle action")
	rig.animation_data_create()
	rig.animation_data.action = idle
	frames = (2, 24, 46, 68, 90)
	left_positions = {
		2: (0.32, -0.06, 0.98), 24: (0.33, -0.06, 0.96),
		46: (0.32, -0.06, 0.98), 68: (0.31, -0.07, 1.00),
		90: (0.32, -0.06, 0.98),
	}
	right_positions = {frame: (-point[0], point[1], point[2])
		for frame, point in left_positions.items()}
	left = add_empty(scene, "TEMP_Idle_LeftHand", left_positions[2])
	right = add_empty(scene, "TEMP_Idle_RightHand", right_positions[2])
	left_pole = add_empty(scene, "TEMP_Idle_LeftPole", (0.35, 0.22, 1.25))
	right_pole = add_empty(scene, "TEMP_Idle_RightPole", (-0.35, 0.22, 1.25))
	for bone_name, target, pole in (
			("mixamorig:LeftHand", left, left_pole),
			("mixamorig:RightHand", right, right_pole)):
		constraint = rig.pose.bones[bone_name].constraints.new("IK")
		constraint.name = "TEMP_Idle_IK_" + bone_name.rsplit(":", 1)[-1]
		constraint.target = target
		constraint.pole_target = pole
		constraint.chain_count = 3
	key_target(scene, left, left_positions)
	key_target(scene, right, right_positions)
	scene.frame_set(46)
	bpy.context.view_layer.update()
	for name, expected in (("mixamorig:LeftHand", left_positions[46]),
			("mixamorig:RightHand", right_positions[46])):
		actual = rig.matrix_world @ rig.pose.bones[name].tail
		if (actual - Vector(expected)).length > 0.22:
			raise RuntimeError(f"Idle hand pose missed for {name}: {tuple(actual)}")
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.select_all(action="DESELECT")
	rig.select_set(True)
	bpy.ops.object.mode_set(mode="POSE")
	bpy.ops.pose.select_all(action="SELECT")
	baked = bpy.ops.nla.bake(
		frame_start=2, frame_end=90, step=1, only_selected=True,
		visual_keying=True, clear_constraints=True, use_current_action=True,
		bake_types={"POSE"}, channel_types={"LOCATION", "ROTATION"},
		clean_curves=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	if "FINISHED" not in baked:
		raise RuntimeError("Idle arm pose bake failed")
	for obj in (left, right, left_pole, right_pole):
		bpy.data.objects.remove(obj, do_unlink=True)
	for curve in idle.fcurves:
		for key in curve.keyframe_points:
			key.interpolation = "BEZIER"
			key.handle_left_type = "AUTO_CLAMPED"
			key.handle_right_type = "AUTO_CLAMPED"
	return idle


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
        for name in used:
            bone = rig.pose.bones.get(name)
            if bone is None:
                raise RuntimeError(f"Missing Y-Bot bone {name}")
            bone.rotation_mode = "QUATERNION"
            angles = pose.get(name, (0, 0, 0))
            bone.rotation_quaternion = Euler(tuple(radians(x) for x in angles), "XYZ").to_quaternion()
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
        hips = rig.pose.bones["mixamorig:Hips"]
        hips.location = (0.0, 0.0, float(pose.get("__hips_z__", 0.0)))
        hips.keyframe_insert(data_path="location", frame=frame, group="mixamorig:Hips")

    left = add_empty(scene, "TEMP_Stop_LeftFoot", LEFT_FOOT[START])
    right = add_empty(scene, "TEMP_Stop_RightFoot", RIGHT_FOOT[START])
    left_pole = add_empty(scene, "TEMP_Stop_LeftPole", (0.28, -0.32, 0.48))
    right_pole = add_empty(scene, "TEMP_Stop_RightPole", (-0.28, -0.32, 0.48))
    left_hand = add_empty(scene, "TEMP_Stop_LeftHand", LEFT_HAND[START])
    right_hand = add_empty(scene, "TEMP_Stop_RightHand", RIGHT_HAND[START])
    left_hand_pole = add_empty(scene, "TEMP_Stop_LeftHandPole", (0.35, 0.22, 1.25))
    right_hand_pole = add_empty(scene, "TEMP_Stop_RightHandPole", (-0.35, 0.22, 1.25))
    for bone_name, target, pole in (
            ("mixamorig:LeftFoot", left, left_pole),
            ("mixamorig:RightFoot", right, right_pole),
            ("mixamorig:LeftHand", left_hand, left_hand_pole),
            ("mixamorig:RightHand", right_hand, right_hand_pole)):
        constraint = rig.pose.bones[bone_name].constraints.new("IK")
        constraint.name = "TEMP_Stop_IK_" + bone_name.rsplit(":", 1)[-1]
        constraint.target = target
        constraint.pole_target = pole
        constraint.chain_count = 3
    key_target(scene, left, LEFT_FOOT)
    key_target(scene, right, RIGHT_FOOT)
    key_target(scene, left_hand, LEFT_HAND)
    key_target(scene, right_hand, RIGHT_HAND)

    scene.frame_set(14)
    bpy.context.view_layer.update()
    planted = rig.matrix_world @ rig.pose.bones["mixamorig:LeftFoot"].tail
    if (planted - Vector(LEFT_FOOT[14])).length > 0.025:
        raise RuntimeError(f"Support foot missed brake plant: {tuple(planted)}")

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
        raise RuntimeError("Stop clip bake failed")
    for obj in (left, right, left_pole, right_pole, left_hand, right_hand,
			left_hand_pole, right_hand_pole):
        bpy.data.objects.remove(obj, do_unlink=True)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    action["source_note"] = "Original in-place football braking study; no root motion"
    return action


def main():
    if not LIBRARY.is_file():
        raise FileNotFoundError(LIBRARY)
    bpy.ops.wm.open_mainfile(filepath=str(LIBRARY))
    rig = bpy.data.objects.get(ARMATURE_NAME)
    if rig is None or len(rig.data.bones) != 65:
        raise RuntimeError("Expected the validated shared 65-bone Y-Bot rig")
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = START, END
    bpy.context.preferences.filepaths.save_version = 0
    idle = refine_idle_arms(rig, scene)
    action = author(rig, scene)
    scene.timeline_markers.clear()
    scene.timeline_markers.new("BRAKE_PLANT", frame=14)
    scene.frame_end = max(int(a.frame_range[1]) for a in bpy.data.actions)
    scene.frame_set(START)
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
        export_optimize_animation_size=False)
    print(f"IDLE_POSE action={idle.name} frames=2-90 relaxed_arm_targets=verified")
    print(f"STOP_CLIP action={action.name} frames={START}-{END} duration={(END-START)/FPS:.3f}s plant={14/FPS:.3f}s")
    print(f"STOP_CLIP output={GLB_OUT} bytes={GLB_OUT.stat().st_size}")


if __name__ == "__main__":
    main()
