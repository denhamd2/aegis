"""Check exported cheek/jaw/sideburn coverage and fitted facial-fibre roots.

Run with headless Blender after John's scoped head/groom export. These guards
catch the previous front-only beard; native turned views establish appearance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT/'games/beechlawn_rovers'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
source = HERE/'john_orourke_head.blend'
asset = PROJECT/'assets/characters/shared/heads/john_swept.glb'
bpy.ops.wm.open_mainfile(filepath=str(source))
head = bpy.data.objects['Skin_Head'].data
groom = bpy.data.objects['Hair_Shane_ShortCropCards'].data
facial_indices = {i for face in groom.polygons if face.material_index < 3 for i in face.vertices}
facial = [groom.vertices[i].co.copy() for i in sorted(facial_indices)]
surface = BVHTree.FromPolygons([v.co for v in head.vertices], [tuple(p.vertices) for p in head.polygons])
fit_error = max(surface.find_nearest(p)[3] for p in facial)
assert fit_error < .24, ('Facial fibres float above the fitted head', fit_error)

raw = asset.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
binary = raw[28+length:]
mesh = next(m for m in doc['meshes'] if m['name'] == 'Hair_Shane_ShortCropCards')
positions = []
palette = {}
for primitive in mesh['primitives']:
    material = doc['materials'][primitive['material']]
    name = material['name']
    if name not in {f'MAT_FittedHair_john_orourke_{i}' for i in range(3)}:
        continue
    palette[name] = material['pbrMetallicRoughness']['baseColorFactor']
    a = doc['accessors'][primitive['attributes']['POSITION']]
    v = doc['bufferViews'][a['bufferView']]
    positions.append(np.ndarray((a['count'], 3), dtype='<f4', buffer=binary,
        offset=v.get('byteOffset', 0)+a.get('byteOffset', 0),
        strides=(v.get('byteStride', 12), 4))*100.)
exported = np.concatenate(positions)
expected = ((.065, .030, .013), (.095, .048, .022), (.135, .075, .038))
for i, rgb in enumerate(expected):
    assert np.allclose(palette[f'MAT_FittedHair_john_orourke_{i}'], (*rgb, 1), atol=1e-7)

def coverage(points):
    x,y,z = np.asarray(points).T
    areas = {}
    for label, side in (('left', -1), ('right', 1)):
        sx = x*side
        areas[label] = {
            'cheek_vertices': int(np.sum((sx>5)&(y>160)&(y<163.2)&(z>3)&(z<7))),
            'sideburn_vertices': int(np.sum((sx>5.4)&(y>164)&(y<168.9)&(z>2.5)&(z<4.9))),
            'jaw_vertices': int(np.sum((sx>4.2)&(y>156.4)&(y<160)&(z>2)&(z<8))),
        }
        assert all(count>40 for count in areas[label].values()), (label, areas[label])
    ear = (abs(x)>6)&(y>161)&(y<168)&(z<.3)
    assert not np.any(ear), 'Beard incorrectly covers the ear'
    return areas

report = {
    'result': 'PASS', 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'groom_sha256': hashlib.sha256(raw).hexdigest(),
    'source_coverage': coverage([tuple(p) for p in facial]),
    'export_coverage': coverage(exported), 'max_fibre_surface_distance_cm': fit_error,
    'preserved_warm_beard_palette': palette,
    'scope': 'Bilateral facial-fibre coverage, ear exclusion, fitted surface distance and unchanged beard colour. Native turned views required for visual acceptance.',
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2)+'\n')
print('JOHN_BEARD_AUDIT PASS', json.dumps(report['export_coverage']), flush=True)
