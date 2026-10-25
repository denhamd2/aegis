"""Original Bramley-Moore reference-led public realm. Input coordinates Godot:
north +X, west -Z (verified against the shipping bank/export transforms).
Research photographs remain external; dimensions are photographic estimates.
"""
from pathlib import Path
import math,json,random
import numpy as np
from PIL import Image
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'games/beechlawn_rovers/assets/environment/rovers_arena'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,c,rough=.8,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=(*(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c),1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;return m
M={'Stone':mat('QuayGranite',(.34,.35,.33)), 'Paving':mat('PublicRealmPaving',(.46,.47,.44)),
 'Cobbles':mat('DockLineCobbles',(.27,.29,.29)), 'Brick':mat('HydraulicTowerBrick',(.31,.12,.07)),
 'Steel':mat('WharfRailings',(.09,.11,.12),.5,1),'Rust':mat('HistoricRail',(.24,.13,.07),.68,.7),
 'Slate':mat('TowerSlate',(.10,.13,.14),.72),'Glass':mat('HeritageWindows',(.035,.065,.08),.2),
 'Road':mat('RegentRoadAsphalt',(.075,.080,.078)), 'White':mat('DockPaint',(.68,.70,.65)),
 'Warehouse':mat('IndustrialWarehouse',(.29,.31,.31)), 'Tank':mat('DistantStorageTank',(.57,.60,.60),.6,.4),
 'Green':mat('PlazaPlanting',(.055,.12,.045)), 'Wood':mat('PromenadeBenches',(.20,.12,.065))}
for key,kind in [('Brick','brick'),('Stone','concrete')]:
 path=OUT/('stadium_shell_Arena_'+kind+'_Color.png')
 if path.exists():
  node=M[key].node_tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(path));M[key].node_tree.links.new(node.outputs['Color'],M[key].node_tree.nodes['Principled BSDF'].inputs['Base Color'])
# Original tileable stone paving with millimetre joints and restrained grain.
rng_image=np.random.default_rng(5027);size=1024
y,x=np.mgrid[:size,:size];u=x/size*6;v=y/size*6
edge=np.minimum(np.minimum(u%1,1-u%1),np.minimum(v%1,1-v%1))
joint=np.clip((.010-edge)/.010,0,1)
noise=rng_image.normal(0,.009,(size,size));blocks=rng_image.uniform(-.025,.025,(6,6))[np.minimum(v.astype(int),5),np.minimum(u.astype(int),5)]
base=np.clip(.48+noise+blocks-joint*.08,0,1)
colour=np.stack([base,base*.995,base*.97],axis=-1)
height=-joint*.004+rng_image.normal(0,.00006,(size,size))
dy,dx=np.gradient(height,4.5/size);normal=np.stack([-dx,dy,np.ones_like(dx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
rough=np.clip(.86+noise*2-joint*.04,0,1)
for suffix,pixels in [('Color',colour),('Normal',normal*.5+.5),('Roughness',rough)]:
 path=OUT/('DockPaving_'+suffix+'.png');Image.fromarray(np.round(pixels*255).astype('uint8')).save(path)
 image=bpy.data.images.load(str(path));image.colorspace_settings.name='sRGB' if suffix=='Color' else 'Non-Color'
 tex=M['Paving'].node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
 bs=M['Paving'].node_tree.nodes['Principled BSDF']
 if suffix=='Normal':
  node=M['Paving'].node_tree.nodes.new('ShaderNodeNormalMap');node.inputs['Strength'].default_value=.45;M['Paving'].node_tree.links.new(tex.outputs['Color'],node.inputs['Color']);M['Paving'].node_tree.links.new(node.outputs['Normal'],bs.inputs['Normal'])
 else:M['Paving'].node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color' if suffix=='Color' else 'Roughness'])
data={}
def P(v):return (v[0],-v[2],v[1])
def face(name,material,points):
 key=(name,material);verts,faces=data.setdefault(key,([],[]));start=len(verts);verts.extend(P(p) for p in points);faces.append(tuple(range(start,start+len(points))))
def box(name,material,c,s):
 x,y,z=c;a,b,d=[v*.5 for v in s]
 v=[(x-a,y-b,z-d),(x+a,y-b,z-d),(x+a,y+b,z-d),(x-a,y+b,z-d),(x-a,y-b,z+d),(x+a,y-b,z+d),(x+a,y+b,z+d),(x-a,y+b,z+d)]
 for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]:face(name,material,[v[i] for i in ids])
def beam(name,material,a,b,r,sides=8):
 a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,1,0)))
 if u.length<.1:u=axis.cross(Vector((1,0,0)))
 u.normalize();v=axis.cross(u);circle=[(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v)*r for i in range(sides)]
 for i in range(sides):j=(i+1)%sides;face(name,material,[a+circle[i],b+circle[i],b+circle[j],a+circle[j]])
 face(name,material,[a+p for p in reversed(circle)]);face(name,material,[b+p for p in circle])
