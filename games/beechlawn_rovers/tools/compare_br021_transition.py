#!/usr/bin/env python3
"""Compare two BR-021 live-foot traces and audit controller displacement."""
import argparse
import json
from math import dist
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    before = json.loads(args.baseline.read_text())
    after = json.loads(args.candidate.read_text())
    old_rows, new_rows = before['samples'], after['samples']
    assert len(old_rows) == len(new_rows) == 185
    assert all(a['tick'] == b['tick'] and a['phase'] == b['phase']
               for a, b in zip(old_rows, new_rows))
    path_delta = max(dist(a['root'], b['root']) for a, b in zip(old_rows, new_rows))
    speed_delta = max(abs(a['speed'] - b['speed']) for a, b in zip(old_rows, new_rows))
    assert path_delta < 1e-4 and speed_delta < 1e-4
    phases = {}
    for phase in ('start', 'turn', 'reverse'):
        old, new = before['summary'][phase], after['summary'][phase]
        phases[phase] = {
            'baseline_mean_mps': old['mean_low_foot_slip'],
            'candidate_mean_mps': new['mean_low_foot_slip'],
            'baseline_p90_mps': old['p90_low_foot_slip'],
            'candidate_p90_mps': new['p90_low_foot_slip'],
            'baseline_samples': old['samples'],
            'candidate_samples': new['samples'],
            'mean_reduction_percent': 100 * (1 - new['mean_low_foot_slip'] / old['mean_low_foot_slip']),
        }
    report = {'phases': phases, 'max_root_delta_m': path_delta,
              'max_speed_delta_mps': speed_delta, 'controller_path_preserved': True,
              'measurement': 'Low, vertically quiet world-space toe samples at 60 Hz; not boot sole.'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
