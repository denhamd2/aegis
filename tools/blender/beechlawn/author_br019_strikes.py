"""Bake six style-specific shots from the live 60 Hz strike onto the unchanged rest.

Run from the repository root with Blender 4.3:
  blender -b -t 2 --python tools/blender/beechlawn/author_br019_strikes.py
The original shared GLB and source blend are read only. The add-on GLB has no mesh.
"""
from pathlib import Path
import hashlib
import json
import math
import struct

import bpy
from mathutils import Matrix, Quaternion

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT / 'games/beechlawn_rovers'
OUT = PROJECT / 'assets/characters/shared'
RUNTIME = PROJECT / 'docs/art_briefs/left_foot_ai_2026_10_25/runtime_right_motion.json'
SOURCE = HERE / 'footballer_shared.blend'
PROTECTED = [SOURCE, OUT / 'footballer_base.glb', OUT / 'left_strikes.glb']
hashes = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in PROTECTED}
sampled = json.loads(RUNTIME.read_text())
for name, digest in sampled['sources'].items():
    assert hashlib.sha256((PROJECT / name.removeprefix('res://')).read_bytes()).hexdigest() == digest

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 60
scene.render.fps_base = 1.0
rig = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
assert len(rig.data.bones) == 65
rest = {bone.name: tuple(tuple(row) for row in bone.matrix_local) for bone in rig.data.bones}
rig.animation_data.action = None
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
inverse = rig.matrix_world.inverted()
reflection = Matrix.Diagonal((-1, 1, 1, 1))
godot_to_blender = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def matrix(values):
    return Matrix(((values[0], values[3], values[6], values[9]),
                   (values[1], values[4], values[7], values[10]),
                   (values[2], values[5], values[8], values[11]), (0, 0, 0, 1)))


def other_side(name):
    return name.replace('Left', 'TEMP').replace('Right', 'Left').replace('TEMP', 'Right')


def style_pose(style, foot, frame, count):
    # Preserve the selected toe at contact; distinct torso, arms and late
    # strike-leg follow-through supply the style without driving the ball.
    windup = math.sin(math.pi * frame / count)
    follow = math.sin(math.pi * (frame - 19) / (count - 19)) if frame > 19 else 0.0
    contact = max(0.0, 1.0 - abs(frame - 18) / 15.0)
    sign = 1 if foot == 'right' else -1
    opposite = 'Left' if foot == 'right' else 'Right'

    def turn(bone_name, axis, degrees):
        bone = rig.pose.bones['mixamorig:' + bone_name]
        delta = Quaternion(axis, math.radians(degrees))
        bone.rotation_quaternion = (delta @ bone.rotation_quaternion).normalized()

    if style == 'power':
        turn('Spine', (1, 0, 0), -15 * windup)
        turn('Spine1', (1, 0, 0), -9 * windup)
        turn(opposite + 'Arm', (0, 0, 1), sign * 25 * windup)
        turn(foot.capitalize() + 'Arm', (0, 0, 1), -sign * 18 * windup)
        turn(opposite + 'Leg', (1, 0, 0), 3 * contact)
        turn(opposite + 'Foot', (1, 0, 0), -3 * contact)
        turn(foot.capitalize() + 'Leg', (1, 0, 0), -10 * follow)
    elif style == 'finesse':
        turn('Spine', (0, 1, 0), sign * 18 * windup)
        turn('Spine1', (0, 1, 0), sign * 12 * windup)
        turn(opposite + 'Arm', (0, 0, 1), sign * 22 * windup)
        turn(foot.capitalize() + 'Arm', (0, 0, 1), -sign * 10 * windup)
        turn(foot.capitalize() + 'Foot', (0, 1, 0), sign * 6 * contact)
        turn(foot.capitalize() + 'Leg', (0, 0, 1), sign * 10 * follow)
    else:  # low: chest over the ball, balanced arms, restrained boot lift.
        turn('Spine', (1, 0, 0), 18 * windup)
        turn('Spine1', (1, 0, 0), 12 * windup)
        turn(opposite + 'Arm', (0, 0, 1), sign * 12 * windup)
        turn(opposite + 'Leg', (1, 0, 0), 4 * contact)
        turn(opposite + 'Foot', (1, 0, 0), -4 * contact)
        turn(foot.capitalize() + 'Leg', (1, 0, 0), 7 * follow)


