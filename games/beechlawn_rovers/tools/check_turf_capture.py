#!/usr/bin/env python3
"""Check rendered production-turf contrast and reflective lift at four angles.

Run after capture_native.py --match --venue rovers_arena --venue-view turf.
These native pixels test shader behaviour; they do not assert Mac GPU parity.
"""
import json
from pathlib import Path
import sys


def check(folder):
    report = json.loads((Path(folder) / 'match_broadcast.json').read_text())
    assert report['rendering_method'] == 'forward_plus'
    assert report['other_geometry_hidden'], 'Expected the minimized material fixture'
    assert report['venue'] == 'rovers_arena'
    assert len(report['cases']) == 4
    failures = []
    for case in report['cases']:
        assert case['samples'] >= 24, 'Insufficient projected pitch samples'
        print(f"TURF {case['camera']} length={case['length_contrast']:.3f} "
              f"cross={case['cross_contrast']:.3f} reflection={case['specular_fraction']:.3f}")
        # Broad, alternating cuts must survive all four camera orientations.
        # Limits are deliberately below the archived broadcast reference's
        # contrast and above the original cancellation/noise-only signal.
        if case['length_contrast'] < .10:
            failures.append(f"Length mowing fades at {case['camera']}")
        if case['cross_contrast'] < .055:
            failures.append(f"Cross mowing fades at {case['camera']}")
        # Relative increase over a render with SPECULAR=0, with identical
        # normals/albedo/sun/sky. Grass must not acquire a broad glossy lift.
        if case['specular_fraction'] > .16:
            failures.append(f"Excess broad turf reflection at {case['camera']}")
    for failure in failures:
        print('FAIL:', failure)
    print('TURF_RENDER', 'FAIL' if failures else 'PASS')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(check(sys.argv[1]))
