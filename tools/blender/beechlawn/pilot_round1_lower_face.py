"""Isolated lower-face study from the six saved Beechlawn hero sources.

Writes editable previews into ignored build storage. It intentionally does
not change the production sources; visual review rejected the result.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT/'games/beechlawn_rovers'
sys.path.insert(0, str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES, render
from player_head_groom import build_groom
import shane_player_finish

SOURCES = {**FOUR_SOURCES, 'robbie_roden': 'robbie_roden_head.blend',
           'david_murray': 'david_murray_head.blend'}
PREVIEW = PROJECT/'build/five_rounds'


def smooth(a, b, value):
    t = max(0.0, min(1.0, (value-a)/(b-a)))
    return t*t*(3.0-2.0*t)


def round_one(point, identity, metrics):
    """Lengthen the photographed lower third without moving the body seam."""
    x, y, z = point
    if y < 154.0:
        return point.copy()
    photo = metrics[identity]['reference']
    current = metrics[identity]['after']
    front = smooth(3.5, 8.0, z)
    chin_gap_cm = max(0.0, (current['chin_y']-photo['chin_y'])*6.694)
    amount = min(1.0, chin_gap_cm*.82)
    phase = (y-154.0)/4.8
    chin_window = math.sin(math.pi*phase) if 0.0 < phase < 1.0 else 0.0
    chin_window *= math.exp(-(x/5.7)**6)*front
    y -= amount*chin_window
    # The same portrait check points to a broad jaw on Robbie and both Des
    # heads. Keep the eye sockets, ears and neck interface outside this field.
    ratio = photo['jaw_width']/current['jaw_width']-1.0
    narrow = max(-.07, min(.035, ratio*.55))
    jaw = math.exp(-((point.y-158.5)/3.4)**4)
    jaw *= smooth(3.5, 6.5, abs(x))*smooth(154.0, 156.5, point.y)*front
    x *= 1.0+narrow*jaw
    assert y >= 154.0-1e-5
    return Vector((x, y, z))


def transform_head(head, identity, metrics, round_number):
    mesh = head.data
    assert mesh.shape_keys and mesh.shape_keys.key_blocks.get('Smile')
    before = [v.co.copy() for v in mesh.vertices]
    groups = [tuple((g.group, round(g.weight, 6)) for g in v.groups) for v in mesh.vertices]
    for key in mesh.shape_keys.key_blocks:
        for item in key.data:
            item.co = round_one(item.co, identity, metrics)
        key.value = 0.0
    for vertex, basis in zip(mesh.vertices, mesh.shape_keys.key_blocks['Basis'].data):
        vertex.co = basis.co
    mesh.update()
    for vertex, old, weights in zip(mesh.vertices, before, groups):
        assert tuple((g.group, round(g.weight, 6)) for g in vertex.groups) == weights
        if old.y < 154.0:
            assert (vertex.co-old).length < 1e-5, 'Protected neck moved'
    return {'vertices': len(mesh.vertices), 'round': round_number,
            'max_displacement_cm': max((v.co-old).length for v, old in zip(mesh.vertices, before))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--round', type=int, required=True)
    parser.add_argument('--players', nargs='+', choices=tuple(SOURCES))
    parser.add_argument('--views', nargs='+', default=['front'],
                        choices=('front', 'threequarter', 'profile'))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    assert args.round == 1, 'Later rounds require their own reviewed correction'
    metrics = json.loads((PROJECT/'docs/art_briefs/br022_landmark_fit_2026_10_29/fit_metrics.json').read_text())['players']
    for identity in args.players or ('robbie_roden', 'david_murray', 'des_feeney_sr'):
        source = HERE/SOURCES[identity] if args.round == 1 else PREVIEW/f'round_{args.round-1}'/SOURCES[identity]
        bpy.ops.wm.open_mainfile(filepath=str(source))
        head = bpy.data.objects['Skin_Head']
        report = transform_head(head, identity, metrics, args.round)
        bpy.context.scene['five_rounds_revision'] = args.round
        output = PREVIEW/f'round_{args.round}'/SOURCES[identity]
        output.parent.mkdir(parents=True, exist_ok=True)
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
        shane_player_finish.TEXTURES = PREVIEW/f'round_{args.round}'/'temporary_textures'
        shane_player_finish.TEXTURES.mkdir(parents=True, exist_ok=True)
        build_groom(head, bpy.data.objects['YBot_Armature'], identity)
        render(head, PREVIEW/f'round_{args.round}'/identity, views=tuple(args.views))
        print('FIVE_ROUNDS_PREVIEW', identity, report, flush=True)


if __name__ == '__main__':
    main()