created = []
audit = {'fps': 60, 'source_sha256': {str(path.relative_to(ROOT)): digest for path, digest in hashes.items()},
         'clips': {}, 'root_motion': 'Existing in-place strike; gameplay owns root and ball'}
samples = sampled['clips']['shot']['samples']
for style in ('power', 'finesse', 'low'):
    for foot in ('right', 'left'):
        name = 'AN_Beechlawn_Shot' + style.capitalize() + foot.capitalize()
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        created.append(action)
        previous = {}
        for frame, sample in enumerate(samples):
            scene.frame_set(frame + 1)
            targets = {}
            for bone in rig.pose.bones:
                source_name = (other_side(bone.name) if foot == 'left' else bone.name).replace(':', '_')
                pose = inverse @ godot_to_blender @ matrix(sample[source_name])
                source_rest = inverse @ godot_to_blender @ matrix(sampled['rest'][source_name])
                delta = pose @ source_rest.inverted()
                if foot == 'left':
                    delta = reflection @ delta @ reflection
                targets[bone.name] = delta @ bone.bone.matrix_local
            for bone in rig.pose.bones:
                if bone.parent:
                    local = bone.bone.convert_local_to_pose(
                        targets[bone.name], bone.bone.matrix_local,
                        parent_matrix=targets[bone.parent.name],
                        parent_matrix_local=bone.parent.bone.matrix_local, invert=True)
                else:
                    local = bone.bone.convert_local_to_pose(targets[bone.name], bone.bone.matrix_local, invert=True)
                location, rotation, scale = local.decompose()
                assert max(abs(value - 1) for value in scale) < .0002
                if bone.name in previous and previous[bone.name].dot(rotation) < 0:
                    rotation.negate()
                bone.location = location
                bone.rotation_mode = 'QUATERNION'
                bone.rotation_quaternion = rotation
                bone.scale = (1, 1, 1)
            style_pose(style, foot, frame, len(samples) - 1)
            for bone in rig.pose.bones:
                rotation = bone.rotation_quaternion
                if bone.name in previous and previous[bone.name].dot(rotation) < 0:
                    rotation.negate()
                previous[bone.name] = rotation.copy()
                bone.keyframe_insert('location', frame=frame + 1, group=bone.name)
                bone.keyframe_insert('rotation_quaternion', frame=frame + 1, group=bone.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = 'LINEAR'
        metadata = {'clip': name, 'event': 'ball_contact', 'frame': 18, 'fps': 60,
                    'time_seconds': .3, 'style': style, 'foot': foot}
        (OUT / f'shot_{style}_{foot}_contact.json').write_text(json.dumps(metadata, indent=2) + '\n')
        audit['clips'][name] = {'frames': len(samples), 'duration_seconds': (len(samples) - 1) / 60,
                                'contact_seconds': .3}
        print('BR019_STRIKE_BAKED', name, len(samples), flush=True)

for obj in list(bpy.data.objects):
    if obj != rig:
        bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    if action not in created:
        bpy.data.actions.remove(action, do_unlink=True)
for material in list(bpy.data.materials):
    bpy.data.materials.remove(material)
for image in list(bpy.data.images):
    bpy.data.images.remove(image)
rig.animation_data.action = created[0]
scene.frame_set(1)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'football_br019_strikes.blend'), compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'br019_strikes.glb'), export_format='GLB',
                          use_selection=True, export_yup=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
                          export_skins=True, export_leaf_bone=False,
                          export_rest_position_armature=True)
assert rest == {bone.name: tuple(tuple(row) for row in bone.matrix_local) for bone in rig.data.bones}
assert all(hashlib.sha256(path.read_bytes()).hexdigest() == digest for path, digest in hashes.items())
raw = (OUT / 'br019_strikes.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
gltf = json.loads(raw[20:20 + length])
assert {anim['name'] for anim in gltf['animations']} == set(audit['clips'])
for anim in gltf['animations']:
    inputs = [gltf['accessors'][sample['input']] for sample in anim['samplers']]
    assert abs(min(item['min'][0] for item in inputs)) < 1e-6
    assert abs(max(item['max'][0] for item in inputs) - .9) < 1e-5
(OUT / 'br019_strikes_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
print('BR019_STRIKES_EXPORTED', len(created), 'clips with unchanged 65-bone rest', flush=True)
