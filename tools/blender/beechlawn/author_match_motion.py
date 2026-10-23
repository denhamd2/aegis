"""Original shared gait arms, standing poke and keeper action library.

Animation-only export preserves the production body, heads, kit and leg curves.
Blender source axes are centimetres, Y up and Z forward. Run bounded with
--python-exit-code 1. No proprietary motion data is used.
"""
import bpy, math, sys, json, hashlib
from pathlib import Path
from mathutils import Vector, Quaternion
sys.path.insert(0,str(Path(__file__).resolve().parent))
from shane_leg_retarget import minimum_roll_pose, local_rotation
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/characters/shared'
SOURCE=Path(__file__).with_name('footballer_shared.blend')
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene;scene.render.fps=60;scene.render.fps_base=1
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
foot_rest={s:rig.pose.bones['mixamorig:'+s+'Foot'].matrix.copy() for s in ['Left','Right']}
def restore():
    for b in rig.pose.bones:b.location,b.rotation_quaternion,b.scale=base[b.name]
    bpy.context.view_layer.update()
def point(name,target):
    b=rig.pose.bones['mixamorig:'+name]
    mat=minimum_roll_pose(b,b.parent.matrix,Vector(target)-b.matrix.translation,b.matrix.translation)
    b.rotation_quaternion=local_rotation(b,mat,b.parent.matrix)[0]
    bpy.context.view_layer.update()
def limb(side,upper_name,lower_name,target,pole):
    upper=rig.pose.bones['mixamorig:'+side+upper_name];lower=rig.pose.bones['mixamorig:'+side+lower_name]
    start=upper.matrix.translation.copy();axis=Vector(target)-start;d=axis.length;axis.normalize()
    a,b=upper.bone.length,lower.bone.length
    d=min(d,a+b-.05);along=(a*a-b*b+d*d)/(2*d)
    bend=Vector(pole);bend=(bend-axis*bend.dot(axis)).normalized()
    joint=start+axis*along+bend*math.sqrt(max(0,a*a-along*along))
    point(side+upper_name,joint);point(side+lower_name,target)
def arms(side,hand):
    # Exact two-bone wrist target, stable forward/outward elbow pole.
    limb(side,'Arm','ForeArm',hand,Vector((.35 if side=='Left' else -.35,-1,.15)))
def plant(side):
    f=foot_rest[side];limb(side,'UpLeg','Leg',f.translation,(0,0,1))
    bone=rig.pose.bones['mixamorig:'+side+'Foot'];mat=f.copy();mat.translation=bone.matrix.translation
    bone.rotation_quaternion=local_rotation(bone,mat,bone.parent.matrix)[0];bpy.context.view_layer.update()
def keys(frame,bones=None):
    for b in bones or rig.pose.bones:
        for prop in ['location','rotation_quaternion']:b.keyframe_insert(prop,frame=frame,group=b.name)
new=[];audit={'source_sha256':source_hash,'fps':60,'clips':{}}
# Original leg and root curves are copied verbatim. Replace only the arm chains.
for name in ['AN_Beechlawn_Jog','AN_Beechlawn_Sprint','AN_Beechlawn_WarmupJog']:
    original=bpy.data.actions.get(name)
    if original is None:continue
    action=original.copy();action.name=name+'_Arms';rig.animation_data.action=action
    for fc in list(action.fcurves):
        if any('mixamorig:'+side+suffix+'"' in fc.data_path for side in ['Left','Right'] for suffix in ['Arm','ForeArm','Hand']):action.fcurves.remove(fc)
    start,end=map(int,original.frame_range)
    samples=[]
    for frame in range(start,end+1,2):
        scene.frame_set(frame)
        phase=(frame-start)/(end-start)*math.tau
        for side,sign in [('Left',1),('Right',-1)]:
            swing=math.sin(phase)*sign
            # Wrist remains in front of torso, elbow swings modestly behind it.
            arms(side,(sign*24,125+7*swing,23+16*swing))
            wrist=rig.pose.bones['mixamorig:'+side+'Hand'].matrix.translation
            samples.append(wrist.z)
        keys(frame,[rig.pose.bones['mixamorig:'+s+n] for s in ['Left','Right'] for n in ['Arm','ForeArm','Hand']])
    # Duplicate first pose at last frame for seamless looping.
    scene.frame_set(start);poses={b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in rig.pose.bones if any(x in b.name for x in ['Arm','Hand'])}
    scene.frame_set(end)
    for name_b,(loc,rot) in poses.items():
        b=rig.pose.bones[name_b];b.location=loc;b.rotation_quaternion=rot;keys(end,[b])
    assert min(samples)>0, (name,'wrist behind torso')
    audit['clips'][name+'_Arms']={'minimum_wrist_forward_cm':min(samples),'duration':(end-start)/60}
    new.append(action)
for style in ['StandingTackle','KeeperCatch','KeeperLowCenter','KeeperLowLeft','KeeperLowRight','KeeperDiveLeft','KeeperDiveRight','KeeperHigh']:
    rig.animation_data.action=None;action=bpy.data.actions.new('AN_Beechlawn_'+style);action.use_fake_user=True;rig.animation_data.action=action
    end=55 if style=='StandingTackle' else 79
    for frame,amount in [(1,0),(7,.25),(16,1),(23,1),(37,.5),(end,0)]:
        scene.frame_set(frame);restore()
        if style=='StandingTackle':
            if amount:
                foot=rig.pose.bones['mixamorig:RightFoot'];ankle=foot_rest['Right'].translation+Vector((0,3*amount,43*amount))
                limb('Right','UpLeg','Leg',ankle,(0,0,1));plant('Left')
                for side,sign in [('Left',1),('Right',-1)]:arms(side,(sign*29,116,25))
        else:
            low='Low' in style;dive='Dive' in style;high='High' in style
            sign=1 if 'Left' in style else -1
            hips=rig.pose.bones['mixamorig:Hips'];hips.location.y-=(80 if low else 23 if dive else 0)*amount
            bpy.context.view_layer.update()
            if dive:
                bone=rig.pose.bones['mixamorig:Spine']
                target=bone.matrix.copy();rot=Quaternion((0,0,1),math.radians(-sign*40*amount))
                target=(rot@target.to_quaternion()).to_matrix().to_4x4();target.translation=bone.matrix.translation
                bone.rotation_quaternion=local_rotation(bone,target,bone.parent.matrix)[0];bpy.context.view_layer.update()
            for side,ss in [('Left',1),('Right',-1)]:
                initial=Vector((ss*20,118,35));target=Vector(((0 if 'Center' in style else sign*56)+ss*7 if low or dive else ss*10,24 if low else 112 if dive else 191 if high else 114,33))
                arms(side,initial.lerp(target,amount))
            plant('Left');plant('Right')
        keys(frame)
    for fc in action.fcurves:
        for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    scene.frame_set(16);audit['clips'][action.name]={'contact_seconds':.25,'duration':(end-1)/60,'wrists_cm':{s:list(rig.pose.bones['mixamorig:'+s+'Hand'].matrix.translation) for s in ['Left','Right']}}
    new.append(action)
rig.animation_data.action=new[0]
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
    if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
scene.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('football_match_motion.blend')),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'match_motion.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'match_motion_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
(OUT/'standing_tackle_contact.json').write_text(json.dumps({'clip':'AN_Beechlawn_StandingTackle','event':'ball_contact','frame':15,'fps':60,'time_seconds':.25},indent=2)+'\n')
print('MATCH_MOTION_EXPORTED',len(new))
