#!/usr/bin/env python3
"""Check the authored close-up GLBs retain animation and garment-mask data."""
import json
from pathlib import Path
import struct
import argparse

ROOT = Path(__file__).resolve().parents[3] / 'games/beechlawn_rovers/assets/characters/supporters'
COMPONENT = {5121: ('B', 1), 5123: ('H', 2), 5126: ('f', 4)}
WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def glb(path):
    data = path.read_bytes()
    assert data[:4] == b'glTF'
    json_size = struct.unpack_from('<I', data, 12)[0]
    document = json.loads(data[20:20 + json_size])
    return data, document, 20 + json_size + 8


def values(data, document, binary_start, index):
    accessor = document['accessors'][index]
    view = document['bufferViews'][accessor['bufferView']]
    fmt, size = COMPONENT[accessor['componentType']]
    width = WIDTH[accessor['type']]
    offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', size * width)
    unpack = struct.Struct('<' + fmt * width).unpack_from
    return (unpack(data, offset + i * stride) for i in range(accessor['count']))


def same_accessor(before, after, first, second):
    old_data, old_doc, old_start = before
    new_data, new_doc, new_start = after
    old, new = old_doc['accessors'][first], new_doc['accessors'][second]
    assert (old['count'], old['componentType'], old['type']) == (new['count'], new['componentType'], new['type'])
    assert all(a == b for a, b in zip(values(old_data, old_doc, old_start, first),
                                      values(new_data, new_doc, new_start, second))), (first, second)


def preserve_original(before, after):
    old_doc, new_doc = before[1], after[1]
    old_mesh, new_mesh = old_doc['meshes'][0]['primitives'][0], new_doc['meshes'][0]['primitives'][0]
    for name, index in old_mesh['attributes'].items():
        if name.startswith('TEXCOORD_') and int(name.removeprefix('TEXCOORD_')) >= 1:
            new_name = 'TEXCOORD_' + str(int(name.removeprefix('TEXCOORD_')) + 1)
        else:
            new_name = name
        same_accessor(before, after, index, new_mesh['attributes'][new_name])
    same_accessor(before, after, old_mesh['indices'], new_mesh['indices'])
    same_accessor(before, after, old_doc['skins'][0]['inverseBindMatrices'],
                  new_doc['skins'][0]['inverseBindMatrices'])
    for old_clip, new_clip in zip(old_doc['animations'], new_doc['animations']):
        assert old_clip['name'] == new_clip['name']
        assert old_clip['channels'] == new_clip['channels']
        for old_sample, new_sample in zip(old_clip['samplers'], new_clip['samplers']):
            assert old_sample['interpolation'] == new_sample['interpolation']
            for key in ('input', 'output'):
                same_accessor(before, after, old_sample[key], new_sample[key])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, help='Previous assets/characters/supporters directory for exact preservation audit')
    args = parser.parse_args()
    total_vertices = 0
    for avatar in range(12):
        data, document, binary_start = glb(ROOT / f'fan_{avatar:02d}.glb')
        attributes = document['meshes'][0]['primitives'][0]['attributes']
        assert 'TEXCOORD_0' in attributes and 'TEXCOORD_1' in attributes
        assert len(document['animations']) == 9 and len(document['skins'][0]['joints']) == 80
        assert {clip['name'] for clip in document['animations']} == {
            'Fan_' + state for state in
            ('Seated', 'Attention', 'Rise', 'Clap', 'Cheer', 'Disappoint', 'Flag', 'Sit', 'Stand')}
        mask = list(values(data, document, binary_start, attributes['TEXCOORD_1']))
        info = list(values(data, document, binary_start, attributes['COLOR_1']))
        assert len(mask) == len(info)
        assert min(uv[1] for uv in mask) < .01 and max(uv[1] for uv in mask) > .99
        assert all(abs(uv[1] - colour[0] / 65535.0) < .001 for uv, colour in zip(mask, info))
        expected_uvs = 4 if avatar == 7 else 3 if avatar == 5 else 2
        assert sum(key.startswith('TEXCOORD_') for key in attributes) == expected_uvs
        if args.baseline:
            preserve_original(glb(args.baseline / f'fan_{avatar:02d}.glb'),
                              (data, document, binary_start))
        total_vertices += len(mask)
    print(f'SUPPORTER_EXPORTS PASS: 12 masks, 9 clips and 80 bones each; {total_vertices} vertices'
          + ('; baseline mesh/rig/animation samples preserved' if args.baseline else ''))


if __name__ == '__main__':
    main()
