"""Original low-cost site footprint, traced from archived reference geometry.

Run with Blender -b --python. Coordinates use the authored 105 m field as
the scale anchor; they are not surveyed measurements. No map imagery exports.
"""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
GAME = ROOT / 'games/beechlawn_rovers'
TRACE = GAME / 'references/research/kilmore_site/site_trace.json'
OUT = GAME / 'assets/environment/kilmore'
EVIDENCE = GAME / 'docs/art_briefs/kilmore_footprint_evidence'
EVIDENCE.mkdir(parents=True, exist_ok=True)
data = json.loads(TRACE.read_text())
outline = data['outline_world_xz_m']

def area(points):
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:]+points[:1])))*.5

def clip(points, axis, limit, less):
    result=[]
    if not points:return result
    for a,b in zip(points[-1:]+points[:-1],points):
        ai = a[axis] <= limit if less else a[axis] >= limit
        bi = b[axis] <= limit if less else b[axis] >= limit
        if ai != bi:
            t=(limit-a[axis])/(b[axis]-a[axis])
            result.append([a[i]+t*(b[i]-a[i]) for i in range(2)])
        if bi:result.append(list(b))
    return result

# Four disjoint regions leave the entire gameplay footprint open, with no
# coplanar grass overlay that could conceal the authored pitch relief.
north=clip(outline,1,-34,True)
south=clip(outline,1,34,False)
middle=clip(clip(outline,1,-34,False),1,34,True)
west=clip(middle,0,-52.5,True)
east=clip(middle,0,52.5,False)
pieces=[north,south,west,east]
assert abs(sum(area(p) for p in pieces)-(area(outline)-105*68))<.05

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1

def material(name,colour):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.use_backface_culling=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*colour,1)
    p.inputs['Roughness'].default_value=.96
    return m

grass=material('MAT_Kilmore_Grass_Layout',(.22,.31,.13))
asphalt=material('MAT_Kilmore_Asphalt_Layout',(.12,.13,.14))
concrete=material('MAT_Kilmore_Footpath_Layout',(.43,.43,.4))

def mesh(name,polygons,height,mat):
    verts=[];faces=[]
    for polygon in polygons:
        if len(polygon)<3:continue
        offset=len(verts);verts.extend((p[0],-p[1],height) for p in polygon)
        faces.append(tuple(range(offset,len(verts))))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bm.normal_update()
    for f in bm.faces:
        if f.normal.z<0:f.normal_flip()
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    uv=me.uv_layers.new(name='UVMap')
    for loop in me.loops:
        p=me.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(p.x/8,-p.y/8)
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(mat)
    assert all(f.normal.z>.99 for f in me.polygons)
    return o

apron=mesh('SM_Kilmore_ParkApron',pieces,0,grass)
road_path=[[-69.5,-75.25],[-110,-74],[-161,-69.5],[-220,-62],[-235,-59]]
def packed(points):return ', '.join(str(v) for p in points for v in p)
(OUT/'kilmore_site_layout.tres').write_text(
    '[gd_resource type="Resource" script_class="KilmoreSiteLayout" load_steps=2 format=3]\n\n'
    '[ext_resource type="Script" path="res://scripts/kilmore_site_layout.gd" id="1"]\n\n'
    '[resource]\nscript = ExtResource("1")\n'
    'outline = PackedVector2Array('+packed(outline)+')\n'
    'west_road = PackedVector2Array('+packed(road_path)+')\n'
    'reference_note = "Manual satellite outline aligned to the authored 105 m field; not surveyed. Regenerate from build_kilmore_site_footprint.py."\n')

def ribbon(path,offset,width,max_x,height,mat,name):
    # Join the low-curvature segments with shared mitered edges.
    sides=[]
    for i,p in enumerate(path):
        tangent=Vector(path[min(i+1,len(path)-1)])-Vector(path[max(0,i-1)])
        tangent.normalize();normal=Vector((tangent.y,-tangent.x))
        centre=Vector(p)+normal*offset
        sides.append((centre+normal*width*.5,centre-normal*width*.5))
    polygons=[]
    for a,b in zip(sides,sides[1:]):
        polygons.append(clip([list(a[0]),list(b[0]),list(b[1]),list(a[1])],0,max_x,True))
    return mesh(name,polygons,height,mat)

