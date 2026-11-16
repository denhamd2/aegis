"""Compare decoded GLB animation tracks exactly; no import/optimizer tolerance."""
import argparse
import hashlib
import json
import pathlib
import struct
import numpy as np

WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
DTYPE = {5126: '<f4', 5123: '<u2', 5125: '<u4'}
SELECTED = {'Run_Grapple_Attacker', 'Run_Grapple_Defender'}

class GLB:
    def __init__(self, path):
        self.path = str(path)
        data = pathlib.Path(path).read_bytes()
        self.sha256 = hashlib.sha256(data).hexdigest()
        self.byte_count = len(data)
        json_length = struct.unpack_from('<I', data, 12)[0]
        self.doc = json.loads(data[20:20 + json_length])
        start = 20 + json_length
        binary_length = struct.unpack_from('<I', data, start)[0]
        self.binary = data[start + 8:start + 8 + binary_length]
        self.animations = {a['name']: a for a in self.doc['animations']}

    def accessor(self, index):
        a = self.doc['accessors'][index]
        view = self.doc['bufferViews'][a['bufferView']]
        dtype = np.dtype(DTYPE[a['componentType']])
        width = WIDTH[a['type']]
        offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = view.get('byteStride', dtype.itemsize * width)
        return np.ndarray((a['count'], width), dtype=dtype, buffer=self.binary,
                          offset=offset, strides=(stride, dtype.itemsize)).copy()

    def tracks(self, name):
        animation = self.animations[name]
        tracks = {}
        for channel in animation['channels']:
            sampler = animation['samplers'][channel['sampler']]
            target = channel['target']
            key = (self.doc['nodes'][target['node']]['name'], target['path'],
                   sampler.get('interpolation', 'LINEAR'))
            tracks[key] = (self.accessor(sampler['input']), self.accessor(sampler['output']))
        return tracks


def compare(a, b, name):
    left, right = a.tracks(name), b.tracks(name)
    layout_equal = left.keys() == right.keys()
    exact = layout_equal
    differences = []
    for key in left.keys() & right.keys():
        ta, va = left[key]
        tb, vb = right[key]
        equal = (ta.dtype == tb.dtype and va.dtype == vb.dtype
                 and ta.shape == tb.shape and va.shape == vb.shape
                 and ta.tobytes() == tb.tobytes() and va.tobytes() == vb.tobytes())
        exact &= equal
        if not equal:
            differences.append({'track': '/'.join(key),
                                'same_time_bits': ta.shape == tb.shape and ta.tobytes() == tb.tobytes(),
                                'max_component_delta': float(np.max(np.abs(va.astype(float) - vb.astype(float))))
                                if va.shape == vb.shape else None})
    return {'clip': name, 'decoded_tracks_bit_exact': bool(exact),
            'track_layout_identical': layout_equal, 'differences': differences}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--published', required=True)
    parser.add_argument('--full', required=True)
    parser.add_argument('--scoped', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    published, full, scoped = [GLB(p) for p in (args.published, args.full, args.scoped)]
    selected = [compare(scoped, full, n) for n in sorted(SELECTED)]
    other = [compare(published, full, n) for n in sorted(full.animations.keys() - SELECTED)]
    report = {'full_path': full.path, 'full_sha256': full.sha256, 'full_bytes': full.byte_count,
              'published_sha256': published.sha256, 'scoped_sha256': scoped.sha256,
              'animation_count': len(full.animations),
              'animation_name_set_identical': published.animations.keys() == full.animations.keys(),
              'static_nodes_identical_to_published': published.doc['nodes'] == full.doc['nodes'],
              'unselected_count': len(other),
              'unselected_decoded_track_bit_exact_count': sum(r['decoded_tracks_bit_exact'] for r in other),
              'unselected_non_exact': [r for r in other if not r['decoded_tracks_bit_exact']],
              'selected_vs_frozen_scoped': selected}
    report['exact_parity_pass'] = (report['animation_count'] == 317
                                  and report['animation_name_set_identical']
                                  and report['static_nodes_identical_to_published']
                                  and report['unselected_count'] == 315
                                  and not report['unselected_non_exact']
                                  and all(r['decoded_tracks_bit_exact'] for r in selected))
    pathlib.Path(args.out).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report['exact_parity_pass'] else 1)

if __name__ == '__main__':
    main()