# Land follows the actual dock relationship rather than filling every view
# with the old 420 x 360 m concrete rectangle.
box('StadiumLand','Paving',(0,-.36,0),(270,.4,224))
box('EasternFanPlaza','Paving',(0,-.18,147),(270,.32,70))
box('WesternWharf','Paving',(0,-.2,-152),(290,.36,13))
for z in [-126,-145]:box('DockQuayWalls','Stone',(0,-1.3,z),(282,2.6,1.2))
for x in [-136,136]:box('DockQuayWalls','Stone',(x,-1.3,-25),(1.4,2.6,200))
for z in [-126,-145]:box('GraniteQuayCaps','Stone',(0,.04,z),(284,.18,1.35))
for x in [-136,136]:box('GraniteQuayCaps','Stone',(x,.04,-25),(1.6,.18,201))
for step in range(9):
 z=-111-step*1.5;box('WesternTerraceSteps','Stone',(0,.15+(8-step)*.14,z),(220,.3+step*.02,1.55))
for x in [-90,90]:box('ChannelCrossing','Paving',(x,.1,-135),(9,.45,20))
# Lattice railings and mooring bollards read strongly in low exterior shots.
for z in [-125,-146,-158]:
 for x in range(-130,131,3):
  beam('WharfRailings','Steel',(x,.2,z),(x,1.25,z),.028)
  for y in [.35,.75,1.22]:beam('WharfRailings','Steel',(x,y,z),(x+3,y,z),.018)
  beam('WharfRailings','Steel',(x,1.0,z),(x+3,1.25,z),.016);beam('WharfRailings','Steel',(x,1.25,z),(x+3,1.0,z),.016)
for x in range(-125,126,18):
 for z in [-125,-146]:
  beam('MooringBollards','Steel',(x,.1,z),(x,.48,z),.12,10);beam('MooringBollards','Steel',(x-.20,.4,z),(x+.20,.4,z),.09,8)
# Historic basin outline, retained railway traces and planted arrival plaza.
for z in [126,163]:box('FormerDockOutline','Cobbles',(0,.012,z),(214,.035,1.7))
for x in [-107,107]:box('FormerDockOutline','Cobbles',(x,.012,144.5),(1.7,.035,37))
for z in [168,169.44]:beam('HistoricRailway','Rust',(-125,.045,z),(126,.045,z),.035,8)
for x in range(-120,121,2):box('RailSleepers','Wood',(x,.018,168.7),(.19,.045,2.3))
for x in [-105,-70,-35,0,35,70,105]:
 box('PlantingBeds','Stone',(x,.18,157),(11,.36,3.2));box('PlantingBeds','Green',(x,.39,157),(10.6,.12,2.8))
 for z in [130,-119]:
  box('PublicBenches','Wood',(x,.48,z),(2.8,.12,.48));box('PublicBenches','Wood',(x,.9,z-.22),(2.8,.72,.1))
  for dx in [-1,1]:box('PublicBenches','Steel',(x+dx,.25,z),(.08,.5,.46))
# The tower is an exterior landmark; concealed interiors are not built.
tx,tz=100,145
box('HydraulicEngineHouse','Brick',(tx,3.7,tz),(13,7.4,10))
box('HydraulicTower','Brick',(tx+5.6,13.0,tz+1.2),(4.8,26,4.8))
for y in [8,15,23,25.5]:box('TowerCornices','Stone',(tx+5.6,y,tz+1.2),(5.15,.24,5.15))
for y in [4.4,11,18.2,23.4]:
 for z in [tz-1.23,tz+3.63]:box('TowerWindows','Glass',(tx+5.6,y,z),(1.1,2.1,.055))
