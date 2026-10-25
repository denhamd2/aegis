"""Preview/apply the four reference-led head refinements on the live master.

Default is geometry-only preview in ignored build storage. --apply captures
all four recipes, bakes their skin and saves editable production sources.
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
from build_roster_heads import open_master, snapshot, apply_sculpt_part, write_json, PARTS
from shane_head_variants import delta_data
from player_head_finish import IDENTITIES, sculpt, eye_sculpt, finish_head, soften_cheek_planes

SOURCES = {'shane_denham':'shane_denham_head.blend', 'john_orourke':'john_orourke_head.blend',
           'bordeaux_09':'des_feeney_head.blend', 'des_feeney_sr':'referee_des_feeney_head.blend'}


def render(head, output, clay=False, views=('front', 'threequarter', 'profile')):
    scene = bpy.context.scene
    for obj in list(scene.objects):
        if obj.type in {'LIGHT', 'CAMERA'}:
            bpy.data.objects.remove(obj, do_unlink=True)
    if clay:
        mat = bpy.data.materials.new('Review_Clay')
        mat.use_nodes = True
        mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.32, .32, .32, 1)
        mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .68
        head.data.materials[0] = mat
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.eevee.taa_render_samples = 12
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.30, .34, .38, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .25
    target = Vector((0, 0, 1.635))
    for name, position, power, size in (
        ('Key', (.28, -.42, 1.85), 5., .26),
        ('Fill', (-.3, -.35, 1.69), 2., .3),
        ('Rim', (.05, .25, 1.84), 2., .2),
    ):
        data = bpy.data.lights.new(name, 'AREA')
        data.energy = power
        data.shape = 'DISK'
        data.size = size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (target-obj.location).to_track_quat('-Z', 'Y').to_euler()
    data = bpy.data.cameras.new('HeadReview')
    data.type = 'ORTHO'
    data.ortho_scale = .36
    camera = bpy.data.objects.new('HeadReview', data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    output.mkdir(parents=True, exist_ok=True)
    for view, angle in (('front', -math.pi/2), ('threequarter', -math.pi/2+.52), ('profile', 0)):
        if view not in views:
            continue
        camera.location = target+Vector((math.cos(angle)*.78, math.sin(angle)*.78, .01))
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(output/(view+'.png'))
        bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--expressions-only', action='store_true')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--player', choices=IDENTITIES)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--view', choices=('front', 'threequarter', 'profile'))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for identity in (IDENTITIES if args.player is None else (args.player,)):
        if args.apply and not args.expressions_only and (HERE/SOURCES[identity]).exists():
            raise RuntimeError('Preserve the current artist source: '+SOURCES[identity]+'. Open/edit/capture it, then use build_roster_heads.py; this bootstrap would overwrite later anatomy and materials.')
        if args.expressions_only:
            from player_head_finish import facial_shapes
            bpy.ops.wm.open_mainfile(filepath=str(HERE/SOURCES[identity]))
            facial_shapes(bpy.data.objects['Skin_Head'])
            bpy.context.scene['head_finish_revision'] = 'four-head-reference-v2'
            bpy.context.preferences.filepaths.save_version = 0
            for path in (HERE/SOURCES[identity], HERE/'head_pipeline/work'/f'{identity}.blend'):
                bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
            continue
        open_master()
        revision = snapshot()['revision']
        parts = {}
        for name in PARTS:
            obj = bpy.data.objects[name]
            base = obj.data
            edited = base.copy()
            centre = sum((v.co for v in base.vertices), Vector())/len(base.vertices)
            for vertex in edited.vertices:
                vertex.co = sculpt(vertex.co, identity) if name == 'Skin_Head' else eye_sculpt(vertex.co, centre, identity)
            if name == 'Skin_Head':
                soften_cheek_planes(edited)
            data = delta_data(base, edited)
            if name == 'Skin_Head':
                assert all(base.vertices[int(i)].co.y>=154 for i in data['offsets']), 'Neck moved'
            apply_sculpt_part(obj, data, protect_neck=name == 'Skin_Head')
            parts[name] = data
            bpy.data.meshes.remove(edited)
        recipe = {'player_id':identity, 'master_revision':revision, 'parts':parts}
        head = bpy.data.objects['Skin_Head']
        bpy.context.scene['head_master_revision'] = revision
        bpy.context.scene['head_player_id'] = identity
        bpy.context.scene['head_finish_revision'] = 'four-head-reference-v2'
        bpy.context.preferences.filepaths.save_version = 0
        if args.apply:
            write_json(HERE/'head_pipeline/deltas'/f'{identity}.json', recipe)
            finish_head(head, identity)
            for path in (HERE/SOURCES[identity], HERE/'head_pipeline/work'/f'{identity}.blend'):
                bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
        else:
            path = PROJECT/'build/four-head-finish-preview'/f'{identity}.blend'
            path.parent.mkdir(parents=True, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
        if args.render or not args.apply:
            if args.apply:
                from player_head_groom import build_groom
                build_groom(head, bpy.data.objects['YBot_Armature'], identity)
            output = (args.output if args.output else PROJECT/'docs/art_briefs/four_head_finish'/('blender' if args.apply else 'clay'))/identity
            render(head, output, clay=not args.apply, views=(args.view,) if args.view else ('front', 'threequarter', 'profile'))
        print('HEAD_FINISH_SOURCE', identity, 'applied' if args.apply else 'preview', flush=True)


if __name__ == '__main__':
    main()
