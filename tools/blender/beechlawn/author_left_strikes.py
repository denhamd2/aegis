"""Bake left-foot strikes from the shipping right motion onto its unchanged rest.

No body/head/kit or existing action is rewritten. Godot-evaluated shipping poses, rather
than an older source action, supply motion with the actual curve interpolation.
First run: godot --headless --path games/beechlawn_rovers --script
res://tools/export_strike_motion.gd (with a hard deadline).
Mirror rest-relative global deltas, rebase each bone through its parent/rest,
and bake at 60 Hz. Gameplay retains root and ball authority.
"""
from pathlib import Path
import bpy, hashlib, json, math, struct
from mathutils import Matrix
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
PROJECT=ROOT/'games/beechlawn_rovers';OUT=PROJECT/'assets/characters/shared'
EVIDENCE=PROJECT/'docs/art_briefs/left_foot_ai_2026_10_25';EVIDENCE.mkdir(exist_ok=True)
SOURCE=HERE/'footballer_shared.blend';protected=[SOURCE,OUT/'footballer_base.glb',OUT/'advanced_actions.glb']
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene;scene.render.fps=60;scene.render.fps_base=1
rig=next(o for o in scene.objects if o.type=='ARMATURE');assert len(rig.data.bones)==65
rest={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones}
rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
reflection=Matrix.Diagonal((-1,1,1,1));inv=rig.matrix_world.inverted();created=[]
audit={'fps':60,'source_hashes':hashes,'rest':rest,'root_motion':'In place; existing gameplay movement authority','clips':{}}
runtime=json.loads((EVIDENCE/'runtime_right_motion.json').read_text())
for path,digest in runtime['sources'].items():
 assert hashlib.sha256((PROJECT/path.removeprefix('res://')).read_bytes()).hexdigest()==digest
# Inverse of the live GLB Y-up conversion plus the visual rig's PI yaw.
godot_to_blender=Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
def matrix(v):
 return Matrix(((v[0],v[3],v[6],v[9]),(v[1],v[4],v[7],v[10]),(v[2],v[5],v[8],v[11]),(0,0,0,1)))
for right,left,kind in [('PassRight','PassLeft','pass'),('ShotRight','ShotLeft','shot'),('Volley','VolleyLeft','volley'),('HalfVolley','HalfVolleyLeft','half_volley')]:
 record=runtime['clips'][kind];count=len(record['samples'])-1;name='AN_Beechlawn_'+left
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action;created.append(action)
 previous={};samples=[];max_position_error=0
 for frame in range(count+1):
  scene.frame_set(frame+1)
  sample=record["samples"][frame]
  targets={};source_positions={}
  for b in rig.pose.bones:
   opposite=b.name.replace('Left','TEMP').replace('Right','Left').replace('TEMP','Right')
   src_name=opposite.replace(':','_')
   pose=inv@godot_to_blender@matrix(sample[src_name])
   source_rest=inv@godot_to_blender@matrix(runtime['rest'][src_name])
   targets[b.name]=reflection@pose@source_rest.inverted()@reflection@b.bone.matrix_local
   source_positions[b.name]=(reflection@pose).translation
  for b in rig.pose.bones:
   if b.parent:
    local=b.bone.convert_local_to_pose(targets[b.name],b.bone.matrix_local,parent_matrix=targets[b.parent.name],parent_matrix_local=b.parent.bone.matrix_local,invert=True)
   else:local=b.bone.convert_local_to_pose(targets[b.name],b.bone.matrix_local,invert=True)
   location,rotation,scale=local.decompose();assert max(abs(x-1) for x in scale)<.0002
   if b.name in previous and previous[b.name].dot(rotation)<0:rotation.negate()
   previous[b.name]=rotation.copy();b.location=location;b.rotation_mode='QUATERNION';b.rotation_quaternion=rotation;b.scale=(1,1,1)
   b.keyframe_insert('location',frame=frame+1,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame+1,group=b.name)
  bpy.context.view_layer.update()
  error=max((b.matrix.translation-source_positions[b.name]).length*.01 for b in rig.pose.bones)
  max_position_error=max(max_position_error,error)
  samples.append({'seconds':frame/60,'left_toe':list(rig.matrix_world@rig.pose.bones['mixamorig:LeftToe_End'].matrix.translation),'right_toe':list(rig.matrix_world@rig.pose.bones['mixamorig:RightToe_End'].matrix.translation)})
 assert max_position_error<.003,(name,max_position_error)
 for fc in action.fcurves:
  for key in fc.keyframe_points:key.interpolation='LINEAR'
 meta_path=PROJECT/('assets/characters/mixamo/y_bot_'+kind+'_contact.json') if kind in ['pass','shot'] else OUT/(kind+'_contact.json')
 meta=json.loads(meta_path.read_text());meta.update(clip=name,foot='left',source_clip='AN_Beechlawn_'+right)
 (OUT/('left_'+kind+'_contact.json')).write_text(json.dumps(meta,indent=2)+'\n')
 audit['clips'][name]={'frames':count+1,'duration_seconds':count/60,'contact_seconds':meta['time_seconds'],'maximum_mirrored_joint_error_m':max_position_error,'samples':samples}
 print('LEFT_STRIKE_BAKED',name,count+1,'max_joint_error_m',max_position_error,flush=True)
# Delivery is animation-only, with no additional skinned body or texture residency.
for obj in list(bpy.data.objects):
 if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
for action in list(bpy.data.actions):
 if action not in created:bpy.data.actions.remove(action,do_unlink=True)
for mat in list(bpy.data.materials):bpy.data.materials.remove(mat)
for image in list(bpy.data.images):bpy.data.images.remove(image)
rig.animation_data.action=created[0];scene.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'football_left_strikes.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'left_strikes.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
assert rest=={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones}
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
raw=(OUT/'left_strikes.glb').read_bytes();length=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+length])
for anim in gltf['animations']:
 inputs=[gltf['accessors'][s['input']] for s in anim['samplers']];start=min(a['min'][0] for a in inputs);end=max(a['max'][0] for a in inputs)
 assert abs(start)<1e-6 and abs(end-audit['clips'][anim['name']]['duration_seconds'])<1e-5
(EVIDENCE/'source_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('LEFT_STRIKES_EXPORTED',len(created),'clips, unchanged65-bone rest and original exports',flush=True)
