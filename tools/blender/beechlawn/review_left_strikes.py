"""Blender pose review of the new motion on the protected source body.

This is a motion/body view, not current individual-head likeness evidence.
Does not save or change the player master. Matching runtime review uses Shane
on the pitch; the source's older diagnostic head is not a reference approval.
"""
from pathlib import Path
import bpy,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OUT=ROOT/'games/beechlawn_rovers/docs/art_briefs/left_foot_ai_2026_10_25/blender';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(HERE/'footballer_shared.blend'))
scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE')
with bpy.data.libraries.load(str(HERE/'football_left_strikes.blend'),link=False) as (source,target):
 target.actions=[name for name in source.actions if name in ['AN_Beechlawn_PassLeft','AN_Beechlawn_ShotLeft','AN_Beechlawn_VolleyLeft','AN_Beechlawn_HalfVolleyLeft']]
scene.render.fps=60;scene.render.fps_base=1
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.use_denoising=False
scene.render.resolution_x=480;scene.render.resolution_y=640;scene.render.resolution_percentage=100
world=bpy.data.worlds.new('DaylightMotionReview');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.61,.71,.84,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
cd=bpy.data.cameras.new('PitchsideMotionCamera');camera=bpy.data.objects.new('PitchsideMotionCamera',cd);scene.collection.objects.link(camera);scene.camera=camera
camera.location=(2.6,-4,1.3);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=2.1
ld=bpy.data.lights.new('DaylightSun','SUN');ld.energy=2;ld.angle=math.radians(8)
light=bpy.data.objects.new('DaylightSun',ld);scene.collection.objects.link(light);light.rotation_euler=(.5,-.3,-.6)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015));ground=bpy.context.object
mat=bpy.data.materials.new('ReviewTurf');mat.diffuse_color=(.08,.14,.045,1);ground.data.materials.append(mat)
for action in target.actions:
 rig.animation_data.action=action
 scene.frame_set(25 if 'Pass' in action.name else 19)
 scene.render.filepath=str(OUT/(action.name+'.png'));bpy.ops.render.render(write_still=True)
print('LEFT_STRIKE_BLENDER_REVIEW_RENDERED',len(target.actions),flush=True)
