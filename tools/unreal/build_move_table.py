"""Build /Game/AegisTest/Data/DT_AegisMoves in the Unreal port from the Godot MoveDefs.

Run inside the Unreal Editor of the port project (UE 5.9, needs the C++ row
struct FAegisMoveRow compiled into the MyProject2 module):
    Tools > Execute Python Script...  ->  pick this file
or send it through the editor's MCP execute_python tool.

Inputs, both already the Godot game's own data:
  - /Game/AegisTest/Data/MoveDefs, the MoveDef .tres values imported earlier
    (one row per move, Godot field names: startup_frames, damage_head, ...)
  - tools/unreal/export_move_clips.py, which reads paired_recipes.gd and
    strike_recipes.gd for each move's clip(s)
The output table is what AAegisWrestlerCharacter reads. Re-running replaces
every row, so the table always equals Godot's current data.
"""
import importlib.util
import json
import os
from pathlib import Path

import unreal

REPO = os.environ.get("AEGIS_REPO", os.path.expanduser("~/code/aegis"))
SOURCE_TABLE = "/Game/AegisTest/Data/MoveDefs"
OUT_DIR = "/Game/AegisTest/Data"
OUT_NAME = "DT_AegisMoves"
SYNC_BUNDLE = globals().get("SYNC_BUNDLE")


def build():
    if SYNC_BUNDLE:
        bundle = Path(SYNC_BUNDLE)
        clips = json.loads((bundle / "move_clips.json").read_text(encoding="utf-8"))
        definitions = json.loads((bundle / "move_defs.json").read_text(encoding="utf-8"))
        rows = [{"Name": name, **row} for name, row in definitions["move_defs"].items()]
    else:
        path = os.path.join(REPO, "tools", "unreal", "export_move_clips.py")
        spec = importlib.util.spec_from_file_location("export_move_clips", path)
        clips_mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(clips_mod)
        clips = {**clips_mod.strike_clips(), **clips_mod.paired_clips()}
        src = unreal.load_asset(SOURCE_TABLE)
        rows = json.loads(unreal.DataTableFunctionLibrary.export_data_table_to_json_string(src))
    out_rows = []
    unmapped = []
    for r in sorted(rows, key=lambda r: r["Name"]):
        pair = str(r.get("animation_pair_id") or r["Name"])
        c = clips.get(pair) or clips.get(r["Name"])
        if not c:
            unmapped.append(r["Name"])
            c = {"kind": "", "attacker": "", "defender": "", "seconds": 0.0}
        out_rows.append({
            "Name": r["Name"],
            "Kind": c["kind"],
            "Group": r.get("group", ""),
            "AttackerClip": c["attacker"],
            "DefenderClip": c["defender"],
            "ClipSeconds": c["seconds"],
            "StartupFrames": r.get("startup_frames", 0),
            "ActiveFrames": r.get("active_frames", 0),
            "RecoveryFrames": r.get("recovery_frames", 0),
            "TotalFrames": r.get("total_frames", 0),
            "ReversalWindowStart": r.get("reversal_window_start", 0),
            "ReversalWindowEnd": r.get("reversal_window_end", 0),
            "DamageHead": r.get("damage_head", 0),
            "DamageTorso": r.get("damage_torso", 0),
            "DamageArms": r.get("damage_arms", 0),
            "DamageLegs": r.get("damage_legs", 0),
            "MomentumCost": r.get("momentum_cost", 0),
            "MomentumGain": r.get("momentum_gain", 0),
            "bLeavesDefenderDown": bool(r.get("leaves_defender_down", False)),
        })

    path = OUT_DIR + "/" + OUT_NAME
    table = unreal.load_asset(path) if unreal.EditorAssetLibrary.does_asset_exist(path) else None
    if table is None:
        factory = unreal.DataTableFactory()
        factory.set_editor_property("struct", unreal.AegisMoveRow.static_struct())
        table = unreal.AssetToolsHelpers.get_asset_tools().create_asset(
            OUT_NAME, OUT_DIR, unreal.DataTable, factory)
    ok = unreal.DataTableFunctionLibrary.fill_data_table_from_json_string(table, json.dumps(out_rows))
    expected = {r["Name"].lower() for r in out_rows}
    actual = {str(name).lower() for name in
              unreal.DataTableFunctionLibrary.get_data_table_row_names(table)}
    if not ok or actual != expected or not unreal.EditorAssetLibrary.save_loaded_asset(table):
        raise RuntimeError(f"Move table import failed: {path}")
    return {"ok": ok, "rows": len(out_rows), "unmapped": unmapped}


result = build()
json.dumps(result)
