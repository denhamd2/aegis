"""Original stadium box net, independent rear stanchions and tension fittings.
Blender +X spans mouth, +Y behind, Z up; Godot X/Y/-Z net contract matches park.
"""
from pathlib import Path
import math,json
import bpy,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/environment/stadium_goal';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,c,rough,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=(*c,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
 return m
paint=material('WhitePowderCoat',(.88,.90,.88),.33)
alloy=material('GalvanisedFittings',(.36,.39,.40),.42,1)
rope=material('WhiteKnottedPolyethylene',(.79,.81,.75),.94)
def tube(name,a,b,r=.06,mat=paint,segments=24):
 a,b=Vector(a),Vector(b)
 bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
 for p in o.data.polygons:p.use_smooth=True
 return o
for side in [-1,1]:
 tube('MouthPost', (side*3.72,0,0),(side*3.72,0,2.50))
 tube('RearNetPole',(side*4.12,2.68,0),(side*4.12,2.68,3.05),.034,paint,16)
 tube('RearPoleFoot',(side*4.12,2.68,.015),(side*4.12,2.68,.10),.10,alloy,16)
 tube('NetTensionCord',(side*3.72,2.15,2.48),(side*4.12,2.68,3.02),.009,rope,8)
 tube('RearGuyWire',(side*4.12,2.68,2.92),(side*4.48,3.20,.04),.005,alloy,6)
 tube('GroundRail',(side*3.72,0,.025),(side*3.72,2.15,.025),.025,alloy,10)
 for y in [0,.55,1.1,1.65,2.15]:
  tube('GroundNetPeg',(side*3.72,y,.01),(side*3.72,y,.065),.013,alloy,8)
tube('Crossbar',(-3.78,0,2.50),(3.78,0,2.50))
tube('RearGroundRail',(-3.72,2.15,.025),(3.72,2.15,.025),.025,alloy,10)
tube('RearTopNetCord',(-3.72,2.15,2.46),(3.72,2.15,2.46),.012,rope,8)
# The small knot/rope texture carries correct physical cell scale, not a large
# opaque overlay. Fine rope geometry supplies dimensional detail nearby.
size=128;pixels=np.zeros((size,size,4),dtype='float32');pixels[:,:,:3]=(.83,.85,.80)
for y in range(size):
 for x in range(size):
  line=min(x,size-1-x,y,size-1-y)<2
  knot=min(x,size-1-x)<4 and min(y,size-1-y)<4
  pixels[y,x,3]=1 if line or knot else 0
im=bpy.data.images.new('StadiumNetGrid',width=size,height=size,alpha=True);im.pixels.foreach_set(pixels.ravel());im.file_format='PNG';im.filepath_raw=str(OUT/'net_grid.png');im.save()
node=rope.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
rope.node_tree.links.new(node.outputs['Color'],rope.node_tree.nodes['Principled BSDF'].inputs['Base Color']);rope.node_tree.links.new(node.outputs['Alpha'],rope.node_tree.nodes['Principled BSDF'].inputs['Alpha']);rope.surface_render_method='DITHERED'
vertices=[];faces=[];uvs=[];pins=[]
def panel(cols,rows,fn,scale):
 start=len(vertices)
 for row in range(rows+1):
  for col in range(cols+1):
   u,v=col/cols,row/rows;vertices.append(fn(u,v));uvs.append((u*scale[0],v*scale[1]));pins.append(0.0 if col in [0,cols] or row in [0,rows] else 1.0)
 for row in range(rows):
  for col in range(cols):
   a=start+row*(cols+1)+col;faces.append((a,a+1,a+cols+2,a+cols+1))
panel(64,24,lambda u,v:(-3.72+u*7.44,2.15+.025*math.sin(math.pi*u)*math.sin(math.pi*v),v*2.46),(74.4,24.6))
for side in [-1,1]:panel(20,24,lambda u,v,s=side:(s*(3.72+.018*math.sin(math.pi*u)*math.sin(math.pi*v)),u*2.15,v*2.46),(21.5,24.6))
panel(64,20,lambda u,v:(-3.72+u*7.44,v*2.15,2.50-.04*v-.035*math.sin(math.pi*u)*math.sin(math.pi*v)),(74.4,21.5))
me=bpy.data.meshes.new('BoxNetMesh');me.from_pydata(vertices,[],faces);me.update();me.materials.append(rope)
uv=me.uv_layers.new(name='NetUV')
for p in me.polygons:
 for li in p.loop_indices:uv.data[li].uv=uvs[me.loops[li].vertex_index]
o=bpy.data.objects.new('StadiumNet',me);bpy.context.collection.objects.link(o)
# Dimensional near-net strands, merged into a single mesh and deformed by
# exactly the same impact shader. The sampled surface remains the far LOD.
parts=[]
for x in np.linspace(-3.72,3.72,76):parts.append(tube('NetRope',(x,2.15,0),(x,2.15,2.46),.0018,rope,4))
for z in np.linspace(0,2.46,26):parts.append(tube('NetRope',(-3.72,2.15,z),(3.72,2.15,z),.0018,rope,4))
for side in [-1,1]:
 for y in np.linspace(0,2.15,23):parts.append(tube('NetRope',(side*3.72,y,0),(side*3.72,y,2.46),.0018,rope,4))
 for z in np.linspace(0,2.46,26):parts.append(tube('NetRope',(side*3.72,0,z),(side*3.72,2.15,z),.0018,rope,4))
for x in np.linspace(-3.72,3.72,76):parts.append(tube('NetRope',(x,0,2.5),(x,2.15,2.46),.0018,rope,4))
for y in np.linspace(0,2.15,23):parts.append(tube('NetRope',(-3.72,y,2.5-y*.04/2.15),(3.72,y,2.5-y*.04/2.15),.0018,rope,4))
bpy.ops.object.select_all(action='DESELECT')
for p in parts:p.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();near=bpy.context.object;near.name='StadiumNetNear'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Near ropes use opaque PBR; runtime supplies the impact deformation.
opaque=material('DimensionalNetRope',(.82,.84,.79),.94);near.data.materials.clear();near.data.materials.append(opaque)
for p in near.data.polygons:p.material_index=0
# Remove unused source atlases and store project-relative texture references.
for unused in list(bpy.data.materials):
 if unused.users==0:bpy.data.materials.remove(unused)
for image in list(bpy.data.images):
 if image.users==0:bpy.data.images.remove(image)
 elif image.filepath and image.source=='FILE':
  image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(Path(__file__).resolve().parent))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/stadium_goal.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'stadium_goal.glb'),export_format='GLB',export_yup=True,export_animations=False)
(OUT/'profile.json').write_text(json.dumps({'mouth':[7.32,2.44],'frame_radius':.06,'depth':2.15,'net_height':2.46,'rear_poles':[[-4.12,3.05,-2.68],[4.12,3.05,-2.68]],'net_cell_metres':.10,'reference':'goal-reference-70150.jpg','inferred':['rear depth and unseen fittings'],'axes':'X across, Y up, negative Z behind'},indent=2)+'\n')
print('STADIUM_GOAL_EXPORTED',len(me.polygons)*2,'net tris, dimensional ropes',len(near.data.polygons)*2,flush=True)
