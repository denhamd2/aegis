"""Render matching source-rig pose reviews for the BR-019 motion add-ons.

Run: blender -b -t 2 --python tools/blender/beechlawn/render_br019_motion.py
Output is diagnostic character-motion evidence, not roster likeness approval.
"""
from pathlib import Path
import math

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUTPUT = ROOT / 'games/beechlawn_rovers/build/br019_blender_motion'
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(HERE / 'footballer_shared.blend'))
scene = bpy.context.scene
rig = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 8
scene.cycles.use_denoising = False
scene.render.resolution_x = 480
scene.render.resolution_y = 480
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.world.color = (.6, .7, .8)
camera_data = bpy.data.cameras.new('BR019MotionCamera')
camera = bpy.data.objects.new('BR019MotionCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera.location = (3, -5, 2.1)
camera.rotation_euler = (Vector((0, 0, .95)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 2.3
sun_data = bpy.data.lights.new('BR019MotionSun', 'SUN')
sun_data.energy = 2
sun_data.angle = math.radians(8)
sun = bpy.data.objects.new('BR019MotionSun', sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (.6, -.4, -.7)


def load_action(source, name):
    with bpy.data.libraries.load(str(HERE / source), link=False) as (available, destination):
        assert name in available.actions, (source, name)
        destination.actions = [name]
    return destination.actions[0]


actions = [
    ('shot_baseline', bpy.data.actions['AN_Beechlawn_ShotRight'], 19),
    ('shot_power', load_action('football_br019_strikes.blend', 'AN_Beechlawn_ShotPowerRight'), 19),
    ('shot_finesse', load_action('football_br019_strikes.blend', 'AN_Beechlawn_ShotFinesseRight'), 19),
    ('shot_low', load_action('football_br019_strikes.blend', 'AN_Beechlawn_ShotLowRight'), 19),
    ('header_baseline', load_action('football_aerial_actions.blend', 'AN_Beechlawn_Header'), 19),
    ('header_duel', load_action('football_br019_header_duel.blend', 'AN_Beechlawn_HeaderDuel'), 19),
    ('keeper_claim', load_action('football_br019_keeper_claim.blend', 'AN_Beechlawn_KeeperHighClaim'), 23),
]
actions.extend([
    ('shot_baseline_follow', actions[0][1], 34),
    ('shot_power_follow', actions[1][1], 34),
    ('shot_finesse_follow', actions[2][1], 34),
    ('shot_low_follow', actions[3][1], 34),
    ('keeper_claim_secure', actions[6][1], 45),
])
for label, action, frame in actions:
    rig.animation_data.action = action
    scene.frame_set(frame)
    scene.render.filepath = str(OUTPUT / (label + '.png'))
    bpy.ops.render.render(write_still=True)
    print('BR019_BLENDER_RENDER', label, frame, flush=True)
