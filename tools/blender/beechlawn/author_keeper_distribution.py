"""Author the in-place keeper sidearm distribution on the shipped 65-bone rig.

Run: blender -b -t 2 --python-exit-code 1 --python tools/blender/beechlawn/author_keeper_distribution.py
The independent Godot ball follows the gloves while held and releases on the
frame-31 contact marker; this asset has no gameplay/root motion authority.
"""
from pathlib import Path
import hashlib
import json
import math
import sys

import bpy
from mathutils import Quaternion, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'games/beechlawn_rovers/assets/characters/shared'
sys.path.insert(0, str(HERE))
from shane_leg_retarget import minimum_roll_pose, local_rotation

protected = [HERE / 'footballer_shared.blend', OUT / 'footballer_base.glb']
digests = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in protected}
bpy.ops.wm.open_mainfile(filepath=str(protected[0]))
scene = bpy.context.scene
scene.render.fps = 60
scene.render.fps_base = 1
rig = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
assert len(rig.data.bones) == 65
rest = {bone.name: tuple(tuple(row) for row in bone.matrix_local) for bone in rig.data.bones}
rig.animation_data.action = bpy.data.actions['AN_Beechlawn_KeeperSet']
scene.frame_set(1)
base = {bone.name: (bone.location.copy(), bone.rotation_quaternion.copy(), bone.scale.copy())
        for bone in rig.pose.bones}

def restore():
    for bone in rig.pose.bones:
        bone.location, bone.rotation_quaternion, bone.scale = base[bone.name]
    bpy.context.view_layer.update()

def arm(side, elbow, hand):
    for suffix, target in [('Arm', Vector(elbow)), ('ForeArm', Vector(hand))]:
        bone = rig.pose.bones['mixamorig:' + side + suffix]
        matrix = minimum_roll_pose(bone, bone.parent.matrix,
                                   target - bone.matrix.translation, bone.matrix.translation)
        bone.rotation_quaternion = local_rotation(bone, matrix, bone.parent.matrix)[0]
        bpy.context.view_layer.update()

action = bpy.data.actions.new('AN_Beechlawn_KeeperDistribute')
action.use_fake_user = True
rig.animation_data.action = action
# Shoulder/elbow/hand targets are in the live source's local centimetres.
# The left glove guides the ball until the right hand accelerates through it.
poses = {
    1:  ((-25, 151, 28), (-13, 129, 47), (25, 151, 28), (13, 129, 47), 0),
    11: ((-37, 151, -1), (-38, 139, -28), (23, 151, 27), (12, 132, 42), -8),
    22: ((-42, 158, -19), (-54, 147, -38), (20, 150, 24), (12, 133, 40), -15),
    31: ((-25, 151, 48), (-11, 143, 83), (23, 150, 30), (16, 135, 43), 9),
    43: ((-15, 140, 51), (6, 125, 78), (24, 149, 27), (17, 132, 41), 6),
    58: ((-25, 151, 28), (-13, 129, 47), (25, 151, 28), (13, 129, 47), 0),
}
for frame, (right_elbow, right_hand, left_elbow, left_hand, turn) in poses.items():
    scene.frame_set(frame)
    restore()
    hips = rig.pose.bones['mixamorig:Hips']
    hips.rotation_quaternion = (Quaternion((0, 1, 0), math.radians(turn))
                                @ hips.rotation_quaternion).normalized()
    bpy.context.view_layer.update()
    arm('Right', right_elbow, right_hand)
    arm('Left', left_elbow, left_hand)
    for bone in rig.pose.bones:
        for channel in ('location', 'rotation_quaternion', 'scale'):
            bone.keyframe_insert(channel, frame=frame, group=bone.name)
for curve in action.fcurves:
    for key in curve.keyframe_points:
        key.interpolation = 'BEZIER'
        key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'

for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
for old in list(bpy.data.actions):
    if old != action:
        bpy.data.actions.remove(old, do_unlink=True)
for obj in list(bpy.data.objects):
    if obj != rig:
        bpy.data.objects.remove(obj, do_unlink=True)
for material in list(bpy.data.materials):
    bpy.data.materials.remove(material)
for image in list(bpy.data.images):
    bpy.data.images.remove(image)
rig.animation_data.action = action
scene.frame_set(1)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'football_keeper_distribution.blend'), compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'keeper_distribution.glb'), export_format='GLB',
                          use_selection=True, export_yup=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
                          export_skins=True, export_leaf_bone=False,
                          export_rest_position_armature=True)
(OUT / 'keeper_distribution_contact.json').write_text(json.dumps({
    'clip': action.name, 'event': 'ball_contact', 'frame': 30,
    'fps': 60, 'time_seconds': 0.5,
}, indent=2) + '\n')
assert rest == {bone.name: tuple(tuple(row) for row in bone.matrix_local) for bone in rig.data.bones}
assert all(hashlib.sha256(path.read_bytes()).hexdigest() == digest for path, digest in digests.items())
print('KEEPER_DISTRIBUTION_EXPORTED', action.name, list(action.frame_range), flush=True)
