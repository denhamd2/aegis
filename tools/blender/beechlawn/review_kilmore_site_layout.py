"""Build a metre-scale site review from Godot's actual placed-layout manifest.

Reads existing Blender modules, records their bounds, instances their mesh data,
and saves a separate site-review .blend. Does not change the reusable modules.
The playable terrain is drawn flat in this layout study; runtime keeps relief.
"""
from pathlib import Path
import json,math,bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
EVIDENCE=ROOT/'games/beechlawn_rovers/docs/art_briefs/kilmore_setback_evidence'
layout=json.loads((EVIDENCE/'runtime_layout.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/kilmore_park_modules.blend'))
modules={}
bounds_report={}
for filename,rootname in [('kilmore_house_a.glb','SM_Kilmore_HouseFacade_A'),('kilmore_house_b.glb','SM_Kilmore_HouseFacade_B'),('kilmore_tree_a.glb','SM_Kilmore_ParkTree_A'),('kilmore_tree_b.glb','SM_Kilmore_ParkTree_B')]+[('kilmore_hatchback_'+letter.lower()+'.glb','SM_Kilmore_ParkedHatchback_'+letter) for letter in 'ABCD']:
    source=bpy.data.objects[rootname]
    parts=[];points=[]
    for child in source.children_recursive:
        if child.type!='MESH':continue
        relative=source.matrix_world.inverted()@child.matrix_world
        prototype=child.copy();prototype.data=child.data
        parts.append((prototype,relative))
        points.extend(relative@Vector(p) for p in child.bound_box)
    modules[filename]=parts
    bounds_report[filename]={'min_m':[min(p[i] for p in points) for i in range(3)],'max_m':[max(p[i] for p in points) for i in range(3)]}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
collection=bpy.data.collections.new('COL_KilmoreSiteLayout');scene.collection.children.link(collection)
review=bpy.data.collections.new('COL_ReviewCameras');scene.collection.children.link(review)
def material(name,c):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    return m
park=material('Layout_ParkGrass',(.22,.32,.12));pitch=material('Layout_PlayingSurface',(.15,.26,.10));concrete=material('Layout_Concrete',(.48,.47,.43));asphalt=material('Layout_Asphalt',(.11,.12,.13));wall=material('Layout_Wall',(.5,.49,.43));paint=material('Layout_White',(.9,.9,.82));accent=material('Layout_Dimension',(.85,.38,.08))
def cube(name,at,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o);return o
def text(body,at,size=2.1,rotation=0):
    data=bpy.data.curves.new('Label','FONT');data.body=body;data.size=size;data.align_x='CENTER';o=bpy.data.objects.new(body,data);collection.objects.link(o);o.location=at;o.rotation_euler.z=rotation;data.materials.append(paint)
# Four flat apron rectangles, leaving the playable surface open.
hx,hz=52.5,34
north=hz+36+(layout['grass_buffer_m']-5.75);south=hz+36
for name,x,y,w,d in [('North',0,(hz+north)/2,147,north-hz),('South',0,-(hz+south)/2,147,south-hz),('West',-63,0,21,68),('East',63,0,21,68)]:
    cube('ParkApron_'+name,(x,y,-.11),(w,d,.22),park)
cube('PlayingSurface',(0,0,0),(105,68,.01),pitch)
for name,at,size in [('TouchlineNorth',(0,34,.02),(105,.11,.015)),('TouchlineSouth',(0,-34,.02),(105,.11,.015)),('WestGoalLine',(-52.5,0,.02),(.11,68,.015)),('EastGoalLine',(52.5,0,.02),(.11,68,.015)),('Halfway',(0,0,.02),(.11,68,.015))]:cube(name,at,size,paint)
for item in layout['objects']:
    name=item['name'];module=Path(item.get('module','')).name
    if module in modules:
        root=bpy.data.objects.new(name,None);collection.objects.link(root)
        x,y,z=item['position'];root.location=(x,-z,y);root.rotation_euler.z=item['rotation_y'];sx,sy,sz=item['scale'];root.scale=(sx,sz,sy)
        for prototype,relative in modules[module]:
            obj=prototype.copy();obj.data=prototype.data;obj.name=name+'_Mesh';collection.objects.link(obj);obj.parent=root;obj.matrix_basis=relative;obj.hide_render=False;obj.hide_viewport=False
    elif 'bounds_min' in item and name!='ParkTurf':
        p=item['bounds_min'];s=item['bounds_size'];at=(p[0]+s[0]/2,-p[2]-s[2]/2,p[1]+s[1]/2)
        mat=asphalt if name=='Road' else (park if 'Grass' in name or 'Hedge' in name else wall if 'Wall' in name else concrete)
        cube(name,at,(s[0],s[2],s[1]),mat)
    elif name.startswith('RoadsideLamp_') or name.startswith('UtilityPole_'):
        x,y,z=item['position'];cube(name,(x,-z,3.5),(.12,.12,7),concrete)
    elif name.startswith('Spectator_'):
        x,y,z=item['position'];cube(name,(x,-z,.9),(.4,.3,1.8),accent)
text('PITCH / 105 x 68 m',(0,-3,.05),3)
text('OPEN PARK GRASS',(0,52,.05),2.5)
text('KILMORE DRIVE / RESIDENTIAL EDGE',(0,76,.2),2)
x=44
cube('GrassBufferDimension',(x,(34+69)/2,.06),(.15,35,.04),accent)
for y in [34,69]:cube('DimensionTick',(x,y,.06),(2,.12,.04),accent)
text('35 m authored grass buffer',(49,51.5,.06),1.5,math.pi/2)
text('SCENE LAYOUT STUDY / NOT A SURVEY',(0,-63,.05),2)
world=bpy.data.worlds.new('Layout_Daylight');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.65,.7,.75,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65;scene.world=world
sun=bpy.data.lights.new('Sun','SUN');sun.energy=2;sun.angle=.25;o=bpy.data.objects.new('Sun',sun);review.objects.link(o);o.rotation_euler=(.5,-.4,-.3)
cam=bpy.data.cameras.new('CAM_SatelliteLayout');camera=bpy.data.objects.new(cam.name,cam);review.objects.link(camera);camera.location=(0,14.625,220);camera.rotation_euler=(Vector((0,14.625,0))-camera.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=240;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.filepath=str(EVIDENCE/'blender_site_layout.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/kilmore_site_layout_review.blend'))
(EVIDENCE/'blender_module_bounds.json').write_text(json.dumps(bounds_report,indent=2)+'\n')
bpy.ops.render.render(write_still=True)
print('KILMORE_SITE_LAYOUT_REVIEW ground metres, reusable module data instanced, source modules unchanged')
