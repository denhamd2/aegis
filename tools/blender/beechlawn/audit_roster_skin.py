#!/usr/bin/env python3
"""Check pigment and protected neck continuity in the actual shipped GLBs.

Run with ordinary Python (numpy/Pillow). This samples anatomical UVs, not an
atlas-wide median that could accidentally measure unused background texels.
"""
import io
import json
from pathlib import Path
import struct
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT/'games/beechlawn_rovers'
SHARED = PROJECT/'assets/characters/shared'


class Package:
    def __init__(self, path):
        raw = path.read_bytes()
        length = struct.unpack_from('<I', raw, 12)[0]
        self.doc = json.loads(raw[20:20+length])
        self.binary = raw[28+length:]

    def array(self, index):
        accessor = self.doc['accessors'][index]
        view = self.doc['bufferViews'][accessor['bufferView']]
        dtype = {5126:'<f4', 5125:'<u4', 5123:'<u2', 5121:'u1'}[accessor['componentType']]
        columns = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}[accessor['type']]
        itemsize = np.dtype(dtype).itemsize
        return np.ndarray((accessor['count'], columns), dtype=dtype, buffer=self.binary,
            offset=view.get('byteOffset', 0)+accessor.get('byteOffset', 0),
            strides=(view.get('byteStride', itemsize*columns), itemsize))

    def skin(self, name):
        node = next(n for n in self.doc['nodes'] if n.get('name') == name and 'mesh' in n)
        mesh = self.doc['meshes'][node['mesh']]
        assert len(mesh['primitives']) == 1
        primitive = mesh['primitives'][0]
        material = self.doc['materials'][primitive['material']]
        assert material['pbrMetallicRoughness'].get('baseColorFactor', [1]*4) == [1]*4
        image_index = self.doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
        image = self.doc['images'][image_index]
        view = self.doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        pixels = np.asarray(Image.open(io.BytesIO(self.binary[start:start+view['byteLength']])).convert('RGB'))/255.
        positions = self.array(primitive['attributes']['POSITION'])
        uv = self.array(primitive['attributes']['TEXCOORD_0'])
        # glTF stores UV coordinates with the image's top-down convention.
        return positions, uv, pixels


def sample(pixels, uv):
    h, w = pixels.shape[:2]
    x = np.clip(np.rint(uv[:,0]*(w-1)).astype(int), 0, w-1)
    y = np.clip(np.rint(uv[:,1]*(h-1)).astype(int), 0, h-1)
    return pixels[y, x]


master = Package(SHARED/'heads/master.glb')
_, _, common = master.skin('Skin_Head')
reports = {}
for identity, path in (
    ('shared', SHARED/'heads/master.glb'),
    ('shane', SHARED/'heads/players/shane_denham.glb'),
    ('des_player', SHARED/'heads/players/bordeaux_09.glb'),
    ('john', SHARED/'heads/players/john_orourke.glb'),
    ('des_referee', SHARED/'heads/players/des_feeney_sr.glb'),
):
    p, uv, pixels = Package(path).skin('Skin_Head')
    forehead = (p[:,1]>1.70)&(p[:,1]<1.725)&(p[:,2]>.07)&(abs(p[:,0])<.035)
    neck = (p[:,1]<1.54)&(p[:,2]>0)
    assert forehead.sum()>4 and neck.sum()>10
    colour = np.median(sample(pixels, uv[forehead]), axis=0)
    # Broad guardrail against the former brown/orange pigment; likeness and
    # reference colour still require the fixed-light visual review.
    assert colour[1]>.48 and colour[0]/colour[1]<1.5, (identity, colour)
    difference = abs(sample(pixels, uv[neck])-sample(common, uv[neck]))
    p99 = float(np.quantile(difference, .99))
    assert p99<.025, f'{identity}: protected neck discontinuity {p99}'
    reports[identity] = {'forehead_uv_samples':int(forehead.sum()), 'forehead_srgb':colour.tolist(),
                         'neck_uv_samples':int(neck.sum()), 'neck_p99_difference':p99}
body = Package(SHARED/'footballer_base.glb')
for part in ('YBot_Joints', 'Skin_Hands'):
    _, uv, pixels = body.skin(part)
    colour = np.median(sample(pixels, uv), axis=0)
    assert colour[1]>.48 and colour[0]/colour[1]<1.5, (part, colour)
    reports[part] = {'anatomical_uv_samples':len(uv), 'median_srgb':colour.tolist()}
report = {'result':'PASS', 'parts':reports,
          'scope':'Shipped skin pigment and common neck join; no artistic or native renderer approval'}
out = PROJECT/'docs/art_briefs/fair_skin_review/skin_uv_audit.json'
out.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
