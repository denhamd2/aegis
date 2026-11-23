"""Export which animation clip(s) each MoveDef plays, for the Unreal port.

Run from a shell (plain Python 3, no Godot or Unreal needed):
    python3 tools/unreal/export_move_clips.py > /tmp/aegis_move_clips.json

The Godot game resolves a move to its clips through two tables:
  - game/resources/animations/paired_recipes.gd  RECIPES[id]["authored"]
    gives the attacker/defender clip pair for every two-man move;
  - game/resources/animations/strike_recipes.gd  RECIPES[id]["source"] (and
    "seconds", its retimed length) gives the single clip for a strike.
Those are the source of truth; this script only reads them. A move in
neither table falls back to a clip whose name starts with the move id
(e.g. chain_headlock -> Chain_Headlock_Attacker), the way the FF library
was named on import.

Output: a JSON object keyed by move id (the MoveDef animation_pair_id):
    {"power_bodyslam": {"kind": "paired", "attacker": "Bodyslam_Attacker",
                        "defender": "Bodyslam_Defender", "seconds": 0.0}, ...}
Unreal's import script (tools/unreal/build_move_table.py) joins this onto
the MoveDefs DataTable. Output is sorted, so it diffs cleanly.
"""
import json
import os
import re
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ANIM = os.path.join(REPO, "game", "resources", "animations")


def _top_level_entries(src: str, const: str) -> dict:
    """Return {key: body} for each one-tab-indented entry of `const X := {`."""
    start = src.index("const %s := {" % const)
    end = src.find("\nconst ", start + 1)
    body = src[start:end if end != -1 else len(src)]
    out = {}
    # an entry starts at '\t"key": ' and runs to the next one (or the end)
    keys = list(re.finditer(r'^\t"([a-z0-9_]+)":', body, re.M))
    for i, m in enumerate(keys):
        stop = keys[i + 1].start() if i + 1 < len(keys) else len(body)
        out[m.group(1)] = body[m.end():stop]
    return out


def paired_clips() -> dict:
    src = open(os.path.join(ANIM, "paired_recipes.gd")).read()
    out = {}
    for move, body in _top_level_entries(src, "RECIPES").items():
        m = re.search(r'"authored":\s*\{\s*"attacker":\s*"([^"]+)",\s*"defender":\s*"([^"]+)"', body)
        if m:
            out[move] = {"kind": "paired", "attacker": m.group(1),
                         "defender": m.group(2), "seconds": 0.0}
    return out


def strike_clips() -> dict:
    src = open(os.path.join(ANIM, "strike_recipes.gd")).read()
    out = {}
    for move, body in _top_level_entries(src, "RECIPES").items():
        m = re.search(r'"source":\s*"([^"]+)"', body)
        if not m:
            continue
        s = re.search(r'"seconds":\s*([0-9.]+)', body)
        out[move] = {"kind": "strike", "attacker": m.group(1), "defender": "",
                     "seconds": float(s.group(1)) if s else 0.0}
    return out


def move_clips() -> dict:
    clips = strike_clips()
    # DiveSpot plays these two clips from the presentation library. Expose
    # them under the MoveDef ID so Unreal can resolve both roles together.
    clips["dive_springboard_cutter"] = {
        "kind": "aerial",
        "attacker": clips["springboard_cutter_attacker"]["attacker"],
        "defender": clips["springboard_cutter_defender"]["attacker"],
        "seconds": clips["springboard_cutter_attacker"]["seconds"],
    }
    clips.update(paired_clips())
    return clips


def main() -> None:
    json.dump(dict(sorted(move_clips().items())), sys.stdout, indent=1)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
