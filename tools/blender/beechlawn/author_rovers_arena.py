"""Hill Dickinson reference-led Rovers building. Blender 4.3, metres.
Original geometry and PBR maps; research photos are never exported as textures.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
import numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
from arena_layout import BANKS,TREAD,RADIUS,CX,CY,floor_height,span,point,normal,walkway,portal,make_layout
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/environment/rovers_arena'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC'
collection=bpy.data.collections.new('COL_RoversArena');bpy.context.scene.collection.children.link(collection)
def material(name,color,rough=.65,metal=0,alpha=1):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,alpha)
 b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,alpha)
 b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;b.inputs['Alpha'].default_value=alpha
 if alpha<1:m.surface_render_method='DITHERED'
 return m

def texture_set(mat,kind):
 """Original tileable height-derived maps. Metre-space UVs; linear ORM."""
 size=1024;rng=np.random.default_rng(174+len(kind));y,x=np.mgrid[0:size,0:size]/size;fine=rng.random((size,size))-.5
 if kind=='brick':
  row=np.floor(y*16);u=np.mod(x*10+(row%2)*.5,1);v=np.mod(y*16,1);joint=(u<.035)|(u>.965)|(v<.055)|(v>.945)
  randoms=rng.random((16,10));br=randoms[row.astype(int)%16,np.floor(np.mod(x*10+(row%2)*.5,10)).astype(int)]
  pigment=np.stack([.39+br*.20,.115+br*.09,.065+br*.05],axis=-1)+fine[...,None]*.06
  pigment[joint]=np.array([.31,.29,.25]);height=np.where(joint,.12,.8)+fine*.15;roughness=.86
 else:
  broad=(np.sin(x*math.tau*13+np.sin(y*math.tau*7))*.5+np.sin(y*math.tau*11)*.5)
  pigment=np.array([.48,.49,.47])[None,None,:]+(fine*.09+broad*.012)[...,None];height=fine*.12+broad*.025;roughness=.9
 gy,gx=np.gradient(height);n=np.stack([-gx*7,-gy*7,np.ones_like(x)],axis=-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
 for label,rgb in [('Color',pigment),('Normal',n*.5+.5),('ORM',np.stack([np.ones_like(x),np.ones_like(x)*roughness+fine*.025,np.zeros_like(x)],axis=-1))]:
  img=bpy.data.images.new('Arena_'+kind+'_'+label,width=size,height=size);pixels=np.ones((size,size,4),dtype=np.float32);pixels[:,:,:3]=np.clip(rgb,0,1)
  img.pixels.foreach_set(pixels.ravel());img.filepath_raw=str(OUT/(img.name+'.png'));img.file_format='PNG'
  if label!='Color':img.colorspace_settings.name='Non-Color'
  img.save();node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=img
  bs=mat.node_tree.nodes.get('Principled BSDF');links=mat.node_tree.links
  if label=='Color':links.new(node.outputs['Color'],bs.inputs['Base Color'])
  elif label=='Normal':
   nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.34;links.new(node.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
  else:
   sep=mat.node_tree.nodes.new('ShaderNodeSeparateColor');links.new(node.outputs['Color'],sep.inputs[0]);links.new(sep.outputs['Green'],bs.inputs['Roughness'])
M={'Concrete':material('Concrete',(.48,.49,.47),.90),'Brick':material('DockRedBrick',(.43,.17,.10),.87),
 'Blue':material('RoyalBlueSeat',(.015,.085,.34),.43),'Steel':material('RoofSteel',(.22,.25,.27),.42,1),
 'Roof':material('SilverBarrelCladding',(.57,.61,.64),.48,1),'Dark':material('RecessAndRoofSoffit',(.025,.033,.043),.82),
 'White':material('TrimAndRoversLettering',(.76,.80,.82),.6),'Glass':material('GlazedEndScreen',(.44,.60,.66),.19,0,.20),
 'Black':material('PitchBoards',(.012,.017,.022),.62),'Apron':material('RunoffTurf',(.035,.12,.025),.94),
 'Amber':material('StairNosing',(.61,.48,.08),.82),
 'FacadeGlass':material('ReflectiveFacadeGlass',(.065,.15,.19),.16)}
glass_bs=M['FacadeGlass'].node_tree.nodes.get('Principled BSDF')
glass_bs.inputs['Coat Weight'].default_value=.8;glass_bs.inputs['Coat Roughness'].default_value=.08
texture_set(M['Concrete'],'concrete');texture_set(M['Brick'],'brick')
class Batch:
 def __init__(self):self.parts={}
 def face(self,name,mat,verts):
  v,f,uv=self.parts.setdefault((name,mat),([],[],[]));start=len(v);v.extend(verts);f.append(tuple(range(start,start+len(verts))))
  n=(Vector(verts[1])-Vector(verts[0])).cross(Vector(verts[2])-Vector(verts[0]));axis=max(range(3),key=lambda k:abs(n[k]));axes=[k for k in range(3) if k!=axis]
  uv.extend([(p[axes[0]]/2.2,p[axes[1]]/1.12) for p in verts])
 def box(self,name,mat,at,size):
  x,y,z=at;a,b,c=[s*.5 for s in size]
  p=[(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
  for q in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.face(name,mat,[p[i] for i in q])
 def beam(self,name,mat,a,b,r=.04,sides=6):
  a=Vector(a);b=Vector(b);d=(b-a).normalized();u=d.cross(Vector((0,0,1)))
  if u.length<.01:u=d.cross(Vector((0,1,0)))
  u.normalize();v=d.cross(u)
  for i in range(sides):
   aa=math.tau*i/sides;bb=math.tau*(i+1)/sides;e=u*math.cos(aa)*r+v*math.sin(aa)*r;f=u*math.cos(bb)*r+v*math.sin(bb)*r
   self.face(name,mat,[a+e,a+f,b+f,b+e])
 def finish(self):
  result=[]
  for (name,mat),(verts,faces,uv) in self.parts.items():
   me=bpy.data.meshes.new(name+'_'+mat);me.from_pydata(verts,[],faces);me.update();layer=me.uv_layers.new(name='UV0')
   for polygon in me.polygons:
    for loop in polygon.loop_indices:layer.data[loop].uv=uv[me.loops[loop].vertex_index]
   if mat=='Roof' and name in ['Exterior','RoofCanopy']:
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(me);bm.free()
    for poly in me.polygons:poly.use_smooth=True
   ob=bpy.data.objects.new(name+'_'+mat,me);collection.objects.link(ob);me.materials.append(M[mat]);result.append(ob)
  return result
B=Batch()
# The complete building sits on a modest paved site, not a floating shell.
B.box('ExteriorPlaza','Concrete',(0,0,-.24),(420,360,.22))
for bank in BANKS:
 name='Interior_'+bank['name']
 for row in range(bank['rows']):
  a,b=span(bank,row);h=floor_height(row);rise=floor_height(row+1)-h
  if walkway(bank,row) and row!=32:continue
  depth=TREAD*4 if walkway(bank,row) else TREAD;steps=24 if bank['kind']=='arc' else max(1,int((b-a)/2.2))
  cuts=[a+(b-a)*i/steps for i in range(steps+1)]
  if bank['kind']=='line':
   for centre in [6.6+26.4*k for k in range(-3,4)]:
    cuts.extend(c for c in [centre-1.45,centre+1.45] if a<c<b)
   if bank['name']=='East':cuts.extend([-2.75,2.75])
  cuts=sorted(set(cuts))
  for u,v in zip(cuts,cuts[1:]):
   if portal(bank,row,(u+v)*.5):continue
   p=point(bank,row,u);q=point(bank,row,v);s=point(bank,row,v,depth);t=point(bank,row,u,depth)
   B.face(name,'Concrete',[(p[0],p[1],h),(t[0],t[1],h),(s[0],s[1],h),(q[0],q[1],h)])
   back_rise=floor_height(row+4)-h if walkway(bank,row) else rise
   B.face(name,'Concrete',[(s[0],s[1],h),(t[0],t[1],h),(t[0],t[1],h+back_rise),(s[0],s[1],h+back_rise)])
  aisles=[i*13.2 for i in range(-4,5) if abs(i*13.2)<bank.get('half',0)-1] if bank['kind']=='line' else [sum(bank['angles'])/2]
  if not walkway(bank,row):
   for u in aisles:
    if not a+.02<u<b-.02:continue
    half=.7 if bank['kind']=='line' else .7/(RADIUS+(row+.5)*TREAD)
    v1=point(bank,row,u-half,depth*.5);v2=point(bank,row,u+half,depth*.5);v3=point(bank,row,u+half,depth);v4=point(bank,row,u-half,depth)
    B.face(name,'Concrete',[(x,y,h+rise*.5) for x,y in [v1,v4,v3,v2]])
    n=normal(bank,u)
    B.face(name,'Amber',[(v1[0],v1[1],h+rise*.5+.003),(v1[0]+n[0]*.04,v1[1]+n[1]*.04,h+rise*.5+.003),(v2[0]+n[0]*.04,v2[1]+n[1]*.04,h+rise*.5+.003),(v2[0],v2[1],h+rise*.5+.003)])
 r=bank['rows']-1;a,b=span(bank,r);h=floor_height(r+1)
 for i in range(24):
  u=a+(b-a)*i/24;v=a+(b-a)*(i+1)/24;p=point(bank,r,u,TREAD);q=point(bank,r,v,TREAD)
  B.face(name,'Concrete',[(p[0],p[1],0),(q[0],q[1],0),(q[0],q[1],h+1),(p[0],p[1],h+1)])
 if bank['role']!='home':
  a,b=span(bank,32);segments=24 if bank['kind']=='arc' else 32
  for i in range(segments):
   u=a+(b-a)*i/segments;v=a+(b-a)*(i+1)/segments;p=point(bank,32,u,-.03);q=point(bank,32,v,-.03);h=floor_height(32)
   B.face(name,'Dark',[(p[0],p[1],h-1.5),(q[0],q[1],h-1.5),(q[0],q[1],h+.35),(p[0],p[1],h+.35)])
   B.beam(name,'White',(*p,h+.45),(*q,h+.45),.035);B.beam(name,'Steel',(*p,h+.65),(*p,h+1.12),.024);B.beam(name,'Steel',(*p,h+1.12),(*q,h+1.12),.024)
 if bank['kind']=='line' and bank['role']!='home':
  for u in [6.6+26.4*k for k in range(-3,4)]:
   if abs(u)>bank['half']-2:continue
   p=point(bank,12,u,TREAD*.5);n=bank['normal'];t=bank['tangent'];h=floor_height(12);q=(p[0]+n[0]*2.5,p[1]+n[1]*2.5)
   B.face(name,'Dark',[(q[0]-t[0]*1.42,q[1]-t[1]*1.42,h),(q[0]+t[0]*1.42,q[1]+t[1]*1.42,h),(q[0]+t[0]*1.42,q[1]+t[1]*1.42,h+2.9),(q[0]-t[0]*1.42,q[1]-t[1]*1.42,h+2.9)])
   B.beam(name,'White',(p[0]-t[0]*1.55,p[1]-t[1]*1.55,h+2.95),(p[0]+t[0]*1.55,p[1]+t[1]*1.55,h+2.95),.16)
def rounded_ring(x,y,r,steps=24):
 verts=[]
 corners=[(x-r,y-r,0),(-x+r,y-r,math.pi/2),(-x+r,-y+r,math.pi),(x-r,-y+r,math.pi*1.5)]
 for index,(cx,cy,start) in enumerate(corners):
  for i in range(steps+1):
   angle=start+math.pi*.5*i/steps;verts.append((cx+r*math.cos(angle),cy+r*math.sin(angle)))
  ex,ey=verts[-1];nx,ny,angle=corners[(index+1)%4];sx=nx+r*math.cos(angle);sy=ny+r*math.sin(angle)
  for j in range(1,32):verts.append((ex+(sx-ex)*j/32,ey+(sy-ey)*j/32))
 return verts
outer=rounded_ring(113,93,38)
for i,p in enumerate(outer):
 q=outer[(i+1)%len(outer)];middle=((p[0]+q[0])*.5,(p[1]+q[1])*.5);end=abs(middle[0])>101
 B.face('Exterior','Brick',[(p[0],p[1],0),(q[0],q[1],0),(q[0],q[1],12),(p[0],p[1],12)])
 centre=Vector(middle);outward=centre.normalized()
 for level in range(8):
  t0=level/8;t1=(level+1)/8
  d0=0 if end else 4*math.sin(math.pi*t0);d1=0 if end else 4*math.sin(math.pi*t1)
  a=(p[0]+outward.x*d0,p[1]+outward.y*d0,12+22*t0);b=(q[0]+outward.x*d0,q[1]+outward.y*d0,12+22*t0)
  c=(q[0]+outward.x*d1,q[1]+outward.y*d1,12+22*t1);d=(p[0]+outward.x*d1,p[1]+outward.y*d1,12+22*t1)
  B.face('Exterior','FacadeGlass' if end else 'Roof',[a,b,c,d])
  B.beam('Exterior','Steel',a,d,.028)
 for h in [4.2,8.2,12]:B.beam('Exterior','Dark',(*p,h),(*q,h),.10)
 B.beam('Exterior','Steel',(*p,12),(*p,34),.08)
 if i%2==0:
  B.beam('Exterior','Dark',(*p,1.5),(*q,8.2),.07);B.beam('Exterior','Dark',(*p,8.2),(*q,1.5),.07)
 if i%3==0:B.box('Exterior','Dark',(*middle,1.45),(1.3,.35,2.9) if abs(middle[1])>60 else (.35,1.3,2.9))
roof_rings=[]
for j in range(17):
 t=j/16;roof_rings.append((rounded_ring(62+t*51,41.5+t*51.5,12.5+t*25.5),34.8+8*math.sin(math.pi*t)-.8*t))
for j in range(16):
 ring0,h0=roof_rings[j];ring1,h1=roof_rings[j+1]
 for i,p in enumerate(ring0):
  n=(i+1)%len(ring0);q=ring0[n];r=ring1[n];s=ring1[i]
  B.face('RoofCanopy','Glass' if j<3 else 'Roof',[(p[0],p[1],h0),(s[0],s[1],h1),(r[0],r[1],h1),(q[0],q[1],h0)])
  if j==3:B.beam('RoofStructure','Steel',(*p,h0-.5),(*q,h0-.5),.15)
for index in range(0,len(outer),4):
 for j in range(16):
  p,h=roof_rings[j];q,k=roof_rings[j+1];a=(*p[index],h-.45);b=(*q[index],k-.45)
  B.beam('RoofStructure','Steel',a,b,.09);B.beam('RoofStructure','Steel',(a[0],a[1],a[2]-1.5),(b[0],b[1],b[2]-1.5),.075);B.beam('RoofStructure','Steel',a,(b[0],b[1],b[2]-1.5),.045)
 p=outer[index];B.beam('Exterior','Steel',(*p,12),(*p,34),.16)
# The deep long-span trusses are a defining part of the reference interior.
# Secondary radial members above them remain small; these main chords read
# correctly in pitch-level and broadcast establishing shots.
for sign in [-1,1]:
 for bay in range(20):
  u=-76+152*bay/20;v=-76+152*(bay+1)/20
  x=sign*78
  B.beam('RoofStructure','Steel',(x,u,37),(x,v,37),.20)
  B.beam('RoofStructure','Steel',(x,u,33),(x,v,33),.17)
  B.beam('RoofStructure','Steel',(x,u,33),(x,v,37),.11)
  B.beam('RoofStructure','Steel',(x,u,33),(x,u,37),.10)
  y=sign*56
  B.beam('RoofStructure','Steel',(u,y,40),(v,y,40),.18)
  B.beam('RoofStructure','Steel',(u,y,36),(v,y,36),.15)
  B.beam('RoofStructure','Steel',(u,y,36),(v,y,40),.10)
for sign in [-1,1]:
 x=sign*104
 for y in range(-62,63,5):
  B.face('EndWindows','Glass',[(x,y,25),(x,y+5,25),(x,y+5,35),(x,y,35)]);B.beam('EndWindows','Steel',(x,y,25),(x,y,35),.07)
 B.box('Screen','Dark',(sign*92,0,33),(1.0,18,7))
 for y in [-8,8]:B.beam('Screen','Steel',(sign*92,y,36.5),(sign*96,y,39),.13)
B.box('Apron','Apron',(0,0,-.10),(120,79,.12))
for sign in [-1,1]:
 for i in range(18):B.box('Boards','Black',(-56+i*6.6,sign*38.2,.48),(6.5,.16,.85))
 for i in range(11):B.box('Boards','Black',(sign*58.5,-33+i*6.6,.48),(.16,6.4,.85))
 B.box('Dugouts','Dark',(sign*9,-40.9,1.05),(10,.15,2.1));B.box('Dugouts','Roof',(sign*9,-39.7,2.2),(10,2.6,.12))
 for xx in [sign*9-5,sign*9+5]:B.box('Dugouts','Glass',(xx,-39.7,1.1),(.08,2.6,2.2))
 for i in range(10):
  B.box('Dugouts','Blue',(sign*9-4.3+i*.95,-40,.60),(.6,.65,.16));B.box('Dugouts','Blue',(sign*9-4.3+i*.95,-40.25,1.1),(.6,.14,.9))
B.box('Tunnel','Dark',(0,-43.5,1.5),(4.3,.15,3));B.box('Tunnel','Concrete',(-2.4,-41.4,1.6),(.35,5,3.2));B.box('Tunnel','Concrete',(2.4,-41.4,1.6),(.35,5,3.2));B.box('Tunnel','Concrete',(0,-41.4,3.35),(5.1,5,.3))
# Brick pilasters and recessed Leitch-style diagonal panels, plus properly
# framed entrance bays. They are repeated modules rather than flat wallpaper.
for sign in [-1,1]:
 for x in range(-65,66,5):
  B.box('Exterior','Brick',(x,sign*93.35,6),(.58,.7,12))
  B.box('Exterior','Dark',(x+2.5,sign*93.10,5),(4.15,.14,4.2))
  B.beam('Exterior','Brick',(x+.45,sign*93.24,3),(x+4.55,sign*93.24,7),.17)
  B.beam('Exterior','Brick',(x+.45,sign*93.24,7),(x+4.55,sign*93.24,3),.17)
 for x in [-56,-28,0,28,56]:
  B.box('Exterior','Dark',(x,sign*93.85,1.7),(3,.25,3.4))
  B.box('Exterior','Roof',(x,sign*94.2,3.6),(4.2,2,.18))
  for dx in [-1.5,0,1.5]:B.beam('Exterior','Steel',(x+dx,sign*94.05,0),(x+dx,sign*94.05,3.5),.05)
 B.box('Exterior','Dark',(0,sign*93.9,10.1),(38,.3,3.5))
shell=B.finish()
chair=Batch()
def extruded_profile(name,polygon,z0,z1):
 chair.face(name,'Blue',[(x,y,z0) for x,y in reversed(polygon)]);chair.face(name,'Blue',[(x,y,z1) for x,y in polygon])
 for i,p in enumerate(polygon):
  q=polygon[(i+1)%len(polygon)];chair.face(name,'Blue',[(p[0],p[1],z0),(q[0],q[1],z0),(q[0],q[1],z1),(p[0],p[1],z1)])
extruded_profile('Seat',[(-.22,-.19),(.22,-.19),(.22,.13),(.17,.23),(-.17,.23),(-.22,.13)],.40,.455)
chair.face('Seat','Blue',[(-.21,-.19,.45),(.21,-.19,.45),(.225,-.24,.78),(.18,-.25,.88),(-.18,-.25,.88),(-.225,-.24,.78)])
chair.box('Seat','Steel',(0,-.08,.20),(.055,.055,.4));seat_objects=chair.finish();bpy.ops.object.select_all(action='DESELECT')
for ob in seat_objects:ob.select_set(True)
bpy.context.view_layer.objects.active=seat_objects[0];bpy.ops.object.join();seat=bpy.context.object;seat.name='ArenaSeat';seat.data.materials[0].use_backface_culling=False
bpy.ops.export_scene.gltf(filepath=str(OUT/'arena_seat.glb'),export_format='GLB',use_selection=True,export_yup=True);seat.hide_render=True;seat.hide_viewport=True

def lettering(body,at,rot,size,name='RoversSign'):
 curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.align_x='CENTER';curve.size=size;curve.extrude=.003
 ob=bpy.data.objects.new(name,curve);collection.objects.link(ob);ob.location=at;ob.rotation_euler=rot;curve.materials.append(M['White'])
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');return bpy.context.object
for sign in [-1,1]:lettering('ROVERS ARENA',(sign*91.4,0,32.8),(math.pi/2,0,math.pi/2 if sign<0 else -math.pi/2),1.15)
for sign in [-1,1]:
 for x in [-43,-16,16,43]:lettering('BEECHLAWN ROVERS 27',(x,sign*38.31,.33),(math.pi/2,0,0 if sign<0 else math.pi),.28)
lettering('BEECHLAWN ROVERS',(0,-94.15,9),(math.pi/2,0,0),2.7);lettering('BEECHLAWN ROVERS',(0,94.15,9),(math.pi/2,0,math.pi),2.7)
shell=[o for o in collection.objects if o!=seat and o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
for ob in shell:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'stadium_shell.glb'),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True)
seats,layout=make_layout();(OUT/'seating.json').write_text(json.dumps(seats,separators=(',',':'))+'\n');(OUT/'seating_layout.json').write_text(json.dumps(layout,separators=(',',':'))+'\n')
# Check real exported geometry under sampled chair feet, independently of the
# placement generator. This catches missing treads/portal cuts and wrong normals.
from mathutils.bvhtree import BVHTree
vertices=[];polygons=[]
for ob in shell:
 if not ob.name.startswith('Interior_') or not ob.name.endswith('Concrete'):continue
 offset=len(vertices);vertices.extend(v.co.copy() for v in ob.data.vertices)
 polygons.extend([offset+i for i in p.vertices] for p in ob.data.polygons)
bvh=BVHTree.FromPolygons(vertices,polygons);errors=[];checked=0
for index in range(0,len(seats),17):
 x,h,z,_,_=seats[index];hit,n,_,_=bvh.ray_cast(Vector((x,-z,h+.12)),Vector((0,0,-1)),.3);checked+=1
 if hit is None or abs(hit.z-(h-.02))>.006 or n.z<.99:errors.append(index)
layout['support_audit']={'sampled':checked,'errors':len(errors),'indices':errors[:20]}
(OUT/'seating_layout.json').write_text(json.dumps(layout,separators=(',',':'))+'\n')
assert not errors, 'Actual terrace support failed: '+str(layout['support_audit'])
tris=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in shell)
(OUT/'asset_audit.json').write_text(json.dumps(dict(author='Original reference-led Beechlawn project geometry',reference='Hill Dickinson Stadium',source='tools/blender/beechlawn/author_rovers_arena.py',units='metres',shell_triangles=tris,seat_positions=len(seats),seating_sections=len(layout['sections']),materials=len(M),inferred_dimensions=True,imported_third_party_models=False),indent=2)+'\n')
print('ROVERS_ARENA_EXPORT',tris,'shell triangles;',len(seats),'seats;',len(layout['sections']),'spatial sections',flush=True)
preview=bpy.data.collections.new('COL_Preview_Only');bpy.context.scene.collection.children.link(preview);verts=[];faces=[]
for x,h,z,yaw,_ in seats:
 start=len(verts)
 for xx,hh in [(-.22,.35),(.22,.35),(.22,.86),(-.22,.86)]:verts.append((x+math.cos(yaw)*xx,-z+math.sin(yaw)*xx,h+hh))
 faces.append((start,start+1,start+2,start+3))
me=bpy.data.meshes.new('PreviewSeats');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('PreviewSeats',me);preview.objects.link(ob);me.materials.append(M['Blue'])
field=Batch();field.box('PreviewField','Apron',(0,0,-.005),(105,68,.018))
for ob in field.finish():collection.objects.unlink(ob);preview.objects.link(ob)
bpy.ops.object.camera_add(location=(-42,-52,29));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,2))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=16;bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(0,0,40));sun=bpy.context.object;sun.rotation_euler=(.65,-.35,-.5);sun.data.energy=2.0;sun.data.angle=.025
scene=bpy.context.scene;scene.world.use_nodes=True
wn=scene.world.node_tree.nodes;wl=scene.world.node_tree.links
environment=wn.new('ShaderNodeTexEnvironment');environment.image=bpy.data.images.load(str(ROOT/'games/beechlawn_rovers/assets/environment/sky/polyhaven/kloofendal_48d_partly_cloudy_puresky_4k.hdr'))
wl.new(environment.outputs['Color'],wn['Background'].inputs['Color']);wn['Background'].inputs['Strength'].default_value=.65
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.render.resolution_x=960;scene.render.resolution_y=540;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
scene.render.filepath=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--preview-output=')),str(ROOT/'games/beechlawn_rovers/docs/art_briefs/hill_dickinson_remodel_2026_10_25/blender_structure.png'))
for image in bpy.data.images:
 if image.filepath and not image.filepath.startswith('//'):
  image.filepath=bpy.path.relpath(image.filepath,start=str(Path(__file__).parent))
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('rovers_arena.blend')),relative_remap=False)
if '--render-preview' in sys.argv:bpy.ops.render.render(write_still=True)
