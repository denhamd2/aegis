"""One textured, rigged supporter plus animated GPU crowd LODs. Blender 4.3.

Bound each invocation externally; --index selects a resumable avatar job.
Rocketbox imports/colour sampling reuse the read-only wrestling helper. All
new motions, chair fitting, textures and exports belong to Beechlawn only.
"""
from pathlib import Path
import sys,os,math,json,argparse
import bpy,bmesh,numpy as np
from mathutils import Matrix,Vector,Quaternion
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE.parent));sys.path.insert(0,str(HERE))
import rocketbox_crowd as rb
from fetch_supporter_sources import AVATARS,COMMIT
os.environ.setdefault('ROCKETBOX_DIR','/tmp/beechlawn-rocketbox')
rb.TEXTURE_LEVEL=1.0  # Daylight albedo; the wrestling look remains unchanged.
OUT=ROOT/'games/beechlawn_rovers/assets/characters/supporters';OUT.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--index',type=int,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
INDEX=args.index;NAME=AVATARS[INDEX]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
a=rb.Avatar(NAME);arm=a.arm;mesh=a.mesh_obj;scene=bpy.context.scene
gender='f' if NAME.startswith('Female') else 'm'
print('SUPPORTER_AUTHOR',INDEX,NAME,'bones',len(arm.pose.bones),flush=True)
CLIPS=[('Seated',3.0),('Attention',2.0),('Rise',.8),('Clap',2.0),('Cheer',2.4),('Disappoint',2.0),('Flag',3.0),('Sit',.9),('Stand',3.0)]
source_names=['sit_chair_idle_neutral_01','sit_chair_breathe_01','claphands_01','cheer_01','idle_neutral_01']
sources={n:rb._clip_armature(gender+'_'+n) for n in source_names}
upper=rb._upper_body(arm)
order=sorted(arm.pose.bones,key=lambda b:len(b.parent_recursive))
world_inv=arm.matrix_world.inverted()
rest_local={b.name:(b.parent.matrix_local.inverted()@b.matrix_local if b.parent else b.matrix_local).to_quaternion() for b in arm.data.bones}

# Authored from the source biped, with source rotations sampled continuously.
# Rise/sit keep both ankles on the same ground targets; the pelvis moves in
# front of its chair instead of translating the whole seated figure upward.
def source(name,phase):
 obj,start,end=sources[name]
 frame=start+(end-start)*phase
 scene.frame_set(math.floor(frame),subframe=frame%1)
 return {b.name:obj.matrix_world@b.matrix for b in obj.pose.bones}
seated=source('sit_chair_idle_neutral_01',.30)
standing=source('idle_neutral_01',.30)
root_name=order[0].name
anchor=standing[root_name].translation.copy();anchor.z=0
front=a._front();yaw=-math.atan2(front[0],-front[1]);R=Matrix.Rotation(yaw,4,'Z')
def ease(x):x=max(0,min(1,x));return x*x*(3-2*x)
def solve_leg(side,target):
 thigh=arm.pose.bones['Bip01 '+side+' Thigh'];calf=arm.pose.bones['Bip01 '+side+' Calf'];foot=arm.pose.bones['Bip01 '+side+' Foot']
 start=thigh.matrix.translation.copy();end=world_inv@Vector(target)
 axis=(end-start).normalized();l1=(calf.head-start).length;l2=(foot.head-calf.head).length
 distance=min((end-start).length,l1+l2-.01)
 pole=world_inv.to_3x3()@Vector((0,-1,0));pole=(pole-axis*pole.dot(axis)).normalized()
 along=(l1*l1-l2*l2+distance*distance)/(2*distance)
 knee=start+axis*along+pole*math.sqrt(max(0,l1*l1-along*along))
 foot_rot=foot.matrix.to_quaternion()
 for bone,child,point in [(thigh,calf,knee),(calf,foot,end)]:
  old=(child.head-bone.head).normalized();new=(point-bone.head).normalized()
  q=old.rotation_difference(new);m=bone.matrix.copy();rotation=q@m.to_quaternion()
  bone.matrix=Matrix.LocRotScale(m.translation,rotation,None);bpy.context.view_layer.update()
 m=foot.matrix.copy();foot.matrix=Matrix.LocRotScale(m.translation,foot_rot,None)
 bpy.context.view_layer.update()
