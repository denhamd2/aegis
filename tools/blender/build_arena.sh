#!/usr/bin/env bash
# Rebuild game/assets/environment/arena_bowl.glb from tools/blender/arena_bowl.py.
#
# Blender is not a build dependency of the game -- the .glb is committed, and
# CI never runs this. It is run by hand when a bowl constant in
# game/core/arena/arena_builder.gd changes, and the exporter reads those
# constants out of that file, so the two cannot be edited apart.
#
# Two ways to get a Blender, in preference order:
#
#   1. A `blender` on PATH (any 4.x).
#   2. The `bpy` module in a Python 3.11 environment: `pip install bpy==4.2.0`.
#      Set BPY_PYTHON to that interpreter. This is what the container the
#      model was first built in had, and it produces a byte-identical export.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/arena_bowl.py"
out="${1:-$here/../../game/assets/environment/arena_bowl.glb}"

if command -v blender >/dev/null 2>&1; then
    exec blender --background --python "$script" -- --out "$out"
fi

python_bin="${BPY_PYTHON:-python3}"
if ! "$python_bin" -c "import bpy" >/dev/null 2>&1; then
    echo "build_arena.sh: no 'blender' on PATH and '$python_bin' has no bpy module." >&2
    echo "  Install one: pip install bpy==4.2.0  (needs Python 3.11)" >&2
    exit 1
fi
exec "$python_bin" "$script" --out "$out"
