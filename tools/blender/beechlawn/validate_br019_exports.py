#!/usr/bin/env python3
"""Check BR-019 animation-only GLBs against the shipping 65-bone rest."""
from pathlib import Path
import json
import struct

ROOT = Path(__file__).resolve().parents[3] / 'games/beechlawn_rovers/assets/characters/shared'


def glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF'
    size = struct.unpack_from('<I', raw, 12)[0]
    return raw, json.loads(raw[20:20 + size]), 20 + size + 8


def sample(asset, index):
    raw, doc, start = asset
    accessor = doc['accessors'][index]
    view = doc['bufferViews'][accessor['bufferView']]
    width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
    fmt = '<' + 'f' * width
    offset = start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', width * 4)
    return [struct.unpack_from(fmt, raw, offset + i * stride) for i in range(accessor['count'])]


baseline = glb(ROOT / 'left_strikes.glb')
base_inverse = sample(baseline, baseline[1]['skins'][0]['inverseBindMatrices'])
base_joints = [baseline[1]['nodes'][index]['name'] for index in baseline[1]['skins'][0]['joints']]
expected = {
    'br019_strikes': {'AN_Beechlawn_Shot' + style + foot for style in ('Power', 'Finesse', 'Low') for foot in ('Right', 'Left')},
    'br019_header_duel': {'AN_Beechlawn_HeaderDuel'},
    'br019_keeper_claim': {'AN_Beechlawn_KeeperHighClaim'},
}
for name, clips in expected.items():
    asset = glb(ROOT / (name + '.glb'))
    doc = asset[1]
    assert not doc.get('meshes'), name
    assert len(doc['skins']) == 1 and len(doc['skins'][0]['joints']) == 65
    assert [doc['nodes'][index]['name'] for index in doc['skins'][0]['joints']] == base_joints
    assert sample(asset, doc['skins'][0]['inverseBindMatrices']) == base_inverse
    assert {motion['name'] for motion in doc['animations']} == clips
    for motion in doc['animations']:
        times = [doc['accessors'][sampler['input']] for sampler in motion['samplers']]
        assert abs(min(item['min'][0] for item in times)) < 1e-6
        expected_duration = .9 if name == 'br019_strikes' else 44 / 60 if name == 'br019_header_duel' else 78 / 60
        assert abs(max(item['max'][0] for item in times) - expected_duration) < 1e-5
for style in ('power', 'finesse', 'low'):
    for foot in ('right', 'left'):
        data = json.loads((ROOT / f'shot_{style}_{foot}_contact.json').read_text())
        assert data['clip'] == f'AN_Beechlawn_Shot{style.capitalize()}{foot.capitalize()}'
        assert (data['event'], data['frame'], data['fps'], data['time_seconds']) == ('ball_contact', 18, 60, .3)
data = json.loads((ROOT / 'br019_header_duel_contact.json').read_text())
assert data['clip'] == 'AN_Beechlawn_HeaderDuel' and (data['frame'], data['fps']) == (18, 60)
print('BR019_EXPORTS PASS: eight animation-only clips, unchanged 65-bone rest, 60 Hz contacts')
