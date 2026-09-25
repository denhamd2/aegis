#!/usr/bin/env bash
# Rebuild the venue's committed .glb models from tools/blender/.
#
# Usage:
#   tools/blender/build_venue.sh            # every model
#   tools/blender/build_venue.sh ring       # bowl ring entrance ringside rig
#
# Blender is not a build dependency of the game -- the .glb files are
# committed and CI never runs this. It is run by hand when a shared constant
# in game/core/arena/arena_builder.gd or game/core/ring/ring_builder.gd
# changes, and each exporter reads those constants out of the GDScript, so the
# two cannot be edited apart.
#
# AFTER running this, reimport before baking or testing:
#
#     godot4 --headless --import
#
# `godot4 --headless -s <script>` does NOT reimport a changed asset first, so
# anything that reads the model through res:// keeps seeing the previous
# import until that step runs.
#
# Two ways to get a Blender, in preference order:
#   1. A `blender` on PATH (any 4.x).
#   2. The `bpy` module in a Python 3.11 environment: `pip install bpy==4.2.0`.
#      Set BPY_PYTHON to that interpreter.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${1:-all}"

run() {
    local script="$here/$1"
    if command -v blender >/dev/null 2>&1; then
        blender --background --python "$script" --
    else
        local python_bin="${BPY_PYTHON:-python3}"
        if ! "$python_bin" -c "import bpy" >/dev/null 2>&1; then
            echo "build_venue.sh: no 'blender' on PATH and '$python_bin' has no bpy." >&2
            echo "  Install one: pip install bpy==4.2.0  (needs Python 3.11)" >&2
            exit 1
        fi
        "$python_bin" "$script"
    fi
}

case "$target" in
    bowl)     run arena_bowl.py ;;
    ring)     run ring.py ;;
    entrance) run entrance_set.py ;;
    ringside) run ringside.py ;;
    rig)      run overhead_rig.py ;;
    all)      run arena_bowl.py; run ring.py; run entrance_set.py; run ringside.py; run overhead_rig.py ;;
    *) echo "build_venue.sh: unknown target '$target'" >&2; exit 2 ;;
esac
