"""Original overhead reach and airborne high dives on the unchanged shared rig.

Animation-only add-on; Godot owns the real take-off, flight and landing.
60 fps, source frame 16 maps to 0.25 s at the extension pose.
"""
from pathlib import Path
import hashlib
import json
import math
import sys

import bpy
from mathutils import Vector, Quaternion

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0,str(HERE))
from shane_leg_retarget import minimum_roll_pose, local_rotation

SOURCE = HERE/'footballer_shared.blend'
OUT = ROOT/'games/beechlawn_rovers/assets/characters/shared'
EVIDENCE = ROOT/'games/beechlawn_rovers/docs/art_briefs/br009_high_shots_2026_10_24'
protected = {SOURCE:hashlib.sha256(SOURCE.read_bytes()).hexdigest(), OUT/'footballer_base.glb':hashlib.sha256((OUT/'footballer_base.glb').read_bytes()).hexdigest()}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 60
scene.render.fps_base = 1
rig = next(o for o in scene.objects if o.type=='ARMATURE')
old_objects,old_actions=set(bpy.data.objects),set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(OUT/'footballer_base.glb'))
imported=next(o for o in bpy.data.objects if o not in old_objects and o.type=='ARMATURE')
imported.animation_data.action=next(a for a in bpy.data.actions if a not in old_actions and a.name.startswith('AN_Beechlawn_Idle'))
scene.frame_set(1)
bpy.context.view_layer.update()
poses={}
for bone in rig.pose.bones:
    other=imported.pose.bones.get(bone.name) or imported.pose.bones.get(bone.name.replace('mixamorig:','mixamorig_'))
    poses[bone.name]=rig.matrix_world.inverted() @ imported.matrix_world @ other.matrix
rig.animation_data.action=None
for bone in rig.pose.bones:
    bone.matrix=poses[bone.name]
    bpy.context.view_layer.update()
for obj in list(bpy.data.objects):
    if obj not in old_objects:bpy.data.objects.remove(obj,do_unlink=True)
for action in list(bpy.data.actions):
    if action not in old_actions:bpy.data.actions.remove(action,do_unlink=True)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
foot_rest={s:rig.data.bones['mixamorig:'+s+'Foot'].matrix_local.copy() for s in ['Left','Right']}
toe_offsets={s:rig.data.bones['mixamorig:'+s+'Toe_End'].head_local-rig.data.bones['mixamorig:'+s+'Foot'].head_local for s in foot_rest}

def restore():
    for b in rig.pose.bones:b.location,b.rotation_quaternion,b.scale=base[b.name]
    bpy.context.view_layer.update()

def point(name,target):
    b=rig.pose.bones['mixamorig:'+name]
    mat=minimum_roll_pose(b,b.parent.matrix,Vector(target)-b.matrix.translation,b.matrix.translation)
    b.rotation_quaternion=local_rotation(b,mat,b.parent.matrix)[0]
    bpy.context.view_layer.update()

def limb(side,upper_name,lower_name,target,pole):
    upper=rig.pose.bones['mixamorig:'+side+upper_name]
    lower=rig.pose.bones['mixamorig:'+side+lower_name]
    start=upper.matrix.translation.copy()
    delta=Vector(target)-start
    length=delta.length
    axis=delta.normalized()
    a,b=upper.bone.length,lower.bone.length
    d=min(length,a+b-.2)
    bend=Vector(pole)
    bend=(bend-axis*bend.dot(axis)).normalized()
    along=(a*a-b*b+d*d)/(2*d)
    joint=start+axis*along+bend*math.sqrt(max(0,a*a-along*along))
    point(side+upper_name,joint)
    point(side+lower_name,start+axis*d)

def arm(side,target):
    limb(side,'Arm','ForeArm',target,(.4 if side=='Left' else -.4,-1,.2))

def foot(side,target):
    limb(side,'UpLeg','Leg',Vector(target)-toe_offsets[side],(0,0,1))
    b=rig.pose.bones['mixamorig:'+side+'Foot']
    mat=foot_rest[side].copy()
    mat.translation=b.matrix.translation
    b.rotation_quaternion=local_rotation(b,mat,b.parent.matrix)[0]
    bpy.context.view_layer.update()

new=[]
report={'fps':60,'contact_seconds':.25,'root_motion':'in-place; physical take-off and lateral drive in Godot','provenance':'Original bpy-authored keeper actions; no extracted motion','clips':{}}
for name,sign in [('KeeperHighReach',0),('KeeperHighDiveLeft',1),('KeeperHighDiveRight',-1)]:
    rig.animation_data.action=None
    action=bpy.data.actions.new('AN_Beechlawn_'+name)
    action.use_fake_user=True
    rig.animation_data.action=action
    previous={}
    for frame,amount in [(1,0),(7,.24),(16,1),(23,1),(37,.52),(55,.16),(79,0)]:
        scene.frame_set(frame)
        restore()
        if amount:
            hips=rig.pose.bones['mixamorig:Hips']
            if sign:
                hips.location.x+=sign*18*amount
                bpy.context.view_layer.update()
                mat=(Quaternion((0,0,1),math.radians(-sign*23*amount)) @ hips.matrix.to_quaternion()).to_matrix().to_4x4()
                mat.translation=hips.matrix.translation
                hips.rotation_quaternion=hips.bone.convert_local_to_pose(mat,hips.bone.matrix_local,invert=True).to_quaternion().normalized()
                bpy.context.view_layer.update()
            # Keep the toe orientation forward; tuck slightly while airborne.
            for side,ss in [('Left',1),('Right',-1)]:
                shoulder=rig.pose.bones['mixamorig:'+side+'Shoulder']
                point(side+'Shoulder',shoulder.matrix.translation+Vector((ss*20,8*amount,2)))
                foot(side,(ss*12+sign*8*amount,4+7*amount,12-8*amount))
                start=Vector((ss*20,118,35))
                target=Vector((ss*10,202,18)) if not sign else Vector((sign*75+ss*5,192 if ss==sign else 182,18))
                arm(side,start.lerp(target,amount))
        for bone in rig.pose.bones:
            if bone.name in previous:bone.rotation_quaternion.make_compatible(previous[bone.name])
            previous[bone.name]=bone.rotation_quaternion.copy()
            for prop in ['location','rotation_quaternion']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation='BEZIER'
            key.handle_left_type=key.handle_right_type='AUTO_CLAMPED'
    samples=[]
    for frame in range(1,80):
        scene.frame_set(frame)
        samples.append({n:list(rig.pose.bones['mixamorig:'+n].matrix.translation) for n in ['Hips','Head','LeftHand','RightHand','LeftFoot','RightFoot']})
    wrists={s:samples[15][s+'Hand'] for s in ['Left','Right']}
    assert max(w[1] for w in wrists.values()) > (179 if sign else 194),(name,wrists)
    report['clips'][action.name]={'duration':1.3,'wrists_cm_at_extension':wrists,'samples':samples}
    new.append(action)
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
    if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
rig.animation_data.action=new[0]
scene.frame_set(1)
bpy.context.view_layer.objects.active=rig
rig.select_set(True)
bpy.context.preferences.filepaths.save_version=0
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'football_keeper_high_saves.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'keeper_high_saves.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,
    export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
for path,expected in protected.items():assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,path
(EVIDENCE/'animation_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('KEEPER_HIGH_ANIMATIONS_EXPORTED',len(new),flush=True)
