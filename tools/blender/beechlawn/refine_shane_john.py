"""Edit the current individual cages in place; preview before apply/export.

Local coordinates are production armature centimetres, +Y up/+Z face.
The common neck, UV layout, weights, body and animation sources are protected.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT / 'games/beechlawn_rovers'
sys.path.insert(0, str(HERE))
from author_four_head_finish import SOURCES, render
from build_roster_heads import SOURCE, PARTS, apply_sculpt_part, write_json
from shane_head_variants import delta_data
from player_head_finish import smooth, field, finish_head

REVISION = 'shane-john-portrait-planes-v1'
DETAIL_REVISION = 'shane-john-soft-tissue-v2'


def refine_detail(point, identity):
    x,y,z=point
    if y<154:return point.copy()
    front=smooth(3.5,7.5,z)
    seam=smooth(154,157,y)
    jaw=field(x,y,5.7,157.5,2.1,1.9)*front*seam
    amount=.045 if identity=='shane_denham' else .070
    x *= 1-amount*jaw
    y += .22*jaw
    z += .12*field(x,y,0,156.2,3.0,1.5)*front*seam
    # Rounded alar tissue and a shallow, dimensional nasal crease.
    z += .085*field(x,y,1.2,162.25, .65,.55)*front
    z -= .055*field(x,y,1.7,162.0,.30,.50)*front
    if identity=='john_orourke':
        y += .12*field(x,y,2.55,160.1,1.0,.75)*front
        z += .09*field(x,y,4.4,161.6,2.1,1.8)*front
    return Vector((x,y,z))


def refine(point, identity):
    x, y, z = point
    if y < 154:
        return point.copy()
    front = smooth(3.5, 7.5, z)
    seam = smooth(154, 157, y)
    # Large planes are continuous through the malar/muzzle transition. The
    # inherited cheeks were shiny isolated bulbs over a hollow lower face.
    cheek = field(x, y, 4.8, 161.7, 2.6, 2.4) * front * seam
    lower = field(x, y, 4.5, 158.4, 2.6, 2.0) * front * seam
    if identity == 'shane_denham':
        x *= 1 - .023 * smooth(4.7, 7.8, abs(x)) * seam
        z += .22 * cheek + .17 * lower
        # Shane has a lower strong brow with a fairly straight medial third.
        brow = field(x, y, 3.25, 167.65, 2.15, .65) * front
        z += .23 * brow
        y -= .20 * brow
        z += .12 * field(x, y, 0, 165.6, .9, 1.7) * front
        z += .14 * field(x, y, 0, 162.5, 1.1, .95) * front
        # A rounded chin, a little lower than the previous generic cage.
        y -= .38 * field(x, y, 0, 155.5, 5.0, 2.0) * front * seam
        z += .14 * field(x, y, 0, 156.2, 3.1, 1.2) * front * seam
        # A real cupid's bow and lip corners, rather than a flat pink shelf.
        z -= .10 * field(x, y, 0, 160.05, 2.4, .34) * front
        z += .07 * field(x, y, .65, 160.27, .46, .22) * front
        y += .055 * field(x, y, 3.0, 159.8, .75, .6) * front
        for level, depth in ((169.0,.025),(170.1,.021),(171.1,.015)):
            crease=level+.12*math.cos(x*.45)
            z -= depth*math.exp(-((y-crease)/.13)**2-(x/5.0)**6)*front
    else:
        z += .13 * cheek + .12 * lower
        # The corrected roll-normalized portrait has a compact nasal tip and
        # narrower mouth. Bound support away from lids and the chin interface.
        nose = math.exp(-(x/2.45)**6 - ((y-162.8)/1.45)**4) * front
        x *= 1 - .105 * nose
        y += .28 * nose
        z += .10 * field(x, y, 0, 163.2, .9, .7) * front
        z -= .14 * field(x, y, 1.35, 162.5, .7, .60) * front
        mouth = math.exp(-(x/5.2)**6 - ((y-160.35)/1.55)**4) * front
        mouth *= 1 - smooth(161.7, 162.8, y)
        x *= 1 - .11 * mouth
        y += .10 * mouth
        z -= .13 * field(x, y, 0, 160.3, 2.4, .5) * front
        # Smaller upper lip and soft, less angular mandibular corners.
        y = 160.4 + (y-160.4) * (1-.11*mouth)
        y += .11*field(x,y,2.7,160.1,1.0,.8)*front
        z += .15 * field(x, y, 3.8, 157.6, 2.2, 1.6) * front * seam
        brow = field(x, y, 3.5, 167.7, 2.0, .6) * front
        z += .085 * brow
    # Subtle lower-lid cushion and tear-trough transition, not a painted bag.
    z += .075 * field(x, y, 3.45, 165.55, 1.55, .40) * front
    z -= .045 * field(x, y, 4.25, 164.9, 1.3, .32) * front
    # Real nostril/alar and nasolabial relief remains visible in a clay turn.
    fold = 1.85 + .43 * (162.25-y)
    z -= (.055 if identity == 'shane_denham' else .035) * math.exp(-((abs(x)-fold)/.30)**2-((y-160.9)/1.5)**4) * front
    return Vector((x, y, z))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--player', choices=('shane_denham', 'john_orourke'), required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--surfaces-only', action='store_true')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--detail', action='store_true',help='Second soft-tissue pass on the saved v1 source')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    identity = args.player
    source = HERE / SOURCES[identity]
    bpy.ops.wm.open_mainfile(filepath=str(source))
    head = bpy.data.objects['Skin_Head']
    before_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    if not args.surfaces_only:
        if args.detail:
            assert bpy.context.scene.get('portrait_refinement_revision')==REVISION
            assert bpy.context.scene.get('portrait_detail_revision')!=DETAIL_REVISION,'Detail pass already applied'
        else:
            assert bpy.context.scene.get('portrait_refinement_revision') != REVISION, 'Already applied; edit the saved source instead'
        base = head.data.copy()
        edited = base.copy()
        for vertex in edited.vertices:
            vertex.co = (refine_detail if args.detail else refine)(vertex.co, identity)
        apply_sculpt_part(head, delta_data(base, edited), True)
        bpy.data.meshes.remove(base)
        bpy.data.meshes.remove(edited)
        bpy.context.scene['portrait_detail_revision' if args.detail else 'portrait_refinement_revision'] = DETAIL_REVISION if args.detail else REVISION
    if args.apply:
        with bpy.data.libraries.load(str(SOURCE), link=False) as (_, target):
            target.objects = list(PARTS)
        parts = {name: delta_data(base.data, bpy.data.objects[name].data)
                 for name, base in zip(PARTS, target.objects)}
        for obj in target.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
        finish_head(head, identity)
        from player_head_groom import build_groom
        build_groom(head, bpy.data.objects['YBot_Armature'], identity)
        destination = source
        write_json(HERE/'head_pipeline/deltas'/f'{identity}.json', {
            'player_id': identity,
            'master_revision': bpy.context.scene['head_master_revision'],
            'parts': parts})
    else:
        destination = PROJECT/'build/shane_john_refinement'/f'{identity}_preview.blend'
    bpy.context.preferences.filepaths.save_version = 0
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination), compress=True)
    output = PROJECT/'docs/art_briefs/shane_john_refinement'/('clay_after' if args.apply else 'clay_preview')/identity
    if args.render:
        # Groom is reviewed separately; it must not obscure clay silhouette.
        for obj in bpy.context.scene.objects:
            if obj.name.startswith('Hair_'):
                obj.hide_render = True
        render(head, output, clay=True)
    print('PORTRAIT_REFINEMENT', identity, 'apply' if args.apply else 'preview', before_hash, flush=True)


if __name__ == '__main__':
    main()
