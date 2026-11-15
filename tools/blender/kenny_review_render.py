#!/usr/bin/env python3
"""Compatibility entry point for Kenny's sole packed native authority.

The previous donor-reading builder is historical (Git history). Regeneration
now runs tools/blender/characters/kenny_character.py from Kenny.blend only.
"""
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[2]
    builder = root / 'tools/blender/characters/kenny_character.py'
    args = [shutil.which('blender') or 'blender', '-b', '--factory-startup', '--python', str(builder), '--', 'review']
    if 'review' == 'review':
        out = sys.argv[1] if len(sys.argv) > 1 else str(root / 'gauntlet/refs/characters/review/blender')
        args += ['--out', out]
    return subprocess.run(args, check=False).returncode


if __name__ == '__main__':
    raise SystemExit(main())
