#!/usr/bin/env python3
"""Reads a .glb/.gltf header and answers the questions that decide the whole job.

Run this FIRST, before importing anything into Godot. It parses the file's own
JSON chunk and takes about a second, where a Godot import of a 100 MB model takes
minutes -- and the single most important question it answers, "is this thing even
rigged", changes what the next several hours look like.

    python3 gltf_triage.py "/path/to/Model.glb"

What it reports, and why each matters:

  RIGGED          A model with no `skins` array and no JOINTS_0/WEIGHTS_0 vertex
                  attributes is a statue. It can be rendered and cannot be posed,
                  retargeted or animated. The Cody Rhodes asset was one, and
                  nothing in the game could use it until it was rigged. This is
                  the go/no-go for Phase 0.5.

  UNITS           A human-sized model measuring ~180 is in centimetres. Convert
                  at import (or at rig time via --scale), never with a scale on
                  the scene node.

  IMAGES          Embedded (bufferView) or external (uri). Archives often ship a
                  `textures/` folder that duplicates images already embedded in
                  the .glb -- committing both wastes tens of megabytes for
                  nothing. This says which you have.

  MATERIALS       Which have no base colour, and which point base colour at a map
                  whose name suggests packed data (`*_rai`, `*_orm`, `*_mask`).
                  Confirm the latter with inspect_textures.py; as albedo they
                  render magenta.

  SIZE            Against GitHub's 100 MB per-file hard limit, which a supplied
                  model can exceed on its textures alone.

Reads the file directly and does no transform maths of its own beyond reporting
raw accessor bounds -- see the note under EXTENTS.
"""

import json
import pathlib
import struct
import sys

# Names that suggest a texture carries packed data rather than colour.
PACKED_HINTS = ("_rai", "_orm", "_mask", "_arm", "_rma", "_data", "_pack")
# GitHub refuses any file at or above this, so a .glb must land under it.
GITHUB_LIMIT_BYTES = 100 * 1024 * 1024


def read_gltf_json(path):
    with open(path, "rb") as handle:
        magic = handle.read(4)
        if magic == b"glTF":
            handle.seek(0)
            _, _, _ = struct.unpack("<III", handle.read(12))
            length, kind = struct.unpack("<II", handle.read(8))
            return json.loads(handle.read(length))
        handle.seek(0)
        return json.load(handle)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = pathlib.Path(sys.argv[1])
    doc = read_gltf_json(path)
    size = path.stat().st_size

    print(f"\n=== {path.name} ===")
    print(f"generator: {doc.get('asset', {}).get('generator')}")
    print(f"file size: {size / 1e6:.1f} MB")
    if size >= GITHUB_LIMIT_BYTES:
        print("!! over GitHub's 100 MB per-file hard limit -- it cannot be")
        print("!! committed as-is. Cap the textures (rig_static_wrestler.py")
        print("!! --max-texture), exempting any atlas carrying logo or text art.")

    # --- rigged? --------------------------------------------------------------
    attributes = set()
    triangles = 0
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            attributes |= set(primitive["attributes"])
            if "indices" in primitive:
                triangles += doc["accessors"][primitive["indices"]]["count"] // 3
    skins = doc.get("skins", [])
    skinned = any(a.startswith("JOINTS") for a in attributes)
    print(f"\nRIGGED: {'yes' if (skins and skinned) else 'NO'}")
    print(f"  skins={len(skins)}  animations={len(doc.get('animations', []))}"
          f"  meshes={len(doc.get('meshes', []))}  triangles={triangles}")
    print(f"  vertex attributes: {sorted(attributes)}")
    if skins:
        for index, skin in enumerate(skins):
            print(f"  skin {index}: {skin.get('name')!r}, "
                  f"{len(skin.get('joints', []))} joints")
    if not (skins and skinned):
        print("!! THIS IS A STATUE: no skeleton and no skin weights. It cannot be")
        print("!! posed, retargeted or animated as supplied. Go to Phase 0.5 and")
        print("!! ask the user how they want it rigged before doing anything else.")
    if not doc.get("animations"):
        print("  no animations of its own -- clips come from the base rig")

    # --- units ----------------------------------------------------------------
    # Deliberately the raw union of accessor min/max, with NO node transforms
    # applied. Composing glTF node transforms by hand is a good way to produce a
    # confident wrong answer: doing exactly that on this asset double-counted a
    # node translation and reported a detached mesh 1.2 m from the body that did
    # not exist. Use Blender or Godot when a real world-space number is needed;
    # this figure is only here to tell centimetres from metres, which it can.
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
            if "min" not in accessor:
                continue
            for axis in range(3):
                lo[axis] = min(lo[axis], accessor["min"][axis])
                hi[axis] = max(hi[axis], accessor["max"][axis])
    if lo[0] != float("inf"):
        span = [hi[axis] - lo[axis] for axis in range(3)]
        tallest = max(span)
        print(f"\nEXTENTS (untransformed, for units only): "
              f"{span[0]:.2f} x {span[1]:.2f} x {span[2]:.2f}")
        if 1.4 < tallest < 2.4:
            print("  units look like METRES -- use --scale 1.0")
        elif 140 < tallest < 240:
            print("  units look like CENTIMETRES -- use --scale 0.01")
        else:
            print(f"!! longest axis is {tallest:.2f}; neither metres nor "
                  "centimetres. Check the export scale before importing.")

    # --- images ---------------------------------------------------------------
    images = doc.get("images", [])
    embedded = sum(1 for i in images if i.get("bufferView") is not None)
    print(f"\nIMAGES: {len(images)} ({embedded} embedded, "
          f"{len(images) - embedded} external)")
    if embedded == len(images) and images:
        print("  all embedded -- a sibling textures/ folder in the archive is a")
        print("  duplicate and should NOT be committed alongside the .glb")

    # --- materials ------------------------------------------------------------
    print(f"\nMATERIALS: {len(doc.get('materials', []))}")
    missing = []
    packed = []
    for material in doc.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        base = pbr.get("baseColorTexture", {}).get("index")
        name = material.get("name", "(unnamed)")
        if base is None:
            missing.append(name)
            continue
        source = doc["textures"][base].get("source")
        image_name = images[source].get("name", "") if source is not None else ""
        if any(hint in image_name.lower() for hint in PACKED_HINTS):
            packed.append(f"{name} -> {image_name}")
    if missing:
        print(f"!! {len(missing)} with NO base colour: {', '.join(missing)}")
        print("!!   each needs a reconnected texture, a flat tint, or hiding.")
        print("!!   Check for an unreferenced image before inventing a colour:")
        print(f"!!   {len(images)} images embedded against "
              f"{len(doc.get('textures', []))} textures referenced.")
    if packed:
        print(f"!! {len(packed)} pointing base colour at a packed data map:")
        for entry in packed:
            print(f"!!   {entry}")
        print("!!   confirm with inspect_textures.py; as albedo these render "
              "magenta.")
    if not missing and not packed:
        print("  every material has its own base colour and none looks like a")
        print("  packed data map -- no material repair pass needed.")


if __name__ == "__main__":
    main()