def pose(kind,t):
 phase=.3+.12*math.sin(t*math.tau/3)
 low=source('sit_chair_breathe_01',phase) if kind in ['Seated','Attention','Clap','Disappoint'] else source('idle_neutral_01',phase)
 seated_weight=1.0 if kind in ['Seated','Attention','Clap','Disappoint'] else 0.0
 if kind in ['Rise','Sit']:
  f=ease(t/(.8 if kind=='Rise' else .9));seated_weight=1-f if kind=='Rise' else f
  low={n:standing[n].lerp(seated[n],seated_weight) for n in standing}
 if kind in ['Clap','Cheer','Flag']:
  motion='claphands_01' if kind=='Clap' else 'cheer_01'
  # A continuous, ping-pong excerpt avoids unrelated source entry poses.
  up=source(motion,.15+.68*(.5-.5*math.cos(t*math.tau/(2.0 if kind=='Clap' else 3.0))))
  offset=low[root_name]@up[root_name].inverted()
  low=dict(low)
  for n in upper:
   if n in up:low[n]=offset@up[n]
 # Target global rotations -> target's unchanged rest-relative bone curves.
 desired={n:(world_inv@m).to_quaternion() for n,m in low.items()}
 for b in order:
  if b.name not in desired:continue
  parent=desired.get(b.parent.name,Quaternion()) if b.parent else Quaternion()
  b.rotation_mode='QUATERNION';b.rotation_quaternion=rest_local[b.name].inverted()@parent.inverted()@desired[b.name]
  b.location=(0,0,0)
 root=arm.pose.bones[root_name]
 p=low[root_name].translation.copy();p.x=anchor.x;p.y=anchor.y-.25*(1-seated_weight)
 p.z-=.095*seated_weight
 # Root location keys live in the bone's rest basis, not armature axes.
 root.location=root.bone.matrix_local.inverted()@(world_inv@p)
 if kind in ['Attention','Disappoint']:
  spine=arm.pose.bones['Bip01 Spine1'];spine.rotation_quaternion@=Quaternion((1,0,0),math.radians(10 if kind=='Attention' else 15))
  if kind=='Disappoint':arm.pose.bones['Bip01 Head'].rotation_quaternion@=Quaternion((1,0,0),math.radians(12))
 bpy.context.view_layer.update()
 for side in ['L','R']:
  original=standing['Bip01 '+side+' Foot'].translation
  solve_leg(side,(original.x,anchor.y-.25,max(.075,original.z)))

# One compact photographic atlas, remapped independently of body topology.
folder=rb.rocketbox_root()/'Assets/Avatars/Adults'/NAME/'Textures'
atlas=Image.new('RGBA',(1024,1024),(120,120,120,255));regions={'body':(0,0),'head':(512,0),'opacity':(0,512)}
for f in folder.glob('*_color.tga'):
 kind=f.stem.split('_')[1]
 if kind in regions:atlas.paste(Image.open(f).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS),regions[kind])
atlas_path=OUT/('fan_%02d.png'%INDEX);atlas.save(atlas_path)
data=mesh.data;uv=data.uv_layers.active.data
kinds=[m.name.split('_')[-1] if m else 'body' for m in data.materials]
for poly in data.polygons:
 kind=kinds[poly.material_index];x,y=regions.get(kind,(0,0))
 for loop in poly.loop_indices:
  u,v=uv[loop].uv;uv[loop].uv=((x+u*512)/1024,1-(y+(1-v)*512)/1024)
mat=bpy.data.materials.new('SupporterPhoto_%02d'%INDEX);mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.86
image=bpy.data.images.load(str(atlas_path));tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
data.materials.clear();data.materials.append(mat)
for p in data.polygons:p.material_index=0;p.use_smooth=True

