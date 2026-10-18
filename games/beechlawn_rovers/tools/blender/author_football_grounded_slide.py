"""Author a grounded committed slide that settles on the side for recovery.

Run from the repository root with Blender 4.3.2. Gameplay owns the 0.62 s
slide window and ball contact; the action is an in-place visual presentation.
"""
from pathlib import Path
from math import radians

import bpy
from mathutils import Euler

ROOT = Path(__file__).resolve().parents[4]
BLEND = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_animation_library.glb"
RIG_NAME = "YBot_Armature"
ACTION_NAME = "AN_Beechlawn_GroundedSlideTackle"
FPS = 60
START, END = 1, 38  # 0.617 s, aligned with the gameplay's 0.62 s commit.

# Side-on tackle: compress, drop hips, lead with the near leg, then let the
# body settle onto its side. Hips Y is in Blender centimetres on this rig.
POSES = {
    1:  {"mixamorig:Hips": (4, 0, 0), "mixamorig:Spine": (-5, 0, -3),
	         "mixamorig:LeftUpLeg": (-8, 0, -5), "mixamorig:LeftLeg": (12, 0, 0),
	         "mixamorig:RightUpLeg": (8, 0, 5), "mixamorig:RightLeg": (8, 0, 0),
	         "mixamorig:LeftArm": (24, 0, -24), "mixamorig:RightArm": (24, 0, 24),
	         "mixamorig:LeftForeArm": (-24, 0, 0), "mixamorig:RightForeArm": (-24, 0, 0), "__drop": -0.03},
    5:  {"mixamorig:Hips": (5, 0, 0), "mixamorig:Spine": (-5, 0, -8),
         "mixamorig:LeftUpLeg": (-30, 0, -14), "mixamorig:LeftLeg": (48, 0, 0),
         "mixamorig:RightUpLeg": (12, 0, 10), "mixamorig:RightLeg": (20, 0, 0),
	         "mixamorig:LeftArm": (42, 0, -38), "mixamorig:RightArm": (38, 0, 42),
	         "mixamorig:LeftForeArm": (-55, 0, 0), "mixamorig:RightForeArm": (-48, 0, 0), "__drop": -0.26},
    10: {"mixamorig:Hips": (82, 0, 7), "mixamorig:Spine": (-3, 0, -4),
         "mixamorig:Spine1": (-1, 0, -2), "mixamorig:Head": (8, 0, 0),
         "mixamorig:LeftUpLeg": (-38, 0, -8), "mixamorig:LeftLeg": (86, 0, 0),
         "mixamorig:RightUpLeg": (-18, 0, 12), "mixamorig:RightLeg": (72, 0, 0),
         "mixamorig:LeftArm": (0, 0, -18), "mixamorig:RightArm": (0, 0, 18),
         "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-18, 0, 0), "__drop": -0.68},
    16: {"mixamorig:Hips": (82, 0, 4), "mixamorig:Spine": (-4, 0, -5),
         "mixamorig:Spine1": (-2, 0, -2), "mixamorig:Head": (9, 0, 0),
         "mixamorig:LeftUpLeg": (-40, 0, -8), "mixamorig:LeftLeg": (88, 0, 0),
         "mixamorig:RightUpLeg": (-18, 0, 12), "mixamorig:RightLeg": (74, 0, 0),
         "mixamorig:LeftArm": (0, 0, -18), "mixamorig:RightArm": (0, 0, 18),
         "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-18, 0, 0), "__drop": -0.68},
    23: {"mixamorig:Hips": (82, 0, 5), "mixamorig:Spine": (-3, 0, -4),
         "mixamorig:Spine1": (-1, 0, -2), "mixamorig:Head": (8, 0, 0),
         "mixamorig:LeftUpLeg": (-38, 0, -8), "mixamorig:LeftLeg": (86, 0, 0),
         "mixamorig:RightUpLeg": (-18, 0, 12), "mixamorig:RightLeg": (72, 0, 0),
         "mixamorig:LeftArm": (0, 0, -18), "mixamorig:RightArm": (0, 0, 18),
         "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-18, 0, 0), "__drop": -0.68},
    30: {"mixamorig:Hips": (82, 0, 5), "mixamorig:Spine": (-3, 0, -4),
         "mixamorig:Spine1": (-1, 0, -2), "mixamorig:Head": (8, 0, 0),
         "mixamorig:LeftUpLeg": (-38, 0, -8), "mixamorig:LeftLeg": (86, 0, 0),
         "mixamorig:RightUpLeg": (-18, 0, 12), "mixamorig:RightLeg": (72, 0, 0),
         "mixamorig:LeftArm": (0, 0, -18), "mixamorig:RightArm": (0, 0, 18),
         "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-18, 0, 0),
         "__drop": -0.68},
    END: {"mixamorig:Hips": (82, 0, 6), "mixamorig:Spine": (-3, 0, -4),
          "mixamorig:Spine1": (-1, 0, -2), "mixamorig:Head": (8, 0, 0),
          "mixamorig:LeftUpLeg": (-38, 0, -8), "mixamorig:LeftLeg": (86, 0, 0),
          "mixamorig:RightUpLeg": (-18, 0, 12), "mixamorig:RightLeg": (72, 0, 0),
          "mixamorig:LeftArm": (0, 0, -18), "mixamorig:RightArm": (0, 0, 18),
          "mixamorig:LeftForeArm": (-18, 0, 0), "mixamorig:RightForeArm": (-18, 0, 0),
          "__drop": -0.68},
}


def author(rig, scene):
    idle_action = bpy.data.actions.get("AN_Beechlawn_Idle")
    getup_action = bpy.data.actions.get("AN_Beechlawn_GetUpFromProne")
    if idle_action is None or getup_action is None:
        raise RuntimeError("Could not find the shared idle pose for a seamless slide start")
    rig.animation_data_create()
    rig.animation_data.action = idle_action
    scene.frame_set(1)
    bpy.context.view_layer.update()
    idle_rotations = {bone.name: bone.rotation_quaternion.copy() for bone in rig.pose.bones}
    idle_locations = {bone.name: bone.location.copy() for bone in rig.pose.bones}
    rig.animation_data.action = getup_action
    scene.frame_set(1)
    bpy.context.view_layer.update()
    recovery_rotations = {bone.name: bone.rotation_quaternion.copy() for bone in rig.pose.bones}
    recovery_locations = {bone.name: bone.location.copy() for bone in rig.pose.bones}
    old = bpy.data.actions.get(ACTION_NAME)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(ACTION_NAME)
    rig.animation_data_create()
    rig.animation_data.action = action
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = idle_rotations[bone.name]
        bone.location = idle_locations[bone.name]
        bone.keyframe_insert("rotation_quaternion", frame=START, group=bone.name)
        if bone.name == "mixamorig:Hips":
            bone.keyframe_insert("location", frame=START, group=bone.name)
    used = {name for pose in POSES.values() for name in pose if not name.startswith("__")}
    for frame, pose in POSES.items():
        if frame == START:
            continue
        scene.frame_set(frame)
        if frame >= 10:
            # Reuse the get-up's verified ground-supported starting pose so
            # contact/settle flows into recovery without a loose approximation.
            for bone in rig.pose.bones:
                bone.rotation_mode = "QUATERNION"
                bone.rotation_quaternion = recovery_rotations[bone.name]
                bone.location = recovery_locations[bone.name]
                bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
                if bone.name == "mixamorig:Hips":
                    bone.keyframe_insert("location", frame=frame, group=bone.name)
            continue
        for name in used:
            bone = rig.pose.bones.get(name)
            if bone is None:
                raise RuntimeError(f"Missing expected Mixamo bone {name}")
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = Euler(tuple(radians(v) for v in pose.get(name, (0, 0, 0))), "XYZ").to_quaternion()
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=name)
        hips = rig.pose.bones["mixamorig:Hips"]
        hips.location = (0.0, float(pose.get("__drop", 0.0)) * 100.0, 0.0)
        hips.keyframe_insert("location", frame=frame, group="mixamorig:Hips")
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    action["source_note"] = "Original grounded side-on slide, settles into prone get-up start; in-place"
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
    for label, frame in (("DROP_AND_PLANT", 5), ("CONTACT", 12), ("SETTLE", 23), ("PRONE_RECOVERY_START", END)):
        scene.timeline_markers.new(label, frame=frame)
    scene.frame_end = max(int(item.frame_range[1]) for item in bpy.data.actions)
    scene.frame_set(START)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_cameras=False, export_lights=False,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_influence_nb=4, export_leaf_bone=False, export_rest_position_armature=True,
        export_force_sampling=True, export_frame_range=True, export_frame_step=1,
        export_optimize_animation_size=False)
    print(f"GROUNDED_SLIDE action={action.name} frames={START}-{END} duration={(END-START)/FPS:.3f}s")
    print(f"GROUNDED_SLIDE output={GLB} bytes={GLB.stat().st_size}")


if __name__ == "__main__":
    main()
