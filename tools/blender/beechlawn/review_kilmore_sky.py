"""Small Cycles reference render for the shipped sky; no gameplay scene edits.

blender -b --python-exit-code 1 --python tools/blender/beechlawn/review_kilmore_sky.py
Godot match captures remain the engine acceptance evidence.
"""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
PROJECT=ROOT/'games/beechlawn_rovers'
EVIDENCE=PROJECT/'docs/art_briefs/sky_evidence'
EVIDENCE.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=False
scene.render.resolution_x=960;scene.render.resolution_y=540;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('Kilmore Partly Cloudy Review');scene.world=world;world.use_nodes=True
nodes=world.node_tree.nodes
texture=nodes.new('ShaderNodeTexEnvironment')
texture.image=bpy.data.images.load(str(PROJECT/'assets/environment/sky/polyhaven/kloofendal_48d_partly_cloudy_puresky_4k.hdr'))
world.node_tree.links.new(texture.outputs['Color'],nodes.get('Background').inputs['Color'])
nodes.get('Background').inputs['Strength'].default_value=.8
camera_data=bpy.data.cameras.new('Sky reference camera');camera=bpy.data.objects.new('Sky reference camera',camera_data)
scene.collection.objects.link(camera);scene.camera=camera
camera.location=(0,0,1.7);camera.rotation_euler=Vector((0,-1,.22)).to_track_quat('-Z','Y').to_euler();camera_data.lens=28
scene.render.filepath=str(EVIDENCE/'blender_sky_reference.png')
bpy.ops.render.render(write_still=True)
print('SKY_REFERENCE_RENDER',scene.render.filepath)