for x in [tx-4,tx,tx+4]:
 box('EngineHouseWindows','Glass',(x,3.7,tz+5.03),(1.8,3.5,.045))
 box('EngineHouseLintels','Stone',(x,5.55,tz+5.08),(2.2,.3,.25))
face('EngineHouseRoof','Slate',[(tx-6.8,7.4,tz-5.4),(tx+6.8,7.4,tz-5.4),(tx+6.8,10,tz),(tx-6.8,10,tz)])
face('EngineHouseRoof','Slate',[(tx-6.8,10,tz),(tx+6.8,10,tz),(tx+6.8,7.4,tz+5.4),(tx-6.8,7.4,tz+5.4)])
apex=(tx+5.6,29,tz+1.2)
corners=[(tx+3,26,tz-1.4),(tx+8.2,26,tz-1.4),(tx+8.2,26,tz+3.8),(tx+3,26,tz+3.8)]
for i in range(4):face('TowerRoof','Slate',[corners[i],corners[(i+1)%4],apex])
# Regent Road and its retained dock wall with actual openings.
box('RegentRoad','Road',(0,-.02,194),(900,.12,13))
for a,b in [(-165,-105),(-87,-20),(0,75),(95,165)]:
 box('HistoricDockWall','Brick',((a+b)/2,2.5,182),(b-a,5,1.1));box('DockWallCoping','Stone',((a+b)/2,5.08,182),(b-a,.25,1.3))
for x in range(-150,151,25):
 for z in [176,-151]:
  beam('PublicLighting','Steel',(x,0,z),(x,6,z),.055);box('PublicLighting','White',(x,6.05,z),(1.2,.12,.28))
box('DistantEastLand','Stone',(0,-.45,10100),(60000,.6,19800))
# Simple industrial context beyond the immediate detailed public realm.
rng=random.Random(5027)
for i in range(19):
 x=rng.uniform(-410,410);z=rng.uniform(225,450);w=rng.uniform(22,65);d=rng.uniform(20,48);h=rng.uniform(9,19)
 box('DistantWarehouses','Warehouse',(x,h/2,z),(w,h,d))
 for j in range(4):box('WarehousePanels','Slate',(x-w*.375+j*w*.25,h+.1,z),(w*.24,.2,d))
for i in range(12):
 x=175+(i%6)*19;z=15+(i//6)*25
 beam('StorageTanks','Tank',(x,0,z),(x,15+i%3*3,z),8,18)
for x in [-260,220]:
 box('DistantDockLand','Stone',(x,-.3,10),(155,.5,220))
 for row in range(3):
  for col in range(5):box('DockContainers','Warehouse',(x-30+col*13,1.4,40+row*3),(12,2.6,2.5))
objects=[]
for (name,material),(verts,faces) in data.items():
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();uv=me.uv_layers.new()
 for p in me.polygons:
  n=p.normal;axis=max(range(3),key=lambda a:abs(n[a]));other=[a for a in range(3) if a!=axis]
  for li in p.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(v[other[0]]*.22,v[other[1]]*.22)
 me.materials.append(M[material]);obj=bpy.data.objects.new(name+'_'+material,me);bpy.context.collection.objects.link(obj);objects.append(obj)
# Remove unused source atlases and store project-relative texture references.
for unused in list(bpy.data.materials):
 if unused.users==0:bpy.data.materials.remove(unused)
for image in list(bpy.data.images):
 if image.users==0:bpy.data.images.remove(image)
 elif image.filepath and image.source=='FILE':
  image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(Path(__file__).resolve().parent))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/stadium_docks.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'stadium_docks.glb'),export_format='GLB',export_yup=True,export_animations=False)
(OUT/'dockside_manifest.json').write_text(json.dumps({'author':'Original Beechlawn geometry','inferred_dimensions':True,'orientation':'North +X, West -Z; verified against imported seating centres','water_rectangles':[[-30000,-30000,30000,-158],[-140,-145,140,-126],[-360,-128,-136,75],[136,-128,360,75]],'water_height':-1.15,'tower':[tx+5.6,14,tz+1.2],'mesh_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),'source_reference':'references/stadium_supporters_2026_10_25'},indent=2)+'\n')
print('STADIUM_DOCKS_EXPORTED',len(objects),'batches',flush=True)
