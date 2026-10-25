"""Original in-place celebration/handshake clips on the unchanged football rig."""
import bpy,math,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from shane_leg_retarget import minimum_roll_pose,local_rotation
ROOT=Path(__file__).resolve().parents[3];SOURCE=Path(__file__).with_name('footballer_shared.blend')
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
OUT=ROOT/'games/beechlawn_rovers/assets/characters/shared'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene;scene.render.fps=60;scene.render.fps_base=1
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
def restore():
 for b in rig.pose.bones:b.location,b.rotation_quaternion,b.scale=base[b.name]
 bpy.context.view_layer.update()
def point(name,target):
 b=rig.pose.bones['mixamorig:'+name];mat=minimum_roll_pose(b,b.parent.matrix,Vector(target)-b.matrix.translation,b.matrix.translation)
 b.rotation_quaternion=local_rotation(b,mat,b.parent.matrix)[0];bpy.context.view_layer.update()
def handshake(amount):
 side='Right';target=Vector((-20+20*amount,118-3*amount,35-amount))
 upper=rig.pose.bones['mixamorig:RightArm'];lower=rig.pose.bones['mixamorig:RightForeArm']
 start=upper.matrix.translation.copy();axis=target-start;distance=axis.length;axis.normalize()
 a,b=upper.bone.length,lower.bone.length
 assert abs(a-b)<distance<a+b, (distance,a,b)
 along=(a*a-b*b+distance*distance)/(2*distance)
 pole=Vector((-.35,-1,.15));pole=(pole-axis*pole.dot(axis)).normalized()
 elbow=start+axis*along+pole*math.sqrt(max(0,a*a-along*along))
 point(side+'Arm',elbow);point(side+'ForeArm',target)
 point(side+'Hand',target+Vector((0,0,11)))
def arm(side,elbow,hand):
 point(side+'Arm',elbow);point(side+'ForeArm',hand)
new=[];report={'source_sha256':source_hash,'fps':60,'root_motion':'none','clips':{}}
for style in ['Celebrate','Handshake']:
 rig.animation_data.action=None;action=bpy.data.actions.new('AN_Beechlawn_'+style);action.use_fake_user=True;rig.animation_data.action=action
 frames=[(1,0),(13,.4),(25,1),(43,.85),(61,1),(79,.85),(97,1),(121,0)] if style=='Celebrate' else [(1,0),(13,1),(25,.85),(37,1),(49,.85),(61,1),(73,0)]
 for frame,amount in frames:
  scene.frame_set(frame);restore()
  if style=='Celebrate':
   for side,sign in [('Left',1),('Right',-1)]:
    arm(side,(sign*(28+7*amount),132+37*amount,12),(sign*(20+7*amount),118+82*amount,35-23*amount))
  else:
   handshake(amount)
   arm('Left',(28,135,5),(20,108,5))
   point('LeftHand',(20,96,7))
  for b in rig.pose.bones:
   for prop in ['location','rotation_quaternion']:b.keyframe_insert(prop,frame=frame,group=b.name)
 for fc in action.fcurves:
  for key in fc.keyframe_points:key.interpolation='BEZIER';key.handle_left_type='AUTO_CLAMPED';key.handle_right_type='AUTO_CLAMPED'
 new.append(action);report['clips'][style]={'duration':(frames[-1][0]-1)/60,'in_place':True}
rig.animation_data.action=new[0]
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
 if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
 if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
scene.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('football_match_presentation.blend')),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'match_presentation.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'match_presentation_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('MATCH_PRESENTATION_EXPORTED',len(new))