# Preserve the imported rig/rest and attach an export normalization above it.
normalizer=bpy.data.objects.new('Supporter_%02d'%INDEX,None);scene.collection.objects.link(normalizer)
normalizer.matrix_world=R@Matrix.Translation(-anchor)
for obj in [arm,mesh]:
 if obj.parent is None:
  old=obj.matrix_world.copy();obj.parent=normalizer;obj.matrix_world=old
if arm.animation_data:arm.animation_data.action=None
scene.render.fps=30;scene.render.fps_base=1
actions=[];hand_samples={}
for kind,duration in CLIPS:
 action=bpy.data.actions.new('Fan_'+kind);action.use_fake_user=True;arm.animation_data_create();arm.animation_data.action=action
 previous={}
 for frame in range(round(duration*30)+1):
  scene.frame_set(frame+1);pose(kind,frame/30)
  for b in order:
   if b.name in previous:b.rotation_quaternion.make_compatible(previous[b.name])
   previous[b.name]=b.rotation_quaternion.copy();b.keyframe_insert('rotation_quaternion',frame=frame+1,group=b.name)
  arm.pose.bones[root_name].keyframe_insert('location',frame=frame+1,group=root_name)
 for curve in action.fcurves:
  for key in curve.keyframe_points:key.interpolation='LINEAR'
 actions.append(action)
 print('SUPPORTER_CLIP',INDEX,kind,round(duration*30)+1,flush=True)
arm.animation_data.action=None

# Apply the static decimation before skinning, retaining weights/UV/attributes.
base_mesh=mesh.data.copy();lods=[];decoded=0;bounds=[]
for lod,budget in enumerate([600,100,32]):
 obj=bpy.data.objects.new('CrowdLOD%d'%lod,base_mesh.copy());scene.collection.objects.link(obj)
 obj.matrix_world=mesh.matrix_world.copy()
 for group in mesh.vertex_groups:obj.vertex_groups.new(name=group.name)
 for vertex in mesh.data.vertices:
  for g in vertex.groups:obj.vertex_groups[g.group].add([vertex.index],g.weight,'REPLACE')
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 dec=obj.modifiers.new('LOD','DECIMATE');dec.ratio=budget/a.full_tris;dec.use_collapse_triangulate=True
 bpy.ops.object.modifier_apply(modifier=dec.name)
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
 bm.to_mesh(obj.data);bm.free()
 skin=obj.modifiers.new('Skin','ARMATURE');skin.object=arm
 me=obj.data;me.calc_loop_triangles();nv=len(me.vertices)
 uvs=np.zeros((nv,2));seen=set()
 for loop in me.loops:
  if loop.vertex_index not in seen:uvs[loop.vertex_index]=me.uv_layers.active.data[loop.index].uv;seen.add(loop.vertex_index)
 colours=np.array([v.color[:] for v in me.color_attributes['Col'].data]);shirt=np.array([v.color[0] for v in me.color_attributes['Info'].data])
 triangles=np.array([list(tri.vertices) for tri in me.loop_triangles],dtype=int)
 clips={};positions=[];normals=[];total=0
 for action,(kind,duration) in zip(actions,CLIPS):
  arm.animation_data.action=action;n=round(duration*15)+1;start=total
  if lod==0:hand_samples[kind]=[]
  for frame in range(n):
   scene.frame_set(1+frame*2)
   if lod==0:
    hand=normalizer.matrix_world@arm.matrix_world@arm.pose.bones['Bip01 R Hand'].head
    hand_samples[kind].append([hand.x,hand.z,-hand.y])
   dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);evaluated=ev.to_mesh()
   co=np.array([v.co[:] for v in evaluated.vertices]);world=np.array(normalizer.matrix_world@obj.matrix_world)
   co=co@world[:3,:3].T+world[:3,3]
   # Blender Z-up -> Godot Y-up, forward +Z.
   co=np.stack([co[:,0],co[:,2],-co[:,1]],axis=1)
   nr=np.zeros_like(co)
   cross=np.cross(co[triangles[:,1]]-co[triangles[:,0]],co[triangles[:,2]]-co[triangles[:,0]])
   for corner in range(3):np.add.at(nr,triangles[:,corner],cross)
   nr/=np.maximum(np.linalg.norm(nr,axis=1,keepdims=True),1e-8)
   positions.append(co.astype('float32'));normals.append(nr.astype('float32'));total+=1
   ev.to_mesh_clear()
  clips[kind]={'start':start,'frames':n,'duration':duration}
 width=256;height=math.ceil(nv*total/width)
 for name,samples in [('positions',positions),('normals',normals)]:
  pixels=np.zeros((height*width,4),dtype='float32');pixels[:nv*total,:3]=np.concatenate(samples);pixels[:,3]=1
  im=bpy.data.images.new('FanVAT',width=width,height=height,float_buffer=True)
  im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(pixels.ravel())
  im.filepath_raw=str(OUT/('fan_%02d_lod%d_%s.exr'%(INDEX,lod,name)));im.file_format='OPEN_EXR';scene.render.image_settings.exr_codec='ZIP';scene.render.image_settings.color_depth='16';im.save();bpy.data.images.remove(im)
  decoded+=width*height*8
 minimum=np.concatenate(positions).min(0);maximum=np.concatenate(positions).max(0);bounds.extend([minimum.tolist(),maximum.tolist()])
 spec={'vertices':positions[0].ravel().tolist(),'normals':normals[0].ravel().tolist(),'uv':uvs.ravel().tolist(),'colour':colours.ravel().tolist(),'shirt':shirt.tolist(),'indices':triangles.ravel().tolist(),'vertex_count':nv,'triangles':len(triangles),'width':width,'height':height,'clips':clips,'aabb_min':minimum.tolist(),'aabb_max':maximum.tolist()}
 (OUT/('fan_%02d_lod%d.json'%(INDEX,lod))).write_text(json.dumps(spec,separators=(',',':'))+'\n')
 lods.append({'lod':lod,'vertices':nv,'triangles':len(triangles),'decoded_bytes':width*height*16})
 bpy.data.objects.remove(obj,do_unlink=True)
 print('SUPPORTER_VAT',INDEX,lod,nv,len(triangles),total,flush=True)

