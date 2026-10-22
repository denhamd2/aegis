"""Refresh skin in current production sources without rebuilding body or motion.

Run with Blender, then run build_roster_heads.py and Godot import. Shared GLB
updates replace only embedded skin PNGs; every other buffer view is verified
byte-identical, retaining the fitted kit, rig and all 19 animation clips.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT / 'games/beechlawn_rovers'
sys.path.insert(0, str(HERE))
from skin_palette import SHARED_SKIN, PALETTE_REVISION


def rebalance_image(image, previous_pigment):
    assert image.colorspace_settings.name == 'sRGB'
    width, height = image.size
    pixels = np.empty(width*height*4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)
    rgb = pixels[:, :, :3]
    # Rebalance pigment, preserving dark brows/lip detail and all alpha.
    weight = np.clip((rgb.max(axis=2)-.16)/.26, 0, 1)
    weight = (weight*weight*(3-2*weight))[:, :, None]
    ratio = np.array(SHARED_SKIN)/np.array(previous_pigment)
    rgb[:] = np.clip(rgb*(1+(ratio-1)*weight), 0, 1)
    image.pixels.foreach_set(pixels.ravel())
    path = Path(bpy.path.abspath(image.filepath))
    image.filepath_raw = str(path)
    image.save()
    # File-backed sRGB and reloaded packed source must agree with glTF PNG.
    loaded = bpy.data.images.load(str(path), check_existing=False)
    loaded.pack()
    for material in bpy.data.materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image == image:
                    node.image = loaded
    return path


def refresh_common(filename):
    bpy.ops.wm.open_mainfile(filepath=str(HERE/filename))
    revision = bpy.context.scene.get('skin_palette_revision')
    previous_palettes = {None: (.68, .43, .345), 'fair-reference-v1': (.76, .61, .555)}
    assert revision in (*previous_palettes, PALETTE_REVISION), 'Review the previous palette before migrating it'
    images = set()
    for name in ('YBot_Joints', 'Skin_Hands', 'Skin_Head'):
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        for material in obj.data.materials:
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image and 'albedo' in node.image.name:
                    images.add(node.image)
    assert images, 'No production skin pigment found'
    paths = [Path(bpy.path.abspath(im.filepath)) for im in images]
    if revision != PALETTE_REVISION:
        paths = [rebalance_image(im, previous_palettes[revision]) for im in images]
        bpy.context.scene['skin_palette_revision'] = PALETTE_REVISION
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(HERE/filename), compress=True)
    print('SKIN_SOURCE', filename, 'palette', PALETTE_REVISION, flush=True)
    return {path.stem: path for path in paths}


def patch_shared_images(paths):
    asset = PROJECT/'assets/characters/shared/footballer_base.glb'
    raw = asset.read_bytes()
    json_length = struct.unpack_from('<I', raw, 12)[0]
    document = json.loads(raw[20:20+json_length])
    binary = raw[28+json_length:]
    replacements = {im['bufferView']: paths[im['name']].read_bytes()
                    for im in document['images'] if im['name'] in paths}
    assert len(replacements) == 2 and len(document['animations']) == 19
    original = []
    rebuilt = bytearray()
    for index, view in enumerate(document['bufferViews']):
        start = view.get('byteOffset', 0)
        data = binary[start:start+view['byteLength']]
        original.append(data)
        replacement = replacements.get(index, data)
        rebuilt.extend(b'\0'*(-len(rebuilt) % 4))
        view['byteOffset'] = len(rebuilt)
        view['byteLength'] = len(replacement)
        rebuilt.extend(replacement)
    for index, view in enumerate(document['bufferViews']):
        if index not in replacements:
            start = view['byteOffset']
            assert rebuilt[start:start+view['byteLength']] == original[index]
    document['buffers'][0]['byteLength'] = len(rebuilt)
    payload = json.dumps(document, separators=(',', ':')).encode()
    payload += b' '*(-len(payload) % 4)
    rebuilt.extend(b'\0'*(-len(rebuilt) % 4))
    result = (struct.pack('<III', 0x46546c67, 2, 28+len(payload)+len(rebuilt))
              + struct.pack('<I4s', len(payload), b'JSON') + payload
              + struct.pack('<I4s', len(rebuilt), b'BIN\0') + rebuilt)
    asset.write_bytes(result)
    return {'unchanged_buffer_views': len(original)-len(replacements),
            'replaced_skin_images': len(replacements), 'retained_animations': 19,
            'asset_sha256': hashlib.sha256(result).hexdigest()}


def refresh_individual_sources():
    from build_roster_heads import open_master, snapshot, apply_sculpt
    from author_four_head_finish import SOURCES
    from player_head_finish import finish_head
    for identity, source in SOURCES.items():
        open_master()
        revision = snapshot()['revision']
        data = json.loads((HERE/'head_pipeline/deltas'/f'{identity}.json').read_text())
        assert data['master_revision'] == revision
        apply_sculpt(data)
        finish_head(bpy.data.objects['Skin_Head'], identity)
        bpy.context.scene['head_master_revision'] = revision
        bpy.context.scene['head_player_id'] = identity
        bpy.context.preferences.filepaths.save_version = 0
        for path in (HERE/source, HERE/'head_pipeline/work'/f'{identity}.blend'):
            bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
        print('INDIVIDUAL_SKIN_SOURCE', identity, flush=True)


paths = refresh_common('footballer_shared.blend')
report = patch_shared_images(paths)
refresh_common('footballer_head_master.blend')
refresh_individual_sources()
report.update(palette_revision=PALETTE_REVISION,
              scope='Source skin only; topology, bind, normals, kit, eyes and hair unchanged')
out = PROJECT/'docs/art_briefs/fair_skin_review'
out.mkdir(parents=True, exist_ok=True)
(out/'source_refresh.json').write_text(json.dumps(report, indent=2)+'\n')
print('ROSTER_SKIN_REFRESH', json.dumps(report), flush=True)
