"""Build the Unreal port's paired-move trajectory table from Godot's export.

Reads tools/unreal/paired_trajectories.json (export_paired_trajectories.gd)
and writes /Game/AegisTest/Data/DT_AegisPairedTrajectories, one
FAegisPairedTrajectory row per paired move in DT_AegisMoves, row name = the
move id. UAegisGrappleRig looks a move up by that id.

A move's trajectory is its MoveDef's animation_pair_id ("moves" in the JSON),
else the trajectory of the same name, else "ff_" + the name: the Fight Forever
MoveDefs live in moves/ff/ (outside the export's "moves"), and their pair ids
carry the ff_ prefix their row names drop.

Also tags the RingTest canvas "AegisCanvas", which the rig reads for the
ring's centre (the ROPE_SAFE and RING_HALF_EXTENT clamps).

Run inside the UE 5.9 editor of the port project (editor MCP execute_python).
Optional global, set before the script body:
    JSON_PATH = "/abs/path/to/paired_trajectories.json"
"""
import json
import os

import unreal

JSON_PATH = globals().get(
    "JSON_PATH", os.path.expanduser("~/code/aegis/tools/unreal/paired_trajectories.json"))
MOVES = "/Game/AegisTest/Data/DT_AegisMoves"
DEST_DIR = "/Game/AegisTest/Data"
DEST_NAME = "DT_AegisPairedTrajectories"
CANVAS_LABEL = "Aegis_Canvas"
CANVAS_TAG = "AegisCanvas"

with open(JSON_PATH, encoding="utf-8") as f:
    doc = json.load(f)
trajectories = doc["trajectories"]
pair_of = doc["moves"]

moves = unreal.EditorAssetLibrary.load_asset(MOVES)
kinds = unreal.DataTableFunctionLibrary.get_data_table_column_as_string(moves, "Kind")
names = [str(n) for n in unreal.DataTableFunctionLibrary.get_data_table_row_names(moves)]

rows, missing = [], []
for name, kind in zip(names, kinds):
    if kind != "paired":
        continue
    pair = pair_of.get(name) or (name if name in trajectories else "ff_" + name)
    t = trajectories.get(pair)
    if t is None:
        missing.append(name)
        continue
    rows.append({
        "Name": name,
        "PairId": pair,
        "Length": t["length"],
        "Ticks": t["ticks"],
        "Attacker": [v for key in t["attacker"] for v in key],
        "Defender": [v for key in t["defender"] for v in key],
    })
rows.sort(key=lambda r: r["Name"])
if globals().get("STRICT_TRAJECTORIES") and missing:
    raise RuntimeError(f"Missing paired trajectories for {', '.join(missing)}")

path = DEST_DIR + "/" + DEST_NAME
table = unreal.EditorAssetLibrary.load_asset(path) if unreal.EditorAssetLibrary.does_asset_exist(path) else None
if table is None:
    factory = unreal.DataTableFactory()
    factory.set_editor_property("struct", unreal.AegisPairedTrajectory.static_struct())
    table = unreal.AssetToolsHelpers.get_asset_tools().create_asset(DEST_NAME, DEST_DIR, unreal.DataTable, factory)
ok = unreal.DataTableFunctionLibrary.fill_data_table_from_json_string(table, json.dumps(rows))
expected = {row["Name"].lower() for row in rows}
actual = {str(name).lower() for name in unreal.DataTableFunctionLibrary.get_data_table_row_names(table)}
if not ok or actual != expected or not unreal.EditorAssetLibrary.save_loaded_asset(table):
    raise RuntimeError(f"Paired trajectory table import failed: {path}")

tagged = False
eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
for actor in eas.get_all_level_actors():
    if actor.get_actor_label() == CANVAS_LABEL:
        tags = list(actor.tags)
        if CANVAS_TAG not in [str(t) for t in tags]:
            tags.append(unreal.Name(CANVAS_TAG))
            actor.set_editor_property("tags", tags)
            unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).save_current_level()
        tagged = True

result = {"filled": ok, "rows": len(rows), "missing": missing, "canvas_tagged": tagged}
json.dumps(result)
