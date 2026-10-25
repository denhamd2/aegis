#!/usr/bin/env python3
"""Stamp packaging time and full source identity before Godot export."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', required=True)
args = parser.parse_args()
if len(args.source) != 40 or any(c not in '0123456789abcdef' for c in args.source):
    parser.error('Source must be a full lowercase Git SHA')
path = Path(__file__).resolve().parents[1] / 'data/build_info.json'
data = json.loads(path.read_text())
data.update(source_sha=args.source, packaged_utc=datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC'))
path.write_text(json.dumps(data, indent=2)+'\n')
print(json.dumps(data))
