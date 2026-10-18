"""Original regulation park goal guided by the archived goal/net object sheet.

Blender +X spans the mouth, +Y points behind goal, Z is up. No rear stanchions.
The render net is separate from the simple Godot collision frame.
"""
from pathlib import Path
import math,random
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/environment/kilmore/park_goal.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def material(name,color,roughness):
    m=bpy.data.materials.new(name);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=roughness
    return m

paint=material('ParkGoal_WeatheredCream',(.74,.72,.64),.79)
image=bpy.data.images.new('Original_GoalPaintWear',width=256,height=256)
rng=random.Random(19);pixels=[]
for y in range(256):
    for x in range(256):
        rust=math.sin(x*.47+math.sin(y*.13))*math.cos(y*.37+x*.11)>.88
        c=(.26,.12,.035) if rust else (.72,.71,.65)
        grain=rng.uniform(.91,1.04);pixels.extend((*[v*grain for v in c],1))
image.pixels.foreach_set(pixels);image.pack()
tex=paint.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
paint.node_tree.links.new(tex.outputs['Color'],paint.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

def tube(name,a,b):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.06,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object;obj.name=name;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(paint)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

tube('LeftPost',(-3.72,0,0),(-3.72,0,2.50))
tube('RightPost',(3.72,0,0),(3.72,0,2.50))
tube('Crossbar',(-3.78,0,2.50),(3.78,0,2.50))
net=material('ParkGoal_KnottedNet',(.68,.66,.56),.96)
image=bpy.data.images.new('Original_NetGrid_RGBA',width=128,height=128,alpha=True)
pixels=[]
for y in range(128):
    for x in range(128):
        edge=min(x,127-x,y,127-y)<2
        knot=(min(x,127-x)**2+min(y,127-y)**2)<20
        pixels.extend((.68,.66,.56,1.0 if edge or knot else 0.0))
image.pixels.foreach_set(pixels);image.pack()
nodes=net.node_tree.nodes;links=net.node_tree.links
tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT'
cut=nodes.new('ShaderNodeMath');cut.operation='GREATER_THAN';cut.inputs[1].default_value=.4
links.new(tex.outputs['Color'],nodes['Principled BSDF'].inputs['Base Color'])
links.new(tex.outputs['Alpha'],cut.inputs[0]);links.new(cut.outputs[0],nodes['Principled BSDF'].inputs['Alpha'])
net.surface_render_method='DITHERED'
vertices=[];faces=[];coords=[]
def panel(cols,rows,point,tiles):
    start=len(vertices)
    for row in range(rows+1):
        for col in range(cols+1):
            u,v=col/cols,row/rows
            vertices.append(point(u,v));coords.append((u*tiles[0],v*tiles[1]))
    for row in range(rows):
        for col in range(cols):
            a=start+row*(cols+1)+col;faces.append((a,a+1,a+cols+2,a+cols+1))
panel(32,12,lambda u,v:(-3.72+7.44*u,1.8+.14*math.sin(math.pi*u)*math.sin(math.pi*v),v*2.28-.10*math.sin(math.pi*u)*v),(62,19))
for side in (-1,1):
    panel(10,12,lambda u,v,s=side:(s*(3.72+.07*math.sin(math.pi*u)*math.sin(math.pi*v)),u*1.8,v*(2.50-.22*u)),(15,20))
panel(32,10,lambda u,v:(-3.72+7.44*u,v*1.8,2.50-.22*v-.12*math.sin(math.pi*u)*math.sin(math.pi*v)),(62,15))
mesh=bpy.data.meshes.new('SaggingNetMesh');mesh.from_pydata(vertices,[],faces);mesh.update()
uv=mesh.uv_layers.new(name='NetUV')
for p in mesh.polygons:
    for li in p.loop_indices:uv.data[li].uv=coords[mesh.loops[li].vertex_index]
obj=bpy.data.objects.new('SaggingNet',mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(net)
OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/park_goal.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
print('PARK_GOAL_EXPORT',OUT,'net_triangles',len(faces)*2,'clear_mouth_m',7.32,2.44)
