"""Disposable eight-pose garment review from the live source; never saves it."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[3]
sys.argv=[sys.argv[0],'--shared']
# Reuse the established neutral material/light/camera calibration.
setup=(Path(__file__).with_name('render_shane_denham_review.py')).read_text().split('views = [')[0]
exec(compile(setup,str(Path(__file__).with_name('render_shane_denham_review.py')),'exec'))
OUT=ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_kit_repair/poses'
OUT.mkdir(parents=True,exist_ok=True)
scene.render.resolution_x=400;scene.render.resolution_y=560;scene.eevee.taa_render_samples=4
camera_data=bpy.data.cameras.new('CAM_Kit_Pose_Review');camera=bpy.data.objects.new('CAM_Kit_Pose_Review',camera_data);scene.collection.objects.link(camera)
camera.location=(2,-4,1.35);camera.rotation_euler=(Vector((0,0,.92))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=2.1;scene.camera=camera
for name,frame in [('Idle',2),('Sprint',10),('PassRight',18),('GroundedSlideTackle',22),('GetUpFromProne',20),('KeeperSet',10),('KeeperSave',18),('Turn90Right',19)]:
 armature.animation_data.action=bpy.data.actions['AN_Beechlawn_'+name];scene.frame_set(frame)
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);print('KIT_POSE',name,flush=True)
