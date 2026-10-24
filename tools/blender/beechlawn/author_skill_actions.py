"""Original in-place BR-020 skills; preserve the current body/head/action assets.

Animation-only add-on on the existing 65-bone rig, 60 fps, zero-based export.
Godot owns root movement and independent, live-foot-gated ball impulses.
"""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector, Quaternion

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from shane_leg_retarget import minimum_roll_pose, local_rotation

OUT = ROOT/'games/beechlawn_rovers/assets/characters/shared'
EVIDENCE = ROOT/'games/beechlawn_rovers/docs/art_briefs/br020_skills_2026_10_24'
SOURCE = HERE/'footballer_shared.blend'
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 60
scene.render.fps_base = 1.
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
# Preserve the actual shipping idle at both action endpoints. Transfer through
# world matrices, including bone roll, rather than assuming the saved source
# and shipping pose agree. Contact-foot orientation is fitted separately below.
shipping = OUT/'footballer_base.glb'
shipping_hash = hashlib.sha256(shipping.read_bytes()).hexdigest()
old_objects, old_actions = set(bpy.data.objects), set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(shipping))
imported = next(o for o in bpy.data.objects if o not in old_objects and o.type == 'ARMATURE')
idle = next(a for a in bpy.data.actions if a not in old_actions and a.name.startswith('AN_Beechlawn_Idle'))
imported.animation_data.action = idle
scene.frame_set(1)
bpy.context.view_layer.update()
poses = {}
for bone in rig.pose.bones:
    other = imported.pose.bones.get(bone.name) or imported.pose.bones.get(bone.name.replace('mixamorig:', 'mixamorig_'))
    assert other is not None, bone.name
    poses[bone.name] = rig.matrix_world.inverted() @ imported.matrix_world @ other.matrix
rig.animation_data.action = None
for bone in rig.pose.bones:
    bone.matrix = poses[bone.name]
    bpy.context.view_layer.update()
for obj in list(bpy.data.objects):
    if obj not in old_objects: bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    if action not in old_actions: bpy.data.actions.remove(action, do_unlink=True)
base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}
# The incoming idle's foot direction is not a contact target. Plant soles in
# the bind foot orientation (+Z toe) and solve their actual rest toe offsets.
feet = {s: rig.data.bones['mixamorig:'+s+'Foot'].matrix_local.copy() for s in ['Left', 'Right']}
toe_offsets = {s: rig.data.bones['mixamorig:'+s+'Toe_End'].head_local-rig.data.bones['mixamorig:'+s+'Foot'].head_local for s in feet}
report = {'source_sha256': source_hash, 'shipping_pose_sha256': shipping_hash, 'fps': 60, 'root_motion': 'in-place',
          'provenance': 'Original bpy-authored football motion; no extracted game animations', 'clips': {}}

def restore():
    for bone in rig.pose.bones:
        bone.location, bone.rotation_quaternion, bone.scale = base[bone.name]
    bpy.context.view_layer.update()

def point_bone(name, target):
    bone = rig.pose.bones['mixamorig:'+name]
    mat = minimum_roll_pose(bone, bone.parent.matrix, Vector(target)-bone.matrix.translation, bone.matrix.translation)
    bone.rotation_quaternion = local_rotation(bone, mat, bone.parent.matrix)[0]
    bpy.context.view_layer.update()

def lean(axis, degrees):
    bone = rig.pose.bones['mixamorig:Spine']
    mat = (Quaternion(Vector(axis), math.radians(degrees)) @ bone.matrix.to_quaternion()).to_matrix().to_4x4()
    mat.translation = bone.matrix.translation
    bone.rotation_quaternion = local_rotation(bone, mat, bone.parent.matrix)[0]
    bpy.context.view_layer.update()

def place_leg(side, target):
    upper = rig.pose.bones['mixamorig:'+side+'UpLeg']
    shin = rig.pose.bones['mixamorig:'+side+'Leg']
    foot = rig.pose.bones['mixamorig:'+side+'Foot']
    toe = rig.pose.bones['mixamorig:'+side+'Toe_End']
    ankle = Vector(target)-toe_offsets[side]
    hip = upper.matrix.translation.copy()
    delta = ankle-hip
    distance = delta.length
    a, b = upper.bone.length, shin.bone.length
    assert abs(a-b) < distance < a+b, (side, target, distance)
    axis = delta.normalized()
    along = (a*a-b*b+distance*distance)/(2*distance)
    pole = Vector((0, 0, 1))
    pole = (pole-axis*pole.dot(axis)).normalized()
    knee = hip+axis*along+pole*math.sqrt(max(0, a*a-along*along))
    point_bone(side+'UpLeg', knee)
    point_bone(side+'Leg', ankle)
    mat = feet[side].copy()
    mat.translation = foot.matrix.translation
    foot.rotation_quaternion = local_rotation(foot, mat, foot.parent.matrix)[0]
    bpy.context.view_layer.update()

def arms(amount, lateral=0):
    for side, sign in [('Left', 1), ('Right', -1)]:
        point_bone(side+'Arm', (sign*(29+amount*8), 128, 12+lateral*sign))
        point_bone(side+'ForeArm', (sign*(25+amount*9), 111+amount*15, 24+lateral*sign))

