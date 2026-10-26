"""Original 60 Hz brace/jump poses on the preserved shared football rest.
Physical approach/jump authority remains in Godot. Does not save the master.
"""
import bpy,sys,math,json,hashlib
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from shane_leg_retarget import minimum_roll_pose,local_rotation
ROOT=Path(__file__).resolve().parents[3];SOURCE=Path(__file__).with_name('footballer_shared.blend')
OUT=ROOT/'games/beechlawn_rovers/assets/characters/shared'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene
scene.render.fps=60;scene.render.fps_base=1
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rest_hash=hashlib.sha256(repr([(b.name,list(b.matrix_local)) for b in rig.data.bones]).encode()).hexdigest()
rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
feet={s:rig.pose.bones['mixamorig:'+s+'Foot'].matrix.copy() for s in ['Left','Right']}
for side,sign in [('Left',1),('Right',-1)]:
 feet[side].translation.x=sign*12
 feet[side].translation.z=0
def restore():
 for b in rig.pose.bones:b.location,b.rotation_quaternion,b.scale=base[b.name]
 bpy.context.view_layer.update()
def point(name,target):
 b=rig.pose.bones['mixamorig:'+name]
 m=minimum_roll_pose(b,b.parent.matrix,Vector(target)-b.matrix.translation,b.matrix.translation)
 b.rotation_quaternion=local_rotation(b,m,b.parent.matrix)[0];bpy.context.view_layer.update()
def crouch(drop):
 h=rig.pose.bones['mixamorig:Hips'];m=h.matrix.copy();m.translation.y-=drop
 if h.parent:
  basis=h.bone.convert_local_to_pose(m,h.bone.matrix_local,parent_matrix=h.parent.matrix,parent_matrix_local=h.parent.bone.matrix_local,invert=True)
 else:basis=h.bone.matrix_local.inverted()@m
 h.matrix_basis=basis;bpy.context.view_layer.update()
 for side in ['Left','Right']:
  upper=rig.pose.bones['mixamorig:'+side+'UpLeg'];lower=rig.pose.bones['mixamorig:'+side+'Leg'];foot=rig.pose.bones['mixamorig:'+side+'Foot']
  ankle=feet[side].translation;hip=upper.matrix.translation.copy();axis=(ankle-hip).normalized();d=(ankle-hip).length;a=upper.bone.length;b=lower.bone.length
  along=(a*a-b*b+d*d)/(2*d);pole=Vector((0,0,1));pole=(pole-axis*pole.dot(axis)).normalized()
  knee=hip+axis*along+pole*math.sqrt(max(0,a*a-along*along))
  point(side+'UpLeg',knee);point(side+'Leg',ankle)
  target=feet[side].copy();target.translation=foot.matrix.translation
  foot.rotation_quaternion=local_rotation(foot,target,foot.parent.matrix)[0];bpy.context.view_layer.update()
new=[]
for kind,poses in [('WallBrace',[(1,0),(31,.35),(61,0)]),('WallJump',[(1,0),(5,2.5),(11,0),(17,0),(23,2),(31,0)])]:
 rig.animation_data.action=None
 action=bpy.data.actions.new('AN_Beechlawn_'+kind);action.use_fake_user=True;rig.animation_data.action=action
 for frame,drop in poses:
  scene.frame_set(frame);restore()
  crouch(drop if kind=='WallJump' else 0)
  for side,sign in [('Left',1),('Right',-1)]:
   point(side+'Arm',(sign*23,121,12));point(side+'ForeArm',(sign*5,101,22))
   point(side+'Hand',(sign*5,88,22))
  for b in rig.pose.bones:
   for prop in ['location','rotation_quaternion']:b.keyframe_insert(prop,frame=frame,group=b.name)
 for fc in action.fcurves:
  for key in fc.keyframe_points:key.interpolation='BEZIER';key.handle_left_type='AUTO_CLAMPED';key.handle_right_type='AUTO_CLAMPED'
 new.append(action)
# Full current mesh is retained only for disposable Blender deformation review.
rig.animation_data.action=new[0];scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath='/tmp/free_kick_wall_review.blend',compress=True)
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
 if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
 if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('football_free_kick_wall.blend')),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'free_kick_wall.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'free_kick_wall_audit.json').write_text(json.dumps(dict(source_sha256=source_hash,rest_sha256=rest_hash,bones=len(rig.data.bones),fps=60,root_motion='None; Godot controls physical root',clips={a.name:(a.frame_range[1]-a.frame_range[0])/60 for a in new}),indent=2)+'\n')
print('FREE_KICK_WALL_EXPORTED',len(new),len(rig.data.bones),flush=True)
