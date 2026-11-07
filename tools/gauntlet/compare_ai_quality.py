#!/usr/bin/env python3
"""Compare seeded AI probe checkpoints; never interpret host timing as Mac fps."""
import argparse
from collections import Counter
import json
from pathlib import Path
import statistics


def read_rows(paths):
    rows = {}
    for path in paths:
        data = json.loads(Path(path).read_text())
        assert data['arena_omitted'], f'{path}: unexpected fixture'
        for row in data['rows']:
            key = (row['matchup'], row['seed'])
            assert key not in rows, f'duplicate match: {key}'
            assert row['winner'] and row['method'] != 'budget', f'unfinished match: {key}'
            for fighter in row['fighters']:
                assert Counter(fighter['sequence']) == Counter(fighter['attempted'])
                for move, count in fighter['landed'].items():
                    # Procedural contact stubs with no catalogued move id are
                    # reported separately, not assigned to a named move.
                    if move:
                        assert count <= fighter['attempted'].get(move, 0), (key, move)
            rows[key] = row
    return rows


def big(move):
    return bool(move) and not move.startswith(('strike_', 'ground_', 'chain_'))


def summarize(rows):
    attempts, landed = Counter(), Counter()
    repeated = adjacent = total_big = unique = rope_runs = setups = spear_matches = 0
    for row in rows.values():
        spear_in_match = False
        for fighter in row['fighters']:
            attempts.update(fighter['attempted'])
            landed.update(fighter['landed'])
            offence = [move for move in fighter['sequence'] if big(move)]
            total_big += len(offence)
            unique += len(set(offence))
            for index, move in enumerate(offence):
                repeated += move in offence[max(0, index - 2):index]
                adjacent += index > 0 and move == offence[index - 1]
            spear_in_match |= fighter['attempted'].get('running_spear', 0) > 0
            rope_runs += fighter['rope_runs']
            setups += fighter['spear_setups']
        spear_matches += spear_in_match
    return {
        'matches_completed': len(rows),
        'mean_match_seconds': round(statistics.mean(row['ticks'] / 60 for row in rows.values()), 2),
        'big_attempts': total_big,
        'vertical_suplex_attempts': attempts['grapple_vertical_suplex'],
        'vertical_suplex_share_percent': round(100 * attempts['grapple_vertical_suplex'] / max(total_big, 1), 2),
        'adjacent_big_repeats': adjacent,
        'big_repeats_within_two': repeated,
        'mean_distinct_big_moves_per_fighter': round(unique / (2 * len(rows)), 2),
        'running_spear_attempts': attempts['running_spear'],
        'running_spear_landings': landed['running_spear'],
        'matches_with_running_spear': spear_matches,
        'spear_setups': setups,
        'rope_runs': rope_runs,
        'uncatalogued_contact_landings': landed.pop('', 0),
        'attempted': dict(sorted(attempts.items())),
        'landed': dict(sorted(landed.items())),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', nargs='+', required=True)
    parser.add_argument('--after', nargs='+', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    before, after = read_rows(args.before), read_rows(args.after)
    assert before.keys() == after.keys(), 'matchup/seed coverage differs'
    output = {'before': summarize(before), 'after': summarize(after),
              'native_m1_performance': 'unverified',
              'fixture': 'roster gameplay on base rig; arena omitted'}
    Path(args.out).write_text(json.dumps(output, indent=2) + '\n')
    for label, data in output.items():
        if isinstance(data, dict):
            print(label, {key: value for key, value in data.items() if key not in ('attempted', 'landed')})


if __name__ == '__main__':
    main()
