"""Original full-stretch low/mid/high dives on the unchanged shared rig.

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
EVIDENCE = ROOT/'games/beechlawn_rovers/docs/art_briefs/br009_dives_2026_10_24'
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

def pose(sign,roll,hip_y,hip_x,wrists,toes):
    restore()
    hips=rig.pose.bones['mixamorig:Hips']
    turn=Quaternion((0,0,1),math.radians(-sign*roll))
    mat=(turn @ hips.matrix.to_quaternion()).to_matrix().to_4x4()
    mat.translation=Vector((sign*hip_x,hip_y,0))
    hips.matrix=mat
    bpy.context.view_layer.update()
    for side,ss in [('Left',1),('Right',-1)]:
        shoulder=rig.pose.bones['mixamorig:'+side+'Shoulder']
        point(side+'Shoulder',shoulder.matrix.translation+turn @ Vector((ss*20,7,2)))
        target=Vector(wrists[side]);target.x*=sign
        arm(side,target)
        point(side+'Hand',rig.pose.bones['mixamorig:'+side+'Hand'].matrix.translation+Vector((sign*20,3,3)))
        target=Vector(toes[side]);target.x*=sign
        ankle=target-turn @ toe_offsets[side]
        limb(side,'UpLeg','Leg',ankle,(0,0,1))
        b=rig.pose.bones['mixamorig:'+side+'Foot']
        m=(turn @ foot_rest[side].to_quaternion()).to_matrix().to_4x4()
        m.translation=b.matrix.translation
        b.rotation_quaternion=local_rotation(b,m,b.parent.matrix)[0]
        bpy.context.view_layer.update()

new=[]
audit={'fps':60,'contact_seconds':.25,'duration':1.8,
       'provenance':'Original bpy-authored full-stretch saves; no extracted motion',
       'root_motion':'in-place; bounded CharacterBody take-off/lateral trajectory in Godot','clips':{}}
for band,roll,hip_y,hand_y in [('Low',80,30,26),('Mid',75,68,92),('High',60,90,148)]:
    for label,sign in [('Left',1),('Right',-1)]:
        style=('KeeperHighDiveFull' if band=='High' else 'KeeperDiveFull'+band)+label
        rig.animation_data.action=None
        action=bpy.data.actions.new('AN_Beechlawn_'+style)
        action.use_fake_user=True
        rig.animation_data.action=action
        leading='Left' if sign>0 else 'Right'
        trailing='Right' if sign>0 else 'Left'
        def paired(a,b):return {leading:a,trailing:b}
        # Anticipation, extension, follow-through, side landing, brace, kneel,
        # rise and ready stance are separate authored poses.
        poses=[
          (1,None),
          (7,(-5,84,-3,paired((30,103,36),(-22,108,32)),paired((14,5,8),(-14,5,8)))),
          (16,(roll,hip_y,12,paired((125,hand_y,23),(116,hand_y+8,26)),paired((-65,10 if band=='Low' else 28,8),(-72,20 if band=='Low' else 40,-12)))),
          (23,(roll+3,hip_y,17,paired((129,hand_y,24),(116,hand_y+6,27)),paired((-60,14 if band=='Low' else 30,12),(-69,22 if band=='Low' else 42,-16)))),
          (35,(82,30,22,paired((82,22,32),(65,34,28)),paired((-60,11,12),(-68,19,-12)))),
          (47,(68,34,18,paired((47,15,35),(40,24,23)),paired((-50,10,17),(-61,12,-14)))),
          (67,(20,64,7,paired((29,44,34),(-7,56,30)),paired((4,5,28),(-24,5,-10)))),
          (88,(0,91,0,paired((22,104,32),(-22,105,32)),paired((12,5,9),(-12,5,9)))),
          (109,None)]
        previous={}
        for frame,params in poses:
            scene.frame_set(frame)
            if params is None:restore()
            else:pose(sign,*params)
            for bone in rig.pose.bones:
                if bone.name in previous:bone.rotation_quaternion.make_compatible(previous[bone.name])
                previous[bone.name]=bone.rotation_quaternion.copy()
                for prop in ['location','rotation_quaternion']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation='BEZIER'
                key.handle_left_type=key.handle_right_type='AUTO_CLAMPED'
        samples=[]
        for frame in range(1,110):
            scene.frame_set(frame)
            joints={n:list(rig.pose.bones['mixamorig:'+n].matrix.translation) for n in ['Hips','Head','LeftHand','RightHand','LeftFoot','RightFoot']}
            samples.append(joints)
        contact=samples[15]
        axis=Vector(contact['Head'])-Vector(contact['Hips'])
        lean=math.degrees(math.acos(abs(axis.normalized().y)))
        assert lean>55,(style,lean)
        audit['clips'][action.name]={'extension':contact,'roll_degrees':lean,'samples':samples}
        print('DIVE_EXTENSION',style,contact['LeftHand'],contact['RightHand'],round(lean,1),flush=True)
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
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'football_keeper_dives.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'keeper_full_dives.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,
    export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
for path,expected in protected.items():assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,path
(EVIDENCE/'animation_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('KEEPER_FULL_DIVES_EXPORTED',len(new),flush=True)