# Export only this rig/mesh and its clips, with the atlas external at runtime.
arm.animation_data.action=actions[0];scene.frame_set(1)
for obj in [arm,mesh]:
 if obj.parent==normalizer:
  original_world=obj.matrix_world.copy();obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=original_world
for obj in list(bpy.data.objects):
 if obj not in [arm,mesh,normalizer]:bpy.data.objects.remove(obj,do_unlink=True)
for action in list(bpy.data.actions):
 if action not in actions:bpy.data.actions.remove(action,do_unlink=True)
scene.render.fps=30
# Remove unused source atlases and store project-relative texture references.
for unused in list(bpy.data.materials):
 if unused.users==0:bpy.data.materials.remove(unused)
for image in list(bpy.data.images):
 if image.users==0:bpy.data.images.remove(image)
 elif image.filepath and image.source=='FILE':
  image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(Path(__file__).resolve().parent))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/('supporter_%02d.blend'%INDEX)),compress=True)
# Avoid a second embedded atlas residency; the runtime binds fan_NN.png.
mat.node_tree.links.remove(bs.inputs['Base Color'].links[0])
colour=mat.node_tree.nodes.new('ShaderNodeVertexColor');colour.layer_name='Col';mat.node_tree.links.new(colour.outputs['Color'],bs.inputs['Base Color'])
bpy.ops.export_scene.gltf(filepath=str(OUT/('fan_%02d.glb'%INDEX)),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_rest_position_armature=True,export_leaf_bone=False)
(OUT/('fan_%02d_audit.json'%INDEX)).write_text(json.dumps({'avatar':NAME,'source_commit':COMMIT,'source_license':'MIT','bones':len(arm.data.bones),'clips':dict(CLIPS),'hands':hand_samples,'lods':lods,'vat_decoded_bytes':decoded,'facing':'Godot +Z, chair floor origin, pan 0.44 m','authoring_fps':30,'vat_fps':15},indent=2)+'\n')
print('SUPPORTER_COMPLETE',INDEX,NAME,decoded,flush=True)