paths = {
    'BallRoll': [(-13, 11, 30), (-3, 12, 49), (-9, 4, 50), (-24, 5, 48)],
    'StepOver': [(-24, 16, 37), (8, 17, 60), (-9, 4, 50), (-25, 5, 48)],
    'BodyFeint': [(-11, 5, 22), (-16, 5, 35), (-9, 4, 50), (-22, 5, 42)],
    'DragBack': [(-9, 12, 35), (-9, 10, 65), (-9, 4, 50), (-9, 6, -8)],
    'SkillTurn': [(-14, 8, 25), (-17, 9, 45), (-9, 4, 50), (-25, 5, 24)],
    'FakeShot': [(-9, 18, -18), (-9, 15, 5), (-9, 4, 50), (-18, 5, 28)],
}
new = []
for kind, path in paths.items():
    for suffix, direction, active, support in [('Right', 1, 'Right', 'Left'), ('Left', -1, 'Left', 'Right')]:
        rig.animation_data.action = None
        name = 'AN_Beechlawn_'+kind+suffix
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        previous = {}
        for frame, target in [(1, None), *zip([7, 13, 19, 25], path), (34, (-11, 5, 19)), (43, None)]:
            scene.frame_set(frame)
            restore()
            if target is not None:
                rig.pose.bones['mixamorig:Hips'].location.y -= 9
                bpy.context.view_layer.update()
                lean((1, 0, 0), 5 if kind == 'FakeShot' else 2)
                shift = -5 if frame < 19 and kind in ('BodyFeint', 'StepOver') else 3
                lean((0, 0, 1), direction*shift)
                targets = {support: (11*direction, 3.5, 13), active: (target[0]*direction, target[1], target[2])}
                # Solve the weight-bearing crouch before either foot. Lowering
                # hips after planting one leg would move that planted foot.
                for attempt in range(18):
                    reachable = True
                    for leg_side, toe_target in targets.items():
                        upper = rig.pose.bones['mixamorig:'+leg_side+'UpLeg']
                        shin = rig.pose.bones['mixamorig:'+leg_side+'Leg']
                        distance = (Vector(toe_target)-toe_offsets[leg_side]-upper.matrix.translation).length
                        reachable &= distance < (upper.bone.length+shin.bone.length)*.985
                    if reachable: break
                    rig.pose.bones['mixamorig:Hips'].location.y -= 1
                    bpy.context.view_layer.update()
                assert reachable, (name, frame, targets, {s: {'hip': list(rig.pose.bones['mixamorig:'+s+'UpLeg'].matrix.translation), 'offset': list(toe_offsets[s]), 'length': rig.pose.bones['mixamorig:'+s+'UpLeg'].bone.length+rig.pose.bones['mixamorig:'+s+'Leg'].bone.length} for s in feet}, list(rig.pose.bones['mixamorig:Hips'].location))
                for leg_side, toe_target in targets.items(): place_leg(leg_side, toe_target)
                arms(.35, direction*2)
            for bone in rig.pose.bones:
                if bone.name in previous: bone.rotation_quaternion.make_compatible(previous[bone.name])
                previous[bone.name] = bone.rotation_quaternion.copy()
                for prop in ['location', 'rotation_quaternion']:
                    bone.keyframe_insert(prop, frame=frame, group=bone.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = 'BEZIER'
                key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'
        scene.frame_set(19)
        actual = rig.pose.bones['mixamorig:'+active+'Toe_End'].matrix.translation
        assert (actual-Vector((-9*direction, 4, 50))).length < .1, (name, list(actual))
        metadata = {'clip': name, 'event': 'ball_contact', 'frame': 18, 'fps': 60,
                    'time_seconds': .3, 'bone': 'mixamorig_'+active+'Toe_End'}
        (OUT/(kind.lower()+'_'+suffix.lower()+'_contact.json')).write_text(json.dumps(metadata, indent=2)+'\n')
        report['clips'][name] = {'duration': .7, 'contact_seconds': .3, 'contact_toe_cm': list(actual), 'samples': []}
        for frame in range(1, 44):
            scene.frame_set(frame)
            report['clips'][name]['samples'].append({n: list(rig.pose.bones['mixamorig:'+n].matrix.translation)
                for n in ['Hips', 'LeftFoot', 'RightFoot', 'LeftHand', 'RightHand']})
        new.append(action)

rig.animation_data.action = None
shield = bpy.data.actions.new('AN_Beechlawn_Shield')
shield.use_fake_user = True
rig.animation_data.action = shield
for frame, amount in [(1, .45), (16, .50), (31, .45), (46, .40), (61, .45)]:
    scene.frame_set(frame)
    restore()
    lean((1, 0, 0), 4)
    arms(amount)
    for bone in rig.pose.bones:
        if any(part in bone.name for part in ('Spine', 'Shoulder', 'Arm', 'Hand')):
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
for curve in shield.fcurves:
    for key in curve.keyframe_points:
        key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'
new.append(shield)
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in new:
        bpy.data.actions.remove(action, do_unlink=True)
for obj in list(bpy.data.objects):
    if obj != rig:
        bpy.data.objects.remove(obj, do_unlink=True)
rig.animation_data.action = new[0]
scene.frame_set(1)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.context.preferences.filepaths.save_version = 0
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'football_skill_actions.blend'), compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'skill_actions.glb'), export_format='GLB', use_selection=True,
    export_yup=True, export_animations=True, export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
    export_skins=True, export_leaf_bone=False, export_rest_position_armature=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
assert hashlib.sha256(shipping.read_bytes()).hexdigest() == shipping_hash
EVIDENCE.mkdir(parents=True, exist_ok=True)
(EVIDENCE/'animation_audit.json').write_text(json.dumps(report, indent=2)+'\n')
print('SKILL_ANIMATIONS_EXPORTED', len(new), flush=True)
