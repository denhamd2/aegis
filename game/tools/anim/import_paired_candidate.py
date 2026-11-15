#!/usr/bin/env python3
"""Import a scoped Blender GLB with production settings, away from the game cache.

Pass the printed .scn to build_paired_poses.gd through AEGIS_AUTHORED_PATH.
Raw GLTFDocument.generate_scene() omits the scene importer's key optimizer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    source = args.glb.resolve(strict=True)
    game = Path(__file__).resolve().parents[2]
    template = game / "assets/animations/wrestling_clips.glb.import"
    root = Path(tempfile.mkdtemp(prefix="aegis-paired-import-"))
    (root / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Aegis scoped animation import"\n'
    )
    shutil.copy2(source, root / "wrestling_clips.glb")
    # Keeping the source basename also keeps importer root naming identical.
    (root / "wrestling_clips.glb.import").write_text(
        template.read_text().replace(
            "res://assets/animations/wrestling_clips.glb", "res://wrestling_clips.glb"
        )
    )
    with (root / "import.log").open("w") as log:
        subprocess.run(
            [args.godot, "--headless", "--path", str(root), "--editor", "--import"],
            stdout=log, stderr=subprocess.STDOUT, check=True,
        )
    scenes = list((root / ".godot/imported").glob("wrestling_clips.glb-*.scn"))
    if len(scenes) != 1:
        raise RuntimeError(f"Expected one imported scene; inspect {root / 'import.log'}")
    manifest = {
        "source": str(source),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "import_template_sha256": hashlib.sha256(template.read_bytes()).hexdigest(),
        "godot": subprocess.check_output([args.godot, "--version"], text=True).strip(),
        "scene": str(scenes[0]),
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(scenes[0])


if __name__ == "__main__":
    main()
