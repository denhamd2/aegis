"""Isolated Robbie groom study for BR-022 five-round art review."""
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import player_head_groom as groom
from author_four_head_finish import render
import shane_player_finish

source = HERE / 'robbie_roden_head.blend'
output = ROOT / 'games/beechlawn_rovers/build/five_rounds/round_4/robbie_roden'
shane_player_finish.TEXTURES = output/'temporary_textures'
shane_player_finish.TEXTURES.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
head = bpy.data.objects['Skin_Head']

original_regions = groom.hair_regions

def raised_hairline(points, identity):
    result = original_regions(points, identity)
    if identity == 'robbie_roden':
        p = np.atleast_2d(np.asarray(points, dtype=np.float64)).copy()
        angle = np.abs(np.arctan2(p[:, 0], p[:, 2] + 1.0))
        front = np.clip((1.48-angle)/.72, 0, 1)
        p[:, 1] -= 1.35*front
        result[:, 0] = original_regions(p, identity)[:, 0]
    return result

groom.hair_regions = raised_hairline
roots, cards = groom.build_groom(head, bpy.data.objects['YBot_Armature'], 'robbie_roden')

# The photo has a flatter, swept crop; reduce the stand-up strand geometry and
# create a subtle common direction while keeping each fibre root on the skull.
for strand in range(4100):
    offset = strand * 10
    root = (cards.data.vertices[offset].co + cards.data.vertices[offset+1].co)*.5
    for row in range(1, 5):
        u = row/4.0
        for side in range(2):
            vertex = cards.data.vertices[offset+row*2+side]
            vertex.co = root + (vertex.co-root)*.76 + Vector((.22*u, 0, -.035*u))
cards.data.update()

output.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output/'robbie_groom.blend'), compress=True)
render(head, output, views=('front', 'threequarter', 'profile'))
print('ROUND4_GROOM_PREVIEW', len(cards.data.vertices), len(cards.data.polygons), flush=True)
