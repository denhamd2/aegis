"""Bounded matching source reviews, independent from runtime evidence."""
from pathlib import Path
import bpy,sys,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
kind=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'goal'
source={'goal':'stadium_goal.blend','tifo':'stadium_tifo.blend','docks':'stadium_docks.blend'}[kind]
bpy.ops.wm.open_mainfile(filepath=str(HERE/source))
scene=bpy.context.scene
if kind=='docks':
 with bpy.data.libraries.load(str(HERE/'rovers_arena.blend'),link=False) as (src,dst):
  dst.objects=[n for n in src.objects if not n.startswith(('Seat','Preview','ExteriorPlaza'))]
 for obj in dst.objects:
  if obj is not None and obj.type=='MESH' and not obj.users_collection:scene.collection.objects.link(obj)
for obj in list(scene.objects):
 if obj.type in ['CAMERA','LIGHT']:bpy.data.objects.remove(obj,do_unlink=True)
if kind=='goal':at=(6.5,-8,2.3);target=(0,-.8,1.3);lens=40
elif kind=='tifo':at=(0,-44,14);target=(0,0,14);lens=38
else:at=(-210,270,102);target=(0,0,10);lens=40
bpy.ops.object.camera_add(location=at);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(10,-20,40));sun=bpy.context.object;sun.rotation_euler=(math.radians(28),math.radians(-18),math.radians(-25));sun.data.energy=2.0;sun.data.angle=.03
scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.19,.21,.24,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.use_denoising=False
scene.render.resolution_x=600 if kind=='tifo' else 960;scene.render.resolution_y=800 if kind=='tifo' else 540;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
out=ROOT/'games/beechlawn_rovers/docs/art_briefs/stadium_supporters_2026_10_25/blender';out.mkdir(parents=True,exist_ok=True)
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(out/(kind+'.png'))
bpy.ops.render.render(write_still=True)
print('BLENDER_STADIUM_REVIEW',kind,flush=True)
