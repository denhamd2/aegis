"""Isolated portrait-lid study for BR-022 five-round art review."""
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from player_head_groom import build_groom
from author_four_head_finish import render
import shane_player_finish

for identity, source in [('robbie_roden', 'robbie_roden_head.blend'),
                         ('david_murray', 'david_murray_head.blend')]:
    bpy.ops.wm.open_mainfile(filepath=str(HERE/source))
    head = bpy.data.objects['Skin_Head']
    head.data.shape_keys.key_blocks['Blink'].value = .28
    output = ROOT/'games/beechlawn_rovers/build/five_rounds/round_5'/identity
    shane_player_finish.TEXTURES = output/'temporary_textures'
    shane_player_finish.TEXTURES.mkdir(parents=True, exist_ok=True)
    build_groom(head, bpy.data.objects['YBot_Armature'], identity)
    render(head, output, views=('front', 'threequarter'))
    print('ROUND5_LID_PREVIEW', identity, flush=True)
