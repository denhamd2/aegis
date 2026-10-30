"""Bounded portrait-landmark fit for the six independent Beechlawn heads.

The reference measurements are eye-line normalized original photographs, not
generated roster art. Fit only reliable symmetric widths and feature heights;
expression-driven mouth width belongs in Smile. The rig, neck join, UVs and
weights are unchanged. Preview by default, then use --apply after visual review.
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
sys.path.insert(0, str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES, render
from build_roster_heads import PARTS, SOURCE, write_json
from player_head_groom import build_groom
from shane_head_variants import delta_data, layout_fingerprint

SOURCES = {**FOUR_SOURCES, 'robbie_roden': 'robbie_roden_head.blend',
           'david_murray': 'david_murray_head.blend'}
MEASUREMENTS = HERE / 'head_pipeline' / 'photo_landmark_fit.json'
REVISION = 'original-photo-landmark-fit-v1'
# Eye centres in the common armature-local centimetre cage are 6.694 cm apart.
EYE_DISTANCE_CM = 6.694


def smooth(a, b, value):
    t = max(0.0, min(1.0, (value-a)/(b-a)))
    return t*t*(3.0-2.0*t)


def field(x, y, cx, cy, sx, sy):
    return math.exp(-((abs(x)-cx)/sx)**4-((y-cy)/sy)**4)


def corrections(entry, identity):
    reference, model = entry['reference']['metrics'], entry['model']['metrics']
    ratio = lambda name: reference[name]/model[name]-1.0
    delta = lambda name: (reference[name]-model[name])*EYE_DISTANCE_CM
    result = {
        'face_width': max(-.09, min(.09, ratio('face_width')*.65)),
        'jaw_width': max(-.10, min(.10, ratio('jaw_width')*.70)),
        'nose_width': max(-.10, min(.10, ratio('nose_width')*.65)),
        'neutral_mouth_width': max(-.035, min(.035, ratio('mouth_width')*.28)),
        'smile_mouth_width': max(-.17, min(.17, ratio('mouth_width')*.72)),
        'nose_y': max(-.58, min(.58, delta('nose_y')*.72)),
        'mouth_y': max(-.35, min(.35, delta('mouth_y')*.65)),
        'chin_y': max(-.70, min(.35, delta('chin_y')*.53)),
    }
    if identity in ('robbie_roden', 'david_murray'):
        # Their photographs show broad tooth-showing smiles. Applying that
        # width/height to the resting lips creates a strained neutral frown.
        result['neutral_mouth_width'] = 0.0
        result['mouth_y'] = 0.0
    return result


def fit_point(point, correction, smile=False):
    x, y, z = point
    if y < 154.0:
        return point.copy()
    original_x, original_y = x, y
    front = smooth(4.5, 8.5, z)
    neck = smooth(154.0, 156.2, y)
    outer = smooth(3.4, 6.0, abs(x))
    cheek = field(x, y, 5.8, 164.0, 3.2, 3.8)
    jaw = field(x, y, 4.9, 158.2, 3.2, 3.1)
    nose = field(x, y, 1.4, 162.3, 2.0, 1.45)*front
    lip = field(x, y, 2.4, 159.72, 3.0, 1.15)*front
    chin = field(x, y, 2.0, 156.2, 4.0, 2.1)*front*neck
    x *= 1.0 + correction['face_width']*cheek*outer*neck
    x *= 1.0 + correction['jaw_width']*jaw*outer*front*neck
    x *= 1.0 + correction['nose_width']*nose
    x *= 1.0 + correction['smile_mouth_width' if smile else 'neutral_mouth_width']*lip
    y += correction['nose_y']*nose
    y += correction['mouth_y']*lip
    y += correction['chin_y']*chin
    # Only symmetric measurements are used; no automatic profile/depth warp
    # can be inferred from a single near-frontal photograph.
    assert y >= 153.99 or original_y < 154.0
    assert abs(x-original_x) < 1.1 and abs(y-original_y) < .9
    return Vector((x, y, z))


def fit_head(head, correction):
    mesh = head.data
    assert mesh.shape_keys and mesh.shape_keys.key_blocks.get('Smile')
    before = [(v.co.copy(), tuple((g.group, round(g.weight, 6)) for g in v.groups))
              for v in mesh.vertices]
    uv_count = len(mesh.uv_layers.active.data)
    for key in mesh.shape_keys.key_blocks:
        smile = key.name == 'Smile'
        for vertex in key.data:
            vertex.co = fit_point(vertex.co, correction, smile)
        key.value = 0.0
    for vertex, key_point in zip(mesh.vertices, mesh.shape_keys.key_blocks['Basis'].data):
        vertex.co = key_point.co
    mesh.update()
    assert len(mesh.vertices) == len(before)
    assert uv_count == len(mesh.uv_layers.active.data)
    for vertex, (old, groups) in zip(mesh.vertices, before):
        assert tuple((g.group, round(g.weight, 6)) for g in vertex.groups) == groups
        if old.y < 154.0:
            assert (vertex.co-old).length < 1e-5, 'Protected neck moved'
    return len(mesh.vertices)


def seal_robbie_blink(head):
    """Keep Robbie's fitted closed lid below the source visibility limit."""
    keys = head.data.shape_keys.key_blocks
    basis, blink = keys['Basis'], keys['Blink']
    for base, point in zip(basis.data, blink.data):
        x, y, z = base.co
        centre = min((-3.347, 3.347), key=lambda value: abs(value-x))
        mask = math.exp(-((x-centre)/1.8)**4-((y-166.526)/1.1)**4)
        mask *= smooth(7.2, 9.4, z)
        point.co.y += (-1.0 if y > 166.526 else 1.0)*.12*mask


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Save the inspected fitted source')
    parser.add_argument('--players', nargs='+', choices=tuple(SOURCES))
    parser.add_argument('--render', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    measurements = json.loads(MEASUREMENTS.read_text())['players']
    for identity in args.players or SOURCES:
        bpy.ops.wm.open_mainfile(filepath=str(HERE/SOURCES[identity]))
        scene = bpy.context.scene
        assert scene.get('photo_landmark_revision') != REVISION, 'Fit was already applied: '+identity
        rig = bpy.data.objects['YBot_Armature']
        head = bpy.data.objects['Skin_Head']
        correction = corrections(measurements[identity], identity)
        fit_head(head, correction)
        if identity == 'robbie_roden':
            seal_robbie_blink(head)
        scene['photo_landmark_revision'] = REVISION
        scene['photo_landmark_corrections'] = json.dumps(correction, sort_keys=True)
        if args.apply:
            with bpy.data.libraries.load(str(SOURCE), link=False) as (_, target):
                target.objects = list(PARTS)
            base = dict(zip(PARTS, target.objects))
            assert all(layout_fingerprint(base[name].data) == layout_fingerprint(bpy.data.objects[name].data)
                       for name in PARTS), 'Original-photo fit unexpectedly changed the shared topology'
            parts = {name: delta_data(base[name].data, bpy.data.objects[name].data) for name in PARTS}
            revision = json.loads((HERE/'head_pipeline/master.json').read_text())['revision']
            assert scene.get('head_master_revision') == revision, 'Source is based on a different master'
            for obj in base.values():
                bpy.data.objects.remove(obj, do_unlink=True)
            bpy.ops.outliner.orphans_purge(do_recursive=True)
        output = HERE/SOURCES[identity] if args.apply else ROOT/'games/beechlawn_rovers/build/head-fit-preview'/SOURCES[identity]
        output.parent.mkdir(parents=True, exist_ok=True)
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
        if args.apply:
            write_json(HERE/'head_pipeline/deltas'/f'{identity}.json', {
                'player_id': identity, 'master_revision': revision, 'parts': parts})
        if args.render:
            build_groom(head, rig, identity)
            folder = ROOT/'games/beechlawn_rovers/build/head-fit-preview'/identity
            render(head, folder, views=('front', 'threequarter', 'profile'))
        print('PORTRAIT_FIT', identity, correction, output, flush=True)


if __name__ == '__main__':
    main()