roads=[ribbon(road_path,0,7,-74.5,.02,asphalt,'SM_Kilmore_West_Asphalt'),
       ribbon(road_path,5,2.5,-69.5,.04,concrete,'SM_Kilmore_West_FootpathInner'),
       ribbon(road_path,-5.1,1.7,-69.5,.03,concrete,'SM_Kilmore_West_FootpathOuter'),
       ribbon(road_path,3.5,.24,-69.5,.13,concrete,'SM_Kilmore_West_Curb')]

def export(objects,filename):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',
        use_selection=True,export_animations=False,export_apply=True,export_yup=True)

export([apron],'kilmore_site_apron.glb')
export(roads,'kilmore_west_road.glb')

# Flat, separate playing surface only for this layout study.
mesh('Review_CentralRoad',[[[-74.5,-78.75],[74.5,-78.75],[74.5,-71.75],[-74.5,-71.75]]],.02,asphalt)
mesh('Review_CentralPath',[[[-69.5,-71.5],[69.5,-71.5],[69.5,-69],[-69.5,-69]]],.04,concrete)
pitchmat=material('MAT_Review_PlayingSurface',(.17,.27,.12))
mesh('Review_PlayingSurface',[[[-52.5,-34],[52.5,-34],[52.5,34],[-52.5,34]]],.005,pitchmat)
paint=material('MAT_Review_FadedPaint',(.67,.66,.57))
def line(name,points,width=.10):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=width*.5;curve.bevel_resolution=0
    poly=curve.splines.new('POLY');poly.points.add(len(points)-1)
    for v,p in zip(poly.points,points):v.co=(p[0],-p[1],.025,1)
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj);curve.materials.append(paint)
line('Touchlines',[[-52.5,-34],[52.5,-34],[52.5,34],[-52.5,34],[-52.5,-34]])
line('Halfway',[[0,-34],[0,34]])
line('CentreCircle',[[math.cos(t*math.tau/64)*9.15,math.sin(t*math.tau/64)*9.15] for t in range(65)])
def label(body,x,y,size):
    c=bpy.data.curves.new('Label','FONT');c.body=body;c.size=size;c.align_x='CENTER';c.materials.append(paint)
    o=bpy.data.objects.new(body,c);bpy.context.collection.objects.link(o);o.location=(x,y,.06)
label('KILMORE DRIVE / WESTERN PARK EXTENSION',-115,84,2.6)
label('105 x 68 m PLAYABLE FIELD',0,-5,2.7)
label('REFERENCE-LED LAYOUT STUDY / NOT A SURVEY',-85,-66,2.6)
world=bpy.data.worlds.new('ReviewWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7;scene.world=world
sun=bpy.data.lights.new('Sun','SUN');sun.energy=1.8;obj=bpy.data.objects.new('Sun',sun);bpy.context.collection.objects.link(obj);obj.rotation_euler=(.4,-.3,-.3)
cam=bpy.data.cameras.new('CAM_SiteFootprint');camera=bpy.data.objects.new(cam.name,cam);bpy.context.collection.objects.link(camera)
camera.location=(-76,15,250);camera.rotation_euler=(Vector((-76,15,0))-camera.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=350;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=False
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.filepath=str(EVIDENCE/'blender_footprint.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/kilmore_site_footprint.blend'))
(EVIDENCE/'geometry_audit.json').write_text(json.dumps({'outline_area_m2':area(outline),'playing_area_m2':105*68,'apron_area_m2':sum(area(p) for p in pieces),'apron_triangles':len(apron.data.polygons),'road_triangles':sum(len(o.data.polygons) for o in roads),'road_path_xz_m':road_path,'surveyed':False},indent=2)+'\n')
bpy.ops.render.render(write_still=True)
print('KILMORE_FOOTPRINT_EXPORT_PASS: upward faces, open gameplay footprint, area preserved')
