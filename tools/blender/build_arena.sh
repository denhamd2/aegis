#!/usr/bin/env bash
# Rebuild the two models the seating bowl needs, from tools/blender/:
#
#   arena_bowl.glb   the hall, with its crowd baked in   (arena_bowl.py)
#   floor_crowd.glb  the six ringside fans, instanced    (floor_crowd.py)
#
# Blender is not a build dependency of the game -- both .glb files are
# committed, and CI never runs this. It is run by hand when a bowl constant in
# game/core/arena/arena_builder.gd changes, and the exporters read those
# constants out of that file, so the two cannot be edited apart.
#
# The ringside model is built here and not by hand because a committed asset
# with no reproducible build path is one nobody can safely change. It was
# added when floor_crowd.py already claimed this script built it.
#
# Two ways to get a Blender, in preference order:
#
#   1. A `blender` on PATH (any 4.x).
#   2. The `bpy` module in a Python 3.11 environment: `pip install bpy==4.2.0`.
#      Set BPY_PYTHON to that interpreter. This is what the container the
#      models were first built in had, and it produces a byte-identical export.
#
# Usage:
#   build_arena.sh                       # both, to their committed paths
#   build_arena.sh <bowl> [<crowd>]      # to somewhere else, e.g. a scratch dir
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
assets="$here/../../game/assets/environment"
bowl_out="${1:-$assets/arena_bowl.glb}"
crowd_out="${2:-$assets/floor_crowd.glb}"

# Resolved once and reused, so the two models cannot be built by different
# Blenders in one run -- which would make only one of them byte-reproducible.
if command -v blender >/dev/null 2>&1; then
    run() { blender --background --python "$1" -- --out "$2"; }
else
    python_bin="${BPY_PYTHON:-python3}"
    if ! "$python_bin" -c "import bpy" >/dev/null 2>&1; then
        echo "build_arena.sh: no 'blender' on PATH and '$python_bin' has no bpy module." >&2
        echo "  Install one: pip install bpy==4.2.0  (needs Python 3.11)" >&2
        exit 1
    fi
    run() { "$python_bin" "$1" --out "$2"; }
fi

run "$here/arena_bowl.py" "$bowl_out"
run "$here/floor_crowd.py" "$crowd_out"
