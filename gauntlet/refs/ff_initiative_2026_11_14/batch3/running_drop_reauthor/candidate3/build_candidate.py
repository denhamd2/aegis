import bpy,sys,json,pathlib,math,collections
REPO = next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'AGENTS.md').is_file())
sys.path.insert(0, str(REPO / 'game/tools/blender'))
import wrestling_clips as w
from rig_pose import RigPoser,vec
out = pathlib.Path(__file__).resolve().parent
arm=w.load_rig();w.clear_actions();poser=RigPoser(arm)
mesh=next(o for o in bpy.data.objects if o.type=='MESH' and len(o.vertex_groups)>0)
groups={g.index:g.name for g in mesh.vertex_groups}
regions=[groups[max(v.groups,key=lambda x:x.weight).group] if v.groups else 'none' for v in mesh.data.vertices]
print('GROUPS',collections.Counter(regions))
report={};allrows=[]
for name in ['Run_Grapple_Attacker','Run_Grapple_Defender']:
 old=w.author(poser,arm,name,w._RUN_GRAPPLE_APPROACH_BASELINE[name]);baseline=w._curve_snapshot(old)
 samples={(path,i):[fc.evaluate(t/2) for t in range(61)] for (path,i) in baseline for fc in [old.fcurves.find(path,index=i)]}
 bpy.data.actions.remove(old)
 action=w.author(poser,arm,name,w.CLIPS[name],exact_timing=True);w._guard_running_approach_curves(action,baseline)
 errors=[abs(v-fc.evaluate(t/2)) for (path,i),values in samples.items() for fc in [action.fcurves.find(path,index=i)] for t,v in enumerate(values)]
 report[name]={'prefix_0_to_30_scalar_max_delta':max(errors),'action_channels':len(action.fcurves),'range_source_frames':list(action.frame_range),'rows':[]}
 arm.animation_data.action=action
 for tick in range(66,133):
  f=tick/2;bpy.context.scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  row={'frame':f,'joints':{},'skin_floor_m':{}}
  for bone in ['pelvis','spine_03','neck_01','Head','upperarm_r','lowerarm_r','hand_r','upperarm_l','lowerarm_l','hand_l','thigh_r','calf_r','foot_r','thigh_l','calf_l','foot_l']:
   p=arm.pose.bones[bone].head;row['joints'][bone]=[-p.x,-p.y,p.z]
  deps=bpy.context.evaluated_depsgraph_get();ev=mesh.evaluated_get(deps);me=ev.to_mesh()
  for v,region in zip(me.vertices,regions):
   if region=='none':continue
   group='head' if region in ['Head','neck_01'] else 'back' if region.startswith('spine') else 'pelvis' if region=='pelvis' else 'arm' if any(s in region for s in ['arm','hand','finger','index','thumb','pinky','middle','ring']) else 'leg'
   z=(ev.matrix_world@v.co).z
   row['skin_floor_m'][group]=min(z,row['skin_floor_m'].get(group,999))
  ev.to_mesh_clear();report[name]['rows'].append(row)
 for f in [37,43,47,49,51,55,57,59,61,63,66]:
  r=next((r for r in report[name]['rows'] if r['frame']==f),None)
  if r:print('SAMPLE',name,f,r['skin_floor_m'])
 print('PREFIX',name,max(errors))
 action.use_fake_user=True
# Native source has base mesh + both editable actions; GLB stays skeleton-only.
bpy.ops.wm.save_as_mainfile(filepath='/tmp/aegis-running-wrap-candidate3.blend')
(out/'source_curve_audit.json').write_text(json.dumps(report,indent=2)+'\n')
w.drop_mesh();w.export('/tmp/aegis-running-wrap-candidate3.glb')
print('EXPORTED /tmp/aegis-running-wrap-candidate3.glb')
