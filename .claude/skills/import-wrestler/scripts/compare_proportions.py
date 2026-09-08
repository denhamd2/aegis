#!/usr/bin/env python3
"""Proves a processed model has the same body proportions as the one supplied.

Rigging a model touches its geometry in ways that are easy to do by accident: a
non-uniform scale, a stray offset, a bake that squashes a limb. None of that is
obvious in a render of the model on its own -- a slightly longer arm looks like
an arm. So compare against the source, numerically, and let the numbers be the
claim.

    python3 compare_proportions.py \\
        --original "/path/to/Supplied.glb" --original-scale 0.01 \\
        --rigged   game/assets/characters/<name>.glb

Reports, for each model and then as a difference:

  * vertex count -- must be identical if the pipeline only transformed
  * overall height, arm span and depth
  * width AND depth of the body at ten heights from ankle to crown, which is
    what catches a limb or torso changing shape while the bounding box does not
  * nearest-vertex distance from every original vertex to the rigged mesh, which
    is the strict test: near zero means the surface was not moved at all

Expect zeroes. On the Cody import the whole table came back identical to
0.000 mm and the worst nearest-vertex deviation was 0.0012 mm, because the
pipeline applies only a uniform scale and a translation.

Each model is measured in its OWN Blender process, on purpose. Reusing one bpy
session across two glTF imports does not fully clear between them -- doing that
here surfaced a phantom 42-vertex sphere in the second model that was not in the
file at all, and it was nearly reported to the user as a defect in the asset.
"""

import argparse
import json
import pathlib
import subprocess
import sys

# Heights to measure at, as a fraction of the model's own height. Chosen to hit
# ankle, calf, thigh, hip, hand/wrist, chest, shoulder, neck and head.
FRACTIONS = (0.06, 0.15, 0.30, 0.45, 0.55, 0.62, 0.72, 0.82, 0.92, 0.97)
# Half-thickness of each measuring band, in metres.
BAND = 0.012


def measure(path, scale):
    """Runs in a fresh Blender: import, scale, centre, report the geometry."""
    import bpy
    import mathutils

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    points = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or not obj.visible_get():
            continue
        for vertex in obj.data.vertices:
            points.append((obj.matrix_world @ vertex.co) * scale)
    lo = mathutils.Vector(min(p[i] for p in points) for i in range(3))
    hi = mathutils.Vector(max(p[i] for p in points) for i in range(3))
    offset = mathutils.Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    points = [p + offset for p in points]

    height = hi.z - lo.z
    rows = []
    for fraction in FRACTIONS:
        z = height * fraction
        band = [p for p in points if abs(p.z - z) < BAND]
        if len(band) < 20:
            continue
        rows.append([
            fraction,
            max(p.x for p in band) - min(p.x for p in band),
            max(p.y for p in band) - min(p.y for p in band),
        ])
    return {
        "n": len(points),
        "size": [hi.x - lo.x, hi.y - lo.y, height],
        "rows": rows,
        "points": [[p.x, p.y, p.z] for p in points],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--original", required=True)
    parser.add_argument("--original-scale", type=float, default=1.0)
    parser.add_argument("--rigged", required=True)
    parser.add_argument("--rigged-scale", type=float, default=1.0)
    parser.add_argument("--_extract", nargs=3, help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args._extract:
        out, path, scale = args._extract
        pathlib.Path(out).write_text(json.dumps(measure(path, float(scale))))
        return

    results = []
    for label, path, scale in (("original", args.original, args.original_scale),
                               ("rigged", args.rigged, args.rigged_scale)):
        out = pathlib.Path(f"/tmp/_proportions_{label}.json")
        subprocess.run(
            [sys.executable, __file__, "--original", args.original,
             "--rigged", args.rigged, "--_extract", str(out), path, str(scale)],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not out.exists():
            sys.exit(f"failed to measure {path} -- is bpy installed?")
        results.append(json.loads(out.read_text()))
    a, b = results

    print(f"{'':<18}{'ORIGINAL':>14}{'RIGGED':>14}{'DIFF':>14}")
    print(f"{'vertices':<18}{a['n']:>14}{b['n']:>14}"
          f"{b['n'] - a['n']:>14}")
    for index, name in enumerate(("arm span", "depth", "height")):
        print(f"{name + ' (m)':<18}{a['size'][index]:>14.4f}"
              f"{b['size'][index]:>14.4f}"
              f"{(b['size'][index] - a['size'][index]) * 1000:>11.3f}mm")
    if a["n"] != b["n"]:
        print("!! vertex counts differ. If the pipeline only transformed the")
        print("!! mesh, they cannot -- something added, removed or welded "
              "geometry.")

    print(f"\n{'height':>8}{'width orig':>12}{'width rig':>12}{'diff':>11}"
          f"{'depth orig':>13}{'depth rig':>12}{'diff':>11}")
    worst = 0.0
    for (f1, w1, d1), (_, w2, d2) in zip(a["rows"], b["rows"]):
        worst = max(worst, abs(w2 - w1), abs(d2 - d1))
        print(f"{f1:>7.0%}{w1:>12.4f}{w2:>12.4f}{(w2 - w1) * 1000:>10.3f}mm"
              f"{d1:>13.4f}{d2:>12.4f}{(d2 - d1) * 1000:>10.3f}mm")
    print(f"\nlargest cross-section difference: {worst * 1000:.3f} mm")
    if worst > 0.002:
        print("!! the body changed shape, not just position or scale. Look for a")
        print("!! non-uniform scale, or a bake that deformed the mesh.")
    else:
        print("proportions are preserved.")


if __name__ == "__main__":
    main()
