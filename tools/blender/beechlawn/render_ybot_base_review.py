"""Render the supplied Mixamo body as an anatomy/weighting comparison baseline."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
OUT = ROOT / "games/beechlawn_rovers/docs/art_briefs/ybot_base_comparison.png"
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
armature = bpy.data.objects["YBot_Armature"]
armature.animation_data.action = None
for bone in armature.pose.bones:
    bone.location = (0.0, 0.0, 0.0)
    bone.rotation_mode = "QUATERNION"
    bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
scene.frame_set(1)
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 600
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.eevee.taa_render_samples = 8
scene.world = bpy.data.worlds.new("YBotComparisonWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.32, .36, .42, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55

def area(name, location, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0, 0, .92)) - light.location).to_track_quat("-Z", "Y").to_euler()

area("Key", (2.2, 3.3, 3.6), 450, 3.0, (1.0, .88, .76))
area("Fill", (-2.8, 2.2, 2.2), 260, 3.5, (.73, .83, 1.0))
area("Rim", (.5, -2.5, 3.1), 380, 2.6, (1.0, 1.0, 1.0))
bpy.ops.object.camera_add(location=(0, 4.7, 1.65))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, .92)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 68
scene.camera = camera
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT)
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
