#!/usr/bin/env python3
"""Six seeded real-match scenarios; thresholds are test gates, never runtime quotas."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[1]
TEAMS = ['Beechlawn Rovers', 'Boardeaux']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--venue', choices=['kilmore_drive','rovers_arena'], default='kilmore_drive')
    parser.add_argument('--observe-only', action='store_true')
    parser.add_argument('--reuse-logs', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for kickoff in TEAMS:
        for variation in range(3):
            label = ('home' if kickoff == TEAMS[0] else 'away') + f'-{variation}'
            path = args.output / (label + '.log')
            if not (args.reuse_logs and path.is_file() and 'AI_MATCH_METRICS ' in path.read_text()):
                env = dict(os.environ, BEECHLAWN_KICKOFF_TEAM=kickoff,
                           BEECHLAWN_START_VARIATION=str(variation), BEECHLAWN_TEST_VENUE=args.venue)
                with path.open('w') as log:
                    result = subprocess.run([sys.executable, str(PROJECT/'tools/run_smoke_tests.py'),
                                             'eleven_v_eleven_match_soak.gd'], env=env,
                                            stdout=log, stderr=subprocess.STDOUT)
                if result.returncode:
                    print(path.read_text()[-6000:], flush=True)
                    return result.returncode
            line = next(line for line in path.read_text().splitlines() if line.startswith('AI_MATCH_METRICS '))
            record = json.loads(line.removeprefix('AI_MATCH_METRICS '))
            results.append(record)
            print(label, ' '.join(f'{team}: shots={record["teams"][team]["shots"]} '
                                 f'contested={record["teams"][team]["contested_shots"]}' for team in TEAMS), flush=True)
    totals = {team: sum(r['teams'][team]['shots'] for r in results) for team in TEAMS}
    passes = {team: sum(r['teams'][team]['shots'] >= 2 and r['teams'][team]['contested_shots'] >= 1
                        for r in results) for team in TEAMS}
    total = sum(totals.values())
    shares = {team: totals[team]/total if total else 0 for team in TEAMS}
    accepted = all(passes[t] >= 5 and .35 <= shares[t] <= .65 for t in TEAMS)
    report = dict(venue=args.venue, scenarios=results, total_shots=totals, qualifying_scenarios=passes,
                  shot_share=shares, accepted=accepted,
                  criteria='Each team: >=2 physical shots + >=1 contested in >=5/6; aggregate share 35–65%.')
    (args.output/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'scenarios'}, indent=2), flush=True)
    return 0 if accepted or args.observe_only else 1

if __name__ == '__main__':
    raise SystemExit(main())
