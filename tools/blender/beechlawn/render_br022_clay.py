"""Fast, matched front/profile clay views of the six saved BR-022 heads."""
import argparse
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from refine_br022_faces import SOURCES

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--pass',type=int,required=True,dest='stage')
parser.add_argument('--players',nargs='+',choices=tuple(SOURCES),default=list(SOURCES))
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for identity in args.players:
    bpy.ops.wm.open_mainfile(filepath=str(HERE/SOURCES[identity]))
    scene=bpy.context.scene
    for obj in scene.objects:
        if obj.type=='MESH' and obj.name not in ('Skin_Head','Eye_l','Eye_r'):
            obj.hide_render=True
    scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='STUDIO'
    scene.display.shading.color_type='SINGLE'
    scene.display.shading.single_color=(.55,.56,.57)
    scene.display.shading.show_cavity=True
    scene.render.resolution_x=scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    target=Vector((0,0,1.65))
    camera_data=bpy.data.cameras.new('BR022_Clay')
    camera_data.type='ORTHO';camera_data.ortho_scale=.35
    camera=bpy.data.objects.new('BR022_Clay',camera_data)
    scene.collection.objects.link(camera);scene.camera=camera
    out=ROOT/'games/beechlawn_rovers/docs/art_briefs/br022_realism_2026_10_28'/f'pass_{args.stage}'/identity
    out.mkdir(parents=True,exist_ok=True)
    for name,angle in (('front',-math.pi/2),('profile',0)):
        camera.location=target+Vector((math.cos(angle)*.75,math.sin(angle)*.75,0))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/(name+'_clay.png'))
        bpy.ops.render.render(write_still=True)
    print('BR022_CLAY',args.stage,identity,flush=True)
