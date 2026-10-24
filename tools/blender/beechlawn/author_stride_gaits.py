"""Original phase-aligned stance/recovery loops on the unchanged shared rig.

Animation-only add-on. Godot owns movement and contact; only the locomotion
branch changes cadence. Five 60 Hz, one-second normalized phase loops.
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
EVIDENCE = ROOT/'games/beechlawn_rovers/docs/art_briefs/br021_stride_2026_10_24'
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

def foot(side,target,pitch=0):
    turn=Quaternion((1,0,0),pitch)
    limb(side,'UpLeg','Leg',Vector(target)-turn @ toe_offsets[side],(0,0,1))
    b=rig.pose.bones['mixamorig:'+side+'Foot']
    mat=(turn @ foot_rest[side].to_quaternion()).to_matrix().to_4x4()
    mat.translation=b.matrix.translation
    b.rotation_quaternion=local_rotation(b,mat,b.parent.matrix)[0]
    bpy.context.view_layer.update()

new=[]
audit={'fps':60,'normalized_cycle_seconds':1.0,'provenance':'Original bpy-authored planted-foot loops; no extracted motion','clips':{}}
for name,speed,cadence,span,front,lift,hip_y,bob in [
    ('Walk',1.5,1.14,.70,.59,.14,93,1.5),
    ('SlowJog',3.,1.333333333,.66,.55,.22,88,3),
    ('Jog',6.,1.5,.94,.70,.32,84,5),
    ('Sprint',8.6,1.875,.94,.70,.42,82,8),
    ('CloseControl',3.36,1.333333333,.66,.55,.21,87,3)]:
    rig.animation_data.action=None
    action=bpy.data.actions.new('AN_Beechlawn_'+name+'_Footwork')
    action.use_fake_user=True
    rig.animation_data.action=action
    stance=span*cadence/speed
    samples=[]
    previous={}
    for frame in range(1,62):
        scene.frame_set(frame)
        restore()
        phase=(frame-1)/60
        # Two support phases per cycle, with a small flight rise between them.
        left=phase%1
        right=(phase+.5)%1
        support=left<stance or right<stance
        flight=min((left-stance)%1,(right-stance)%1)/max(.01,.5-stance)
        hips=rig.pose.bones['mixamorig:Hips']
        hips.location.y+=hip_y-99.791954+(0 if support else bob*math.sin(math.pi*min(1,flight)))
        bpy.context.view_layer.update()
        lean={'Walk':0,'SlowJog':2,'Jog':4,'Sprint':7,'CloseControl':3}[name]
        mat=(Quaternion((1,0,0),math.radians(lean)) @ hips.matrix.to_quaternion()).to_matrix().to_4x4()
        mat.translation=hips.matrix.translation
        hips.matrix=mat
        bpy.context.view_layer.update()
        for side,p,ss in [('Left',left,1),('Right',right,-1)]:
            pitch=0
            if p<stance:
                z=front-span*p/stance
                y=.05
            else:
                q=(p-stance)/(1-stance)
                smooth=q*q*(3-2*q)
                z=front-span+span*smooth
                y=.05+lift*math.sin(math.pi*q)
                pitch=math.radians(18)*math.sin(math.tau*q)
            foot(side,(ss*10.5,y*100,z*100),pitch)
            # Straight toe joints retain the rest-shaped sole during support.
            for part in ['ToeBase','Toe_End']:
                toe=rig.pose.bones['mixamorig:'+side+part]
                toe.rotation_quaternion=(1,0,0,0)
            bpy.context.view_layer.update()
        # Contralateral arm swing follows the shared gait phase. Walking uses
        # a relaxed low hand, running a bent elbow; wrists follow the forearm
        # instead of retaining the open, forward-facing idle hand orientation.
        arm_shapes={'Walk':(-10,4,14),'SlowJog':(5,14,10),
                    'Jog':(18,16,13),'Sprint':(21,18,15),'CloseControl':(12,16,11)}
        height_offset,forward,swing_size=arm_shapes[name]
        for side,ss in [('Left',1),('Right',-1)]:
            swing=-math.cos(math.tau*phase)*ss
            wrist=(ss*(21 if name=='Walk' else 24),hips.matrix.translation.y+height_offset+3*swing,forward+swing_size*swing)
            limb(side,'Arm','ForeArm',wrist,(ss*.3,-.5,-1))
            hand=rig.pose.bones['mixamorig:'+side+'Hand']
            forearm=rig.pose.bones['mixamorig:'+side+'ForeArm']
            point(side+'Hand',hand.matrix.translation+(hand.matrix.translation-forearm.matrix.translation).normalized()*15)
        for bone in rig.pose.bones:
            if bone.name in previous:bone.rotation_quaternion.make_compatible(previous[bone.name])
            previous[bone.name]=bone.rotation_quaternion.copy()
            for prop in ['location','rotation_quaternion']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
        samples.append({n:list(rig.pose.bones['mixamorig:'+n].matrix.translation) for n in ['Hips','LeftToe_End','RightToe_End','LeftFoot','RightFoot']})
    # Dense solved samples retain the linear stance velocity; interpolation
    # should not ease the planted foot to a stop in actor space.
    for curve in action.fcurves:
        for key in curve.keyframe_points:key.interpolation='LINEAR'
    audit['clips'][action.name]={'reference_speed':speed,'cadence':cadence,'stance_phase':stance,'span_m':span,'front_m':front,'samples':samples}
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
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'football_stride_gaits.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'stride_gaits.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,
    export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
for path,expected in protected.items():assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,path
(EVIDENCE/'animation_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('STRIDE_GAITS_EXPORTED',len(new),flush=True)

