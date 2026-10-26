"""Matched shared-body deformation renders; source head is diagnostic, not likeness proof."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[3]
sys.argv=[sys.argv[0],'--shared','--scene=/tmp/free_kick_wall_review.blend']
setup=Path(__file__).with_name('render_shane_denham_review.py').read_text().split('views = [')[0]
exec(compile(setup,str(Path(__file__).with_name('render_shane_denham_review.py')),'exec'))
OUT=Path('/tmp/free-kick-wall-blender-review');OUT.mkdir(exist_ok=True)
scene.render.resolution_x=400;scene.render.resolution_y=560;scene.eevee.taa_render_samples=8
camera_data=bpy.data.cameras.new('CAM_Wall_Review');camera=bpy.data.objects.new('CAM_Wall_Review',camera_data);scene.collection.objects.link(camera)
camera.location=(2,-4,1.35);camera.rotation_euler=(Vector((0,0,.92))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=2.1;scene.camera=camera
for name,frame in [('WallBrace',1),('WallJump',5),('WallJump',23)]:
 armature.animation_data.action=bpy.data.actions['AN_Beechlawn_'+name];scene.frame_set(frame)
 scene.render.filepath=str(OUT/(name+str(frame)+'.png'));bpy.ops.render.render(write_still=True)
 print('WALL_POSE_REVIEW',name,frame,flush=True)
