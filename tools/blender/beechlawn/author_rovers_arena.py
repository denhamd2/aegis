"""Original modular three-tier arena. Blender 4.3, metres; GLB + editable source."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/environment/rovers_arena'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC'
collection=bpy.data.collections.new('COL_RoversArena');bpy.context.scene.collection.children.link(collection)
def mat(name,col,rough=.65,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 return m
concrete=mat('Concrete',(.31,.34,.36),.91);blue=mat('BluePlastic',(.035,.16,.34),.39);metal=mat('GalvanisedRail',(.34,.39,.43),.38,.72);roof=mat('RoofCladding',(.58,.63,.68),.52,.45);dark=mat('DarkAccess',(.035,.045,.06),.9);white=mat('WhiteTrim',(.83,.86,.84),.65);black=mat('Boards',(.018,.025,.037),.65)
def link(obj):
 for c in list(obj.users_collection):c.objects.unlink(obj)
 collection.objects.link(obj)
 return obj
def mesh(name,verts,faces,material):
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
 o=bpy.data.objects.new(name,m);collection.objects.link(o);o.data.materials.append(material);return o
def box(name,size,at,material):
 bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=link(bpy.context.object);o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);return o
def beam(name,a,b,r=.04,material=metal):
 d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2)
 o=link(bpy.context.object);o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(material);return o
def ring(x,z,c=12):return [(x-c,z),(x,z-c),(x,-z+c),(x-c,-z),(-x+c,-z),(-x,-z+c),(-x,z-c),(-x+c,z)]
def ring_surface(name,a,b,h1,h2,material):
 return mesh(name,[(x,z,h1) for x,z in a]+[(x,z,h2) for x,z in b],[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],material)
seats=[];row_number=0;last=None
for tier,rows in enumerate([18,20,20]):
 base= tier*2.4
 for r in range(rows):
  offset=row_number*.76+tier*3.6;x=63+offset;z=44+offset;h=1.8+row_number*.43+base
  a=ring(x,z);b=ring(x+.76,z+.76)
  ring_surface(f'Tier{tier+1}_Row{r+1}_Tread',a,b,h,h,concrete)
  ring_surface(f'Tier{tier+1}_Row{r+1}_Riser',b,b,h,h+.43,concrete)
  for side in range(8):
   v1=Vector(a[side]);v2=Vector(a[(side+1)%8]);d=v2-v1;length=d.length
   n=max(1,int(length/.60));mid=(v1+v2)/2;fwd=-mid.normalized();yaw=math.atan2(fwd.x,-fwd.y)
   for i in range(n):
    # Regular radial stair aisles and vomitory breaks, not uninterrupted seating.
    if i%22 in [0,1,2]:continue
    pos=v1.lerp(v2,(i+.5)/n)+ (Vector(b[side])-v1)*.48
    seats.append([round(pos.x,4),round(h+.02,4),round(pos.y,4),round(yaw,5),tier*8+side])
  row_number+=1;last=(x+.76,z+.76,h+.43)
 # Wide promenade and metal guardrail between tiers.
 a=ring(last[0],last[1]);b=ring(last[0]+3.6,last[1]+3.6)
 ring_surface(f'Tier{tier+1}_Promenade',a,b,last[2],last[2],concrete)
 for i in range(8):
  aa=a[i];bb=a[(i+1)%8]
  for height in [.45,1.05]:beam('PromenadeRail',(aa[0],aa[1],last[2]+height),(bb[0],bb[1],last[2]+height),.025)
# Continuous outer concourse walls and a cantilever canopy, open sky over pitch.
x,z,h=last
outer=ring(x+3.6,z+3.6);inner=ring(72,53)
ring_surface('OuterFacade',outer,outer,.1,h+2.8,concrete)
ring_surface('CantileverRoof',inner,outer,h+5,h+7,roof)
for i in range(8):
 a=Vector(outer[i]);b=Vector(outer[(i+1)%8]);count=max(2,int((b-a).length/11))
 for j in range(count):
  pt=a.lerp(b,(j+.5)/count);inside=pt.normalized()*min(75,pt.length*.72)
  beam('RoofColumn',(*pt,0),(*pt,h+6.8),.16)
  beam('CanopyTruss',(*pt,h+6.8),(*inside,h+4.5),.10)
# Perimeter boards with alternating original blue/black treatment, and field apron.
box('PitchApron',(122,85,.12),(0,0,-.10),mat('ApronTurf',(.14,.23,.095),.95))
for sign in [-1,1]:
 for i in range(18):box('PitchsideBoard',(6.2,.16,.85),(-56+i*6.6,sign*39,.48),black if i%2 else blue)
 for i in range(11):box('EndBoard',(.16,6.2,.85),(sign*59,-34+i*6.6,.48),black if i%2 else blue)
 # Dugouts remain off the playing surface.
 box('DugoutBack',(10,.15,2.1),(sign*9,-41,1.05),blue)
 box('DugoutRoof',(10,2.6,.12),(sign*9,-39.8,2.15),roof)
 for xx in [sign*9-5,sign*9+5]:box('DugoutSide',(.09,2.6,2.1),(xx,-39.8,1.05),metal)
 # Tunnel / access portal, open dark recess between two lower-bank blocks.
 box('AccessPortal',(5,.12,3.4),(sign*22,44.2,1.7),dark)
# Steel goal surrounds do not include static duplicate goals or pitch markings.
# Save a proper 3D chair as a separate reusable near LOD; far seats use cards.
chair=[]
for name,size,at in [('SeatPan',(.43,.4,.065),(0,0,.42)),('SeatBack',(.43,.06,.43),(0,-.18,.66)),('SeatSupport',(.055,.055,.42),(0,0,.21))]:
 o=box(name,size,at,blue if name!='SeatSupport' else metal);chair.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in chair:o.select_set(True)
bpy.context.view_layer.objects.active=chair[0];bpy.ops.object.join();chair_obj=bpy.context.object;chair_obj.name='ArenaSeat'
# Merge immutable shell pieces by material: a handful of draw calls, not one per row.
for material in [concrete,blue,metal,roof,dark,white,black]+[bpy.data.materials['ApronTurf']]:
 group=[o for o in collection.objects if o!=chair_obj and o.type=='MESH' and len(o.data.materials)==1 and o.data.materials[0]==material]
 if len(group)>1:
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();bpy.context.object.name='Arena_'+material.name
bpy.ops.object.select_all(action='DESELECT');chair_obj.select_set(True)
bpy.context.view_layer.objects.active=chair_obj
# chair vertex positions are in the same meter-space as seats; preserve origin at floor.
bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.export_scene.gltf(filepath=str(OUT/'arena_seat.glb'),export_format='GLB',use_selection=True,export_yup=True)
chair_obj.hide_render=True;chair_obj.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
for o in collection.objects:
 if o!=chair_obj:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'stadium_shell.glb'),export_format='GLB',use_selection=True,export_yup=True)
(OUT/'seating.json').write_text(json.dumps(seats,separators=(',',':'))+'\n')
tris=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in collection.objects if o.type=='MESH' and o!=chair_obj)
(OUT/'asset_audit.json').write_text(json.dumps({'author':'Original Beechlawn project geometry','source':'tools/blender/beechlawn/author_rovers_arena.py','units':'metres','shell_triangles':tris,'seat_positions':len(seats),'seating_sections':24,'materials':len(bpy.data.materials),'imported_third_party_models':False},indent=2)+'\n')
print('ROVERS_ARENA_EXPORT',tris,'shell triangles;',len(seats),'seat positions')

# Linked preview geometry stays outside the exported runtime collection.
preview=bpy.data.collections.new('COL_Preview_Only');bpy.context.scene.collection.children.link(preview)
verts=[];faces=[]
for px,py,pz,yaw,section in seats:
 start=len(verts)
 for xx,hh in [(-.215,.32),(.215,.32),(.215,.84),(-.215,.84)]:
  verts.append((px+math.cos(yaw)*xx,-pz+math.sin(yaw)*xx,py+hh))
 faces.append((start,start+1,start+2,start+3))
m=bpy.data.meshes.new('PreviewSeatCards');m.from_pydata(verts,[],faces);m.update()
o=bpy.data.objects.new('PreviewSeatCards',m);preview.objects.link(o);m.materials.append(blue)
field=box('PreviewPlayingSurface',(105,68,.018),(0,0,-.005),mat('PreviewTurf',(.20,.33,.075),.95))
collection.objects.unlink(field);preview.objects.link(field)
# Scale/framing render, using original geometry only. Native captures validate final match.
bpy.ops.object.camera_add(location=(-42,-52,29));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,2))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=26
bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(0,0,40));sun=bpy.context.object;sun.rotation_euler=(.45,-.35,-.5);sun.data.energy=2.5;sun.data.angle=.025
scene=bpy.context.scene;scene.world.color=(.35,.42,.50);scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=False
scene.render.resolution_x=640;scene.render.resolution_y=360;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'games/beechlawn_rovers/docs/art_briefs/match_presentation_2026_10_24/blender_structure.png')
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('rovers_arena.blend')))
if '--render-preview' in sys.argv:bpy.ops.render.render(write_still=True)
