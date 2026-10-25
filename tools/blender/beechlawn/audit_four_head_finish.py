"""Check four saved Blender heads against shipped geometry and shared interfaces.

Run after build_roster_heads.py with Blender --python-exit-code 1. This is an
asset integrity gate, not a likeness or native performance certification.
"""
import hashlib
import argparse
import json
from pathlib import Path
import struct
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT/'games/beechlawn_rovers'
BASE_EVIDENCE = PROJECT/'docs/art_briefs/four_head_finish'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=BASE_EVIDENCE)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=args.output
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0, str(HERE))
from author_four_head_finish import SOURCES


def load_glb(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    return raw, json.loads(raw[20:20+length]), raw[28+length:]


def positions(document, binary, primitive):
    accessor = document['accessors'][primitive['attributes']['POSITION']]
    view = document['bufferViews'][accessor['bufferView']]
    assert accessor['componentType'] == 5126 and accessor['type'] == 'VEC3'
    return np.ndarray((accessor['count'], 3), dtype='<f4', buffer=binary,
        offset=view.get('byteOffset', 0)+accessor.get('byteOffset', 0),
        strides=(view.get('byteStride', 12), 4))


def tree(points):
    result = KDTree(len(points))
    for index, point in enumerate(points):
        result.insert(Vector(point), index)
    result.balance()
    return result


bpy.ops.wm.open_mainfile(filepath=str(HERE/'footballer_head_master.blend'))
master = bpy.data.objects['Skin_Head'].data
neck = {v.index: v.co.copy() for v in master.vertices if v.co.y < 154}
neck_uv = {loop.index: master.uv_layers.active.data[loop.index].uv.copy()
           for loop in master.loops if loop.vertex_index in neck}
master.calc_loop_triangles()
lip_triangles = []
for triangle in master.loop_triangles:
    centre = sum((master.vertices[i].co for i in triangle.vertices), Vector())/3
    if 159 < centre.y < 160.6 and abs(centre.x) < 3.5 and centre.z > 9 and triangle.normal.z > .25:
        lip_triangles.append((tuple(triangle.vertices), triangle.normal.copy()))

report = {'result': 'PASS', 'heads': {}, 'scope': 'Neutral source/export geometry, UV/neck preservation, lip winding and package materials; runtime binds/poses checked separately.'}
for identity, source in SOURCES.items():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/source))
    assert bpy.context.scene['head_player_id'] == identity
    assert bpy.context.scene['head_finish_revision'] == 'four-head-reference-v2'
    asset = PROJECT/f'assets/characters/shared/heads/players/{identity}.glb'
    raw, document, binary = load_glb(asset)
    parts = {}
    for name in ('Skin_Head', 'Eye_l', 'Eye_r'):
        mesh = next(m for m in document['meshes'] if m['name'] == name)
        actual = np.concatenate([positions(document, binary, p) for p in mesh['primitives']])
        obj = bpy.data.objects[name]
        expected = [v.co*.01 for v in obj.data.vertices]
        expected_tree, actual_tree = tree(expected), tree(actual)
        error = max(max(expected_tree.find(Vector(p))[2] for p in actual),
                    max(actual_tree.find(p)[2] for p in expected))
        assert error < 2e-6, (identity, name, error)
        parts[name] = {'source_vertices': len(expected), 'exported_vertices': len(actual), 'max_error_m': error}
        if name == 'Skin_Head':
            assert all(not any(k.startswith('COLOR_') for k in p['attributes']) for p in mesh['primitives'])
    mesh = bpy.data.objects['Skin_Head'].data
    assert max((mesh.vertices[i].co-p).length for i,p in neck.items()) < 1e-5
    assert max((mesh.uv_layers.active.data[i].uv-uv).length for i,uv in neck_uv.items()) < 1e-6
    flips = 0
    for indices, normal in lip_triangles:
        a,b,c = (mesh.vertices[i].co for i in indices)
        flips += int((b-a).cross(c-a).normalized().dot(normal) < 0)
    assert flips == 0, (identity, 'Inverted frontal lip triangles', flips)
    images = document.get('images', [])
    assert len(images) == 4 and all(im['name'].startswith(identity+'_finish_') for im in images)
    textures = []
    for im in images:
        view = document['bufferViews'][im['bufferView']]
        width, height = struct.unpack_from('>II', binary, view.get('byteOffset', 0)+16)
        textures.append({'name': im['name'], 'dimensions': [width,height]})
    report['heads'][identity] = {'source': source, 'sha256': hashlib.sha256(raw).hexdigest(),
        'parts': parts, 'textures': textures, 'protected_neck_vertices': len(neck),
        'frontal_lip_triangles': len(lip_triangles), 'inverted_frontal_lip_triangles': flips}

protected = json.loads((BASE_EVIDENCE/'protected_before.json').read_text())
for path, expected in protected.items():
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == expected, path
report['protected_shared_assets'] = protected
(OUT/'export_audit.json').write_text(json.dumps(report, indent=2)+'\n')
print('FOUR_HEAD_EXPORT_AUDIT PASS', ', '.join(report['heads']), flush=True)
