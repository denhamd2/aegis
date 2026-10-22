"""Render neutral front/three-quarter/profile evidence of the exported Des head."""
import bpy, math, sys, argparse
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
PROJECT=ROOT/'games/beechlawn_rovers'
parser=argparse.ArgumentParser()
parser.add_argument('--baseline',action='store_true')
parser.add_argument('--clay',action='store_true')
parser.add_argument('--view',default='all',choices=('all','front','threequarter','profile'))
parser.add_argument('--samples',type=int,default=8)
parser.add_argument('--output',type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
WORK=ROOT/'tools/blender/beechlawn'/('footballer_head_master.blend' if args.baseline else 'des_feeney_head.blend')
OUT=PROJECT/'docs/art_briefs/des_feeney_player_likeness'/('before' if args.baseline else 'after')
if args.output:OUT=args.output.resolve()
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(WORK))
head=bpy.data.objects['Skin_Head']; rig=bpy.data.objects['YBot_Armature']
if not args.baseline and not args.clay:
    from player_head_groom import build_groom
    build_groom(head, rig, 'bordeaux_09')
if args.clay:
    clay=bpy.data.materials.new('Review_Neutral_Clay');clay.diffuse_color=(.36,.36,.36,1)
    clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.36,.36,.36,1)
    clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.65
    head.data.materials[0]=clay
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.eevee.taa_render_samples=args.samples
scene.view_settings.view_transform='AgX'
scene.world.color=(.35,.35,.35)
scene.render.fps=30
# remove any inherited camera/lights, leave the character asset intact
for o in list(scene.objects):
    if o.type in {'CAMERA','LIGHT'}: bpy.data.objects.remove(o,do_unlink=True)
world=scene.world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.32,.36,.40,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25

def area(name,loc,power,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector((0,0,1.63))-ob.location).to_track_quat('-Z','Y').to_euler()
area('Portrait_Key',(.25,-.42,1.84),5,.24,(1.0,.94,.88))
area('Portrait_Fill',(-.30,-.35,1.68),2,.26,(.88,.94,1.0))
area('Portrait_Rim',(.05,.25,1.83),2,.18,(1.0,.96,.91))
cam_data=bpy.data.cameras.new('Des_Review_Camera');cam=bpy.data.objects.new('Des_Review_Camera',cam_data);scene.collection.objects.link(cam);scene.camera=cam
cam_data.type='ORTHO';cam_data.ortho_scale=.32
written=[]
for suffix,azimuth in [('front',3*math.pi/2),('threequarter',3*math.pi/2+.52),('profile',0)]:
    if args.view!='all' and args.view!=suffix:continue
    target=Vector((0,0,1.634));radius=.78
    cam.location=target+Vector((math.cos(azimuth)*radius,math.sin(azimuth)*radius,.01))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'des_player_{"clay_" if args.clay else ""}{suffix}.png')
    bpy.ops.render.render(write_still=True)
    written.append(scene.render.filepath)
print('DES_PLAYER_RENDERS',*written)
