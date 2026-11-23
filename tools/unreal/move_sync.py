"""Export and verify the versioned move bundle shared with the Unreal port."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

from export_move_clips import paired_clips, strike_clips

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
FILES = ("move_defs.json", "move_clips.json", "paired_trajectories.json", "wrestling_clips.glb")
PRIORITY_MOVES = ("snap_dragon_suplex_3", "finisher_cross_rhodes", "mexican_destroyer",
                  "running_grapple_inverted_drop")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256(path):
    with path.open("rb") as payload:
        return hashlib.file_digest(payload, "sha256").hexdigest()


def glb_clips(path):
    with path.open("rb") as payload:
        magic, version, size, json_size, kind = struct.unpack("<4sIII4s", payload.read(20))
        if (magic, version, size, kind) != (b"glTF", 2, path.stat().st_size, b"JSON"):
            raise ValueError(f"Invalid animation GLB: {path}")
        names = [clip["name"] for clip in json.loads(payload.read(json_size))["animations"]]
        if len(set(names)) != len(names):
            raise ValueError("Animation GLB has duplicate clip names")
        return set(names)


def verify_bundle(bundle):
    manifest = read_json(bundle / "manifest.json")
    if manifest["schema_version"] != 1 or set(manifest["files"]) != set(FILES):
        raise ValueError("Unsupported move bundle format")
    for name in FILES:
        if sha256(bundle / name) != manifest["files"][name]:
            raise ValueError(f"Move bundle hash mismatch: {name}")
    return manifest


def validate_joins(definitions, clips, trajectories):
    for move, row in definitions.items():
        clip = clips.get(row["animation_pair_id"]) or clips.get(move)
        if not clip or clip["kind"] != "paired":
            continue
        pair = trajectories["moves"].get(move)
        if pair not in trajectories["trajectories"]:
            raise ValueError(f"No exported trajectory for paired move {move}")


def export(bundle, godot):
    resources = REPO / "game/resources"
    bundle.mkdir(parents=True, exist_ok=True)
    (bundle / "manifest.json").unlink(missing_ok=True)
    # The exporter needs only MoveDefs and animation data. A small Godot
    # project avoids importing the arena or loading the game's autoloads in CI.
    with tempfile.TemporaryDirectory() as scratch:
        project = Path(scratch)
        (project / "project.godot").write_text("config_version=5\n", encoding="utf-8")
        target = project / "resources"
        (target / "animations").mkdir(parents=True)
        shutil.copytree(resources / "moves", target / "moves", ignore=shutil.ignore_patterns("*.uid"))
        shutil.copy2(resources / "move_def.gd", target)
        for name in ("paired_moves.tres", "paired_recipes.gd"):
            shutil.copy2(resources / "animations" / name, target / "animations")
        script = "export_paired_trajectories.gd"
        shutil.copy2(HERE / script, project)
        subprocess.run([godot, "--headless", "--path", str(project), "--script",
                        f"res://{script}", "--",
                        str(bundle / "paired_trajectories.json"),
                        str(bundle / "move_defs.json")], check=True, env={
                            **os.environ, "XDG_DATA_HOME": str(project / "data"),
                            "XDG_CACHE_HOME": str(project / "cache"),
                            "XDG_CONFIG_HOME": str(project / "config"),
                        })
    paired = paired_clips()
    clips = {**strike_clips(), **paired}
    write_json(bundle / "move_clips.json", clips)
    shutil.copy2(REPO / "game/assets/animations/wrestling_clips.glb", bundle / "wrestling_clips.glb")
    available = glb_clips(bundle / "wrestling_clips.glb")
    trajectories = read_json(bundle / "paired_trajectories.json")
    definitions = read_json(bundle / "move_defs.json")["move_defs"]
    validate_joins(definitions, clips, trajectories)
    for pair, roles in paired.items():
        if pair not in trajectories["trajectories"]:
            raise ValueError(f"Missing paired trajectory: {pair}")
        for role in ("attacker", "defender"):
            if roles[role] not in available:
                raise ValueError(f"Missing Blender clip for {pair}: {roles[role]}")
    required = set()
    for move in PRIORITY_MOVES:
        pair = definitions[move]["animation_pair_id"]
        roles = paired[pair]
        if trajectories["moves"].get(move) != pair:
            raise ValueError(f"Missing trajectory mapping for {move}")
        required.update((roles["attacker"], roles["defender"]))

    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    dirty = subprocess.check_output(
        ["git", "status", "--porcelain", "--", "game", "tools/unreal"], cwd=REPO, text=True)
    write_json(bundle / "manifest.json", {
        "schema_version": 1,
        "source_commit": commit,
        "source_dirty": bool(dirty),
        "files": {name: sha256(bundle / name) for name in FILES},
        "required_unreal_source_clips": sorted(required),
    })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--godot", default="godot")
    snapshot = parser.add_mutually_exclusive_group()
    snapshot.add_argument("--check-snapshot", action="store_true")
    snapshot.add_argument("--update-snapshot", action="store_true")
    args = parser.parse_args()
    bundle = args.output.resolve()
    if bundle == HERE:
        parser.error("Choose a bundle directory outside tools/unreal itself.")
    export(bundle, args.godot)
    verify_bundle(bundle)
    generated = bundle / "paired_trajectories.json"
    checked_in = HERE / generated.name
    if args.update_snapshot:
        shutil.copyfile(generated, checked_in)
    if args.check_snapshot and read_json(checked_in) != read_json(generated):
        parser.exit(1, "Unreal trajectory snapshot is stale. Re-run move_sync.py with --update-snapshot.\n")


if __name__ == "__main__":
    main()
