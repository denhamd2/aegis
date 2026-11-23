"""Verify a move bundle and update the Unreal port's two move tables.

Run as a script in the Unreal editor. Set AEGIS_MOVE_SYNC_BUNDLE to the
unpacked bundle directory. Use SYNC_BUNDLE and SOURCE_ANIM_DIR globals
when invoking through the editor's Python bridge.
"""
import json
import os
from pathlib import Path
import runpy
import sys

import unreal

HERE = Path(__file__).resolve().parent
DEFAULT_ANIM_DIR = "/Game/AegisTest/AllRig/wrestler_base_with_clips/SkeletalMeshes"


def sync(bundle, source_anim_dir):
    sys.path.insert(0, str(HERE))
    try:
        from move_sync import read_json, validate_joins, verify_bundle
    finally:
        sys.path.pop(0)

    manifest = verify_bundle(bundle)
    registry = unreal.AssetRegistryHelpers.get_asset_registry()
    available = {
        str(asset.asset_name) for asset in registry.get_assets_by_path(source_anim_dir, recursive=True)
        if str(asset.asset_class_path.asset_name) == "AnimSequence"
    }
    required = set(manifest["required_unreal_source_clips"])
    missing = sorted(required - available)
    if missing:
        raise RuntimeError(f"Import the bundle's source animations first. Missing: {', '.join(missing)}")

    # Check joins before writing either asset. The same clip-map lookup and
    # keys drive the two table builders.
    definitions = read_json(bundle / "move_defs.json")["move_defs"]
    clips = read_json(bundle / "move_clips.json")
    trajectories = read_json(bundle / "paired_trajectories.json")
    validate_joins(definitions, clips, trajectories)

    moves = runpy.run_path(str(HERE / "build_move_table.py"),
                           init_globals={"SYNC_BUNDLE": bundle})["result"]
    paired = runpy.run_path(str(HERE / "build_trajectory_table.py"), init_globals={
        "JSON_PATH": str(bundle / "paired_trajectories.json"),
        "STRICT_TRAJECTORIES": True,
    })["result"]
    return {
        "source_commit": manifest["source_commit"],
        "source_dirty": manifest["source_dirty"],
        "bundle_files": manifest["files"],
        "move_table": moves,
        "trajectory_table": paired,
        "source_clip_names_verified": sorted(required),
    }


def main():
    directory = globals().get("SYNC_BUNDLE") or os.environ.get("AEGIS_MOVE_SYNC_BUNDLE")
    if not directory:
        raise RuntimeError("Set AEGIS_MOVE_SYNC_BUNDLE to the unpacked move bundle directory")
    bundle = Path(directory).resolve()
    receipt = bundle / "unreal-import-receipt.json"
    # A failed refresh must not leave a receipt that describes an earlier import.
    receipt.unlink(missing_ok=True)
    result = sync(bundle, globals().get("SOURCE_ANIM_DIR", DEFAULT_ANIM_DIR))
    temp = receipt.with_suffix(".tmp")
    temp.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temp.replace(receipt)
    unreal.log(f"Imported Aegis move tables from {result['source_commit']}; receipt: {receipt}")


if __name__ == "__main__":
    main()
