"""Original lightweight cloth grid and suspension hardware, metres, Godot GLB."""
from pathlib import Path
import bpy,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OUT=ROOT/'games/beechlawn_rovers/assets/environment/tifo';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
W,H=22.,28.;NX,NY=64,80
verts=[((u/NX-.5)*W,0,(1-v/NY)*H) for v in range(NY+1) for u in range(NX+1)]
faces=[]
for v in range(NY):
 for u in range(NX):
  a=v*(NX+1)+u;faces.append((a,a+1,a+NX+2,a+NX+1))
mesh=bpy.data.meshes.new('TifoCloth');mesh.from_pydata(verts,[],faces);mesh.update()
uv=mesh.uv_layers.new(name='UVMap')
for poly in mesh.polygons:
 poly.use_smooth=True
 for loop in poly.loop_indices:
  index=mesh.loops[loop].vertex_index;u=index%(NX+1)/NX;v=index//(NX+1)/NY;uv.data[loop].uv=(u,1-v)
cloth=bpy.data.objects.new('TifoCloth',mesh);bpy.context.collection.objects.link(cloth)
mat=bpy.data.materials.new('PrintedCotton');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
if (OUT/'rovers_tifo.png').exists():
 image=bpy.data.images.load(str(OUT/'rovers_tifo.png'));tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);mat.surface_render_method='DITHERED'
mesh.materials.append(mat)
# Remove unused source atlases and store project-relative texture references.
for unused in list(bpy.data.materials):
 if unused.users==0:bpy.data.materials.remove(unused)
for image in list(bpy.data.images):
 if image.users==0:bpy.data.images.remove(image)
 elif image.filepath and image.source=='FILE':
  image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(Path(__file__).resolve().parent))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'stadium_tifo.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'tifo_cloth.glb'),export_format='GLB',export_yup=True,export_animations=False,export_materials='NONE')
(OUT/'tifo_profile.json').write_text(json.dumps({'dimensions':[W,H],'triangles':NX*NY*2,'quote':'"I KNOW CATHY CAN BE A BITCH SOMETIMES"','portrait':'Owner references 70201 and 70199; illustrated print, no black eye','mounting':'Rovers home end, North +X / South -X; bottom 3m, top 31m'},indent=2)+'\n')
print('TIFO_EXPORTED',NX*NY*2,flush=True)
