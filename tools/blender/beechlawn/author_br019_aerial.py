"""Author additive challenged header and secure high-claim motions.

Both clips inherit the approved in-place action and unchanged 65-bone rest.
Run: blender -b -t 2 --python tools/blender/beechlawn/author_br019_aerial.py
"""
from pathlib import Path
import hashlib
import json
import math

import bpy
from mathutils import Quaternion

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'games/beechlawn_rovers/assets/characters/shared'
PROTECTED = [HERE / 'footballer_shared.blend', OUT / 'footballer_base.glb',
             HERE / 'football_aerial_actions.blend', HERE / 'football_keeper_high_saves.blend',
             OUT / 'aerial_actions.glb', OUT / 'keeper_high_saves.glb']
hashes = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in PROTECTED}


def make(source_file, source_name, target_name, frames, output_name, blend_name, kind):
    bpy.ops.wm.open_mainfile(filepath=str(HERE / source_file))
    scene = bpy.context.scene
    scene.render.fps = 60
    scene.render.fps_base = 1
    rig = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
    assert len(rig.data.bones) == 65
    rest = {bone.name: tuple(tuple(row) for row in bone.matrix_local) for bone in rig.data.bones}
    original = bpy.data.actions[source_name]
    action = bpy.data.actions.new(target_name)
    action.use_fake_user = True
    rig.animation_data.action = original
    for frame in range(1, frames + 1):
        scene.frame_set(frame)
        poses = {bone.name: (bone.location.copy(), bone.rotation_quaternion.copy()) for bone in rig.pose.bones}
        rig.animation_data.action = action
        for bone in rig.pose.bones:
            bone.location, bone.rotation_quaternion = poses[bone.name]
        amount = math.sin(math.pi * max(0, min(1, (frame - 3) / (31 if kind == 'header' else 50))))

        def turn(name, axis, degrees):
            bone = rig.pose.bones['mixamorig:' + name]
            bone.rotation_quaternion = (Quaternion(axis, math.radians(degrees)) @ bone.rotation_quaternion).normalized()

        if kind == 'header':
            # Wider braced arms signal a real challenger. The head and torso
            # path remain identical to the proven 20 cm live-contact action.
            turn('LeftArm', (0, 0, 1), 12 * amount)
            turn('RightArm', (0, 0, 1), -12 * amount)
            turn('LeftForeArm', (0, 1, 0), 9 * amount)
            turn('RightForeArm', (0, 1, 0), -9 * amount)
        elif frame > 20:
            # Retain the proven overhead hand reach at contact, then gather
            # into a balanced two-hand cradle during the physical landing.
            secure = math.sin(math.pi * min(1, (frame - 20) / 59))
            turn('LeftArm', (1, 0, 0), 16 * secure)
            turn('RightArm', (1, 0, 0), 16 * secure)
            turn('LeftForeArm', (0, 1, 0), -16 * secure)
            turn('RightForeArm', (0, 1, 0), 16 * secure)
        for bone in rig.pose.bones:
            bone.keyframe_insert('location', frame=frame, group=bone.name)
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
        rig.animation_data.action = original
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = 'LINEAR'
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    for candidate in list(bpy.data.actions):
        if candidate != action:
            bpy.data.actions.remove(candidate, do_unlink=True)
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
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / blend_name), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / output_name), export_format='GLB',
                              use_selection=True, export_yup=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
                              export_skins=True, export_leaf_bone=False,
                              export_rest_position_armature=True)
    assert rest == {bone.name: tuple(tuple(row) for row in bone.matrix_local) for bone in rig.data.bones}
    return {'clip': target_name, 'frames': frames, 'duration_seconds': (frames - 1) / 60,
            'source_clip': source_name, 'source_blend': source_file}


audit = {'fps': 60, 'root_motion': 'none; existing CharacterBody owns takeoff and landing', 'clips': []}
audit['clips'].append(make('football_aerial_actions.blend', 'AN_Beechlawn_Header',
                           'AN_Beechlawn_HeaderDuel', 45, 'br019_header_duel.glb',
                           'football_br019_header_duel.blend', 'header'))
metadata = {'clip': 'AN_Beechlawn_HeaderDuel', 'event': 'ball_contact',
            'frame': 18, 'fps': 60, 'time_seconds': .3}
(OUT / 'br019_header_duel_contact.json').write_text(json.dumps(metadata, indent=2) + '\n')
audit['clips'].append(make('football_keeper_high_saves.blend', 'AN_Beechlawn_KeeperHighReach',
                           'AN_Beechlawn_KeeperHighClaim', 79, 'br019_keeper_claim.glb',
                           'football_br019_keeper_claim.blend', 'keeper'))
assert all(hashlib.sha256(path.read_bytes()).hexdigest() == digest for path, digest in hashes.items())
(OUT / 'br019_aerial_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
print('BR019_AERIAL_EXPORTED', audit['clips'], flush=True)
