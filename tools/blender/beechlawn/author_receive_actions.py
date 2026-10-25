"""Four original 60 Hz receiving actions on the shipping 65-bone shared rig.

Animation-only add-on. Preserve the master and all existing character exports.
Run: timeout 150s blender --disable-autoexec -b --python-exit-code 1 \
 --python tools/blender/beechlawn/author_receive_actions.py
"""
from pathlib import Path
import hashlib, json, math, sys
import bpy
from mathutils import Vector,Quaternion
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from shane_leg_retarget import minimum_roll_pose,local_rotation
OUT=ROOT/'games/beechlawn_rovers/assets/characters/shared'
EVIDENCE=ROOT/'games/beechlawn_rovers/docs/art_briefs/contextual_control_2026_10_25'
SOURCE=HERE/'footballer_shared.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene;scene.render.fps=60;scene.render.fps_base=1
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rest={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones}
old_objects,old_actions=set(bpy.data.objects),set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(OUT/'footballer_base.glb'))
imported=next(o for o in bpy.data.objects if o not in old_objects and o.type=='ARMATURE')
imported.animation_data.action=next(a for a in bpy.data.actions if a not in old_actions and a.name.startswith('AN_Beechlawn_Idle'))
scene.frame_set(1);bpy.context.view_layer.update()
poses={b.name:rig.matrix_world.inverted()@imported.matrix_world@(imported.pose.bones.get(b.name) or imported.pose.bones.get(b.name.replace('mixamorig:','mixamorig_'))).matrix for b in rig.pose.bones}
rig.animation_data.action=None
for b in rig.pose.bones:
 b.matrix=poses[b.name];bpy.context.view_layer.update()
for o in list(bpy.data.objects):
 if o not in old_objects:bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions):
 if a not in old_actions:bpy.data.actions.remove(a,do_unlink=True)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
feet={s:rig.data.bones['mixamorig:'+s+'Foot'].matrix_local.copy() for s in ['Left','Right']}
toes={s:rig.data.bones['mixamorig:'+s+'Toe_End'].head_local-rig.data.bones['mixamorig:'+s+'Foot'].head_local for s in feet}
def restore():
 for b in rig.pose.bones:b.location,b.rotation_quaternion,b.scale=base[b.name]
 bpy.context.view_layer.update()
def point(name,target):
 b=rig.pose.bones['mixamorig:'+name]
 m=minimum_roll_pose(b,b.parent.matrix,Vector(target)-b.matrix.translation,b.matrix.translation)
 b.rotation_quaternion=local_rotation(b,m,b.parent.matrix)[0];bpy.context.view_layer.update()
def limb(side,upper_name,lower_name,target,pole):
 u=rig.pose.bones['mixamorig:'+side+upper_name];l=rig.pose.bones['mixamorig:'+side+lower_name]
 start=u.matrix.translation.copy();delta=Vector(target)-start;axis=delta.normalized()
 a,b=u.bone.length,l.bone.length;d=min(delta.length,a+b-.2)
 bend=Vector(pole);bend=(bend-axis*bend.dot(axis)).normalized()
 along=(a*a-b*b+d*d)/(2*d);joint=start+axis*along+bend*math.sqrt(max(0,a*a-along*along))
 point(side+upper_name,joint);point(side+lower_name,start+axis*d)
def foot(side,target,pitch=0):
 q=Quaternion((1,0,0),pitch)
 limb(side,'UpLeg','Leg',Vector(target)-q@toes[side],(0,0,1))
 b=rig.pose.bones['mixamorig:'+side+'Foot'];m=(q@feet[side].to_quaternion()).to_matrix().to_4x4();m.translation=b.matrix.translation
 b.rotation_quaternion=local_rotation(b,m,b.parent.matrix)[0];bpy.context.view_layer.update()
 for part in ['ToeBase','Toe_End']:rig.pose.bones['mixamorig:'+side+part].rotation_quaternion=(1,0,0,0)
def smooth(t):
 t=max(0,min(1,t));return t*t*(3-2*t)
new=[];audit={'fps':60,'provenance':'Original anatomical bpy FK/IK bake on unchanged shared rest; no external/extracted motion','rest':rest,'clips':{}}
for moving in [False,True]:
 for side in ['Left','Right']:
  ss=1 if side=='Left' else -1
  mode='Move' if moving else 'Stand'
  name='AN_Beechlawn_Receive'+mode+side
  rig.animation_data.action=None;action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
  samples=[];prev={}
  for frame in range(1,32):
   scene.frame_set(frame);restore();t=(frame-1)/60
   rise=smooth(t/.12);out=smooth((t-.27)/.23);weight=rise*(1-out)
   hips=rig.pose.bones['mixamorig:Hips']
   # Moving clips supply a leg/upper-body overlay only. Solve against the
   # jog-height pelvis while the runtime support leg keeps the real gait.
   hip_y=84 if moving else 91
   hips.location.y+=hip_y-99.791954
   bpy.context.view_layer.update()
   for other,sign in [('Left',1),('Right',-1)]:
    if other==side:
     z=14+(54-14)*smooth(t/.2) if t<=.2 else 54-39*smooth((t-.2)/.30)
     y=4+8*math.sin(math.pi*min(t,.4)/.4) if t<.4 else 4
     foot(other,(sign*10.5,y,z),math.radians(-3)*weight)
    else:foot(other,(sign*11,3,-5 if moving else 7))
   # Bent balancing elbows and relaxed wrists, no hands flung behind the back.
   for other,sign in [('Left',1),('Right',-1)]:
    limb(other,'Arm','ForeArm',(sign*(24+7*weight),hip_y+14,10+ss*sign*8*weight),(sign*.3,-.5,-1))
    hand=rig.pose.bones['mixamorig:'+other+'Hand'];fore=rig.pose.bones['mixamorig:'+other+'ForeArm']
    point(other+'Hand',hand.matrix.translation+(hand.matrix.translation-fore.matrix.translation).normalized()*15)
   if frame in (1,31):restore()  # Exact shipping neutral endpoints; runtime overlay fades at these boundaries.
   for b in rig.pose.bones:
    if b.name in prev:b.rotation_quaternion.make_compatible(prev[b.name])
    prev[b.name]=b.rotation_quaternion.copy()
    for prop in ['location','rotation_quaternion']:b.keyframe_insert(prop,frame=frame,group=b.name)
   samples.append({n:list(rig.pose.bones['mixamorig:'+n].matrix.translation) for n in ['Hips','LeftToe_End','RightToe_End']})
  for fc in action.fcurves:
   for k in fc.keyframe_points:k.interpolation='LINEAR'
  new.append(action)
  meta={'clip':name,'event':'ball_contact','frame':12,'fps':60,'time_seconds':.2,'duration_seconds':.5,'foot':side.lower(),'moving':moving,'toe_at_contact_cm':samples[12][side+'Toe_End']}
  (OUT/('receive_'+mode.lower()+'_'+side.lower()+'_contact.json')).write_text(json.dumps(meta,indent=2)+'\n')
  audit['clips'][name]={'metadata':meta,'samples':samples}
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for a in list(bpy.data.actions):
 if a not in new:bpy.data.actions.remove(a,do_unlink=True)
for o in list(bpy.data.objects):
 if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data.action=new[0];scene.frame_set(1)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.context.preferences.filepaths.save_version=0
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'football_receive_actions.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'receive_actions.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
assert {b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones}==rest
(EVIDENCE/'animation_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('RECEIVE_ACTIONS_EXPORTED',len(new),json.dumps({k:v['metadata']['toe_at_contact_cm'] for k,v in audit['clips'].items()}),flush=True)
