"""Render the saved current head sources without rebaking or rewriting them."""
import argparse
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from author_four_head_finish import SOURCES, render
from player_head_groom import build_groom

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--player', choices=tuple(SOURCES))
parser.add_argument('--views', nargs='+', default=['front', 'threequarter', 'profile'])
parser.add_argument('--output', type=Path)
parser.add_argument('--expression', choices=('neutral','blink','smile'), default='neutral')
parser.add_argument('--clay', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for identity in ((args.player,) if args.player else SOURCES):
    bpy.ops.wm.open_mainfile(filepath=str(HERE/SOURCES[identity]))
    head = bpy.data.objects['Skin_Head']
    if args.expression != 'neutral':
        head.data.shape_keys.key_blocks['Blink' if args.expression == 'blink' else 'Smile'].value = 1.0
    if not args.clay:
        build_groom(head, bpy.data.objects['YBot_Armature'], identity)
    out = (args.output if args.output else ROOT/'games/beechlawn_rovers/docs/art_briefs/four_head_finish'/('clay_final' if args.clay else 'blender'))/identity
    render(head, out, clay=args.clay, views=args.views)
    print('SAVED_HEAD_REVIEW', identity, args.views, flush=True)
