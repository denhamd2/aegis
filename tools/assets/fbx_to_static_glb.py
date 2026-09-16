#!/usr/bin/env python3
"""Turns a supplied FBX character scan into a clean static .glb for rigging.

`rig_static_wrestler.py` is the tool that gives a statue the base rig's
skeleton, but it cannot read this class of asset directly: its `import_gltf()`
calls `bpy.ops.import_scene.gltf`, so it accepts only .glb/.gltf. This script is
the step in front of it, and it exists because the Kenny Omega asset arrived as
none of the things that pipeline assumes.

## What the supplied asset actually is, measured

A binary FBX 7700 inside two nested zips, plus a 4096-square diffuse and a
4096-square normal map. Parsed with bpy:

  * no armature, no vertex groups, no animations -- a STATUE, so Phase 0.5 of
    the import skill applies and it must be rigged before anything can pose it;
  * ONE mesh, 285,913 vertices / 571,794 triangles -- 7.7x the Cody asset;
  * watertight: 0 non-manifold edges and 0 boundary edges, with 99.86% of the
    vertices in a single connected shell. That is unusually healthy, and the
    opposite of the Cody asset's 224 shells and 6251 non-manifold edges;
  * 7 loose fragments totalling 402 vertices -- scan specks that render as
    flecks floating beside the body;
  * UPSIDE DOWN: the head sits at -Z after the FBX import's own axis fix;
  * 0.176 units tall, i.e. a 17.6 cm action figure, not a character in metres;
  * ONE material, base colour and normal both properly wired, so there is no
    material repair pass to do here at all.

In short: a photogrammetry scan of a physical action figure. Three of those
facts -- FBX, inverted, and the triangle count -- are what this script fixes;
the scale is left to `rig_static_wrestler.py --scale`, deliberately, so that its
own "is this a human height" assertion still has something to check.

## Why the decimation target is not the obvious one

The Cody asset ships at 74k triangles and looks right, so 74k is the tempting
target. It is the wrong one here, because the two assets' UV layouts are not
comparable. A photogrammetry atlas is thousands of tiny UV islands, and every
island boundary is a UV seam; the COLLAPSE decimator smears texture wherever it
merges across one. A conventional hand-authored atlas has a few dozen seams and
tolerates far heavier decimation.

So the default is 150k, which is a STARTING GUESS and not a searched minimum --
it is roughly a quarter of the supplied geometry, which leaves the small islands
mostly intact. The number that is actually correct is whichever survives a
side-by-side close-up render against the undecimated mesh; `--target-tris 0`
skips decimation entirely so that comparison can be rendered.

File size is not what is driving this. At 150k triangles with 2048-square
textures the rigged .glb lands around 20 MB, comfortably under GitHub's 100 MB
per-file limit. Render cost and UV damage are the real constraints.

## Usage

    python3 tools/assets/fbx_to_static_glb.py \\
        --input  /path/to/model.fbx \\
        --output /tmp/kenny_static.glb \\
        --target-tris 150000 \\
        --report /tmp/kenny_prep.txt

Every measurement it makes is printed, including the body's width and depth at
ten heights from ankle to crown before and after decimation. Those ten pairs are
the check that decimation changed the silhouette by nothing that matters; a
COLLAPSE decimation that only removes redundant detail cannot move them, and one
that has started eating the shape will.
"""

import argparse
import math
import sys

# `bpy` must be imported before `bmesh` and `mathutils`: as a pip-installed
# module it is what registers them, and importing bmesh first fails outright.
import bpy  # isort: skip
import bmesh  # noqa: E402  isort: skip
import mathutils  # noqa: E402  isort: skip


def log(report, message):
    print(message, flush=True)
    report.append(message)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bounds(obj):
    """World-space min/max over the real vertices.

    Deliberately not `obj.bound_box`, which is cached and can still hold the
    pre-transform box right after an import -- reading it here reported this
    model as a roughly cubic object, which is nothing like its true shape.
    """
    lo = mathutils.Vector((1e18, 1e18, 1e18))
    hi = mathutils.Vector((-1e18, -1e18, -1e18))
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        for axis in range(3):
            lo[axis] = min(lo[axis], world[axis])
            hi[axis] = max(hi[axis], world[axis])
    return lo, hi


def silhouette(obj, samples=10):
    """Width (X) and depth (Y) in a thin slab at each of `samples` heights.

    The same measurement `compare_proportions.py` makes, done here so the
    decimation can be judged in the same terms before the mesh goes anywhere
    near the rigger.
    """
    lo, hi = bounds(obj)
    height = hi.z - lo.z
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    rows = []
    for index in range(samples):
        # Sample between 5% and 95% so the slabs sit on the body rather than on
        # the single lowest vertex of a boot or the topmost strand of hair.
        fraction = 0.05 + 0.90 * index / (samples - 1)
        centre = lo.z + height * fraction
        half = height * 0.02
        slab = [p for p in points if abs(p.z - centre) <= half]
        if not slab:
            rows.append((fraction, 0.0, 0.0))
            continue
        width = max(p.x for p in slab) - min(p.x for p in slab)
        depth = max(p.y for p in slab) - min(p.y for p in slab)
        rows.append((fraction, width, depth))
    return rows


def report_silhouette(report, label, rows):
    log(report, f"  {label}:")
    for fraction, width, depth in rows:
        log(report, f"    h={fraction * 100:5.1f}%  width={width:.5f}"
                    f"  depth={depth:.5f}")


def measure_yaw(obj):
    """The yaw of the character's own shoulder-to-hand line, in radians.

    Read as the principal axis of the upper body projected onto XY. With the
    arms spread, they dominate that spread by a wide margin -- the hands sit
    about three times further from the spine than the torso is wide -- so the
    principal axis IS the arm line, and no landmark detection is needed.

    This exists because the supplied scan does not stand square to the world:
    measured on the Kenny asset, its arm line runs 44 degrees off X while the
    base rig's runs exactly along it (hand_l at +0.739, hand_r at -0.739, with
    identical Y and Z). That difference is not cosmetic. `rig_static_wrestler.py`
    fits the arms by rotating each upperarm to aim at the measured hand, so the
    arms partly absorb the error, but nothing rotates the spine or the legs --
    they keep the base rig's facing while the mesh's legs are turned away. The
    result was calf_l 12.6 cm and foot_l 23.9 cm OUTSIDE the mesh, with the
    right side fine, from this one cause.
    """
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo_z = min(p.z for p in points)
    hi_z = max(p.z for p in points)
    height = hi_z - lo_z
    # Above 60%: shoulders, arms and head. The arms carry the spread.
    upper = [p for p in points if (p.z - lo_z) > 0.60 * height]
    if len(upper) < 16:
        raise SystemExit("too few upper-body vertices to measure yaw")
    mean_x = sum(p.x for p in upper) / len(upper)
    mean_y = sum(p.y for p in upper) / len(upper)
    a = b = c = 0.0
    for p in upper:
        dx = p.x - mean_x
        dy = p.y - mean_y
        a += dx * dx
        b += dx * dy
        c += dy * dy
    # Principal axis of the 2x2 covariance [[a, b], [b, c]].
    return 0.5 * math.atan2(2.0 * b, a - c)


def measure_facing(obj):
    """+1 if the feet point along +Y, -1 if along -Y.

    A yaw measured off the arm line is only defined up to 180 degrees -- the
    same line describes a character facing either way -- so the ambiguity is
    resolved from an independent part of the body. The feet are the reliable
    one: a foot is much longer in front of the ankle than behind it, so the
    toes reach further from the foot's own centre than the heel does.

    The face would be the obvious alternative and is a worse choice here: this
    scan's hair is a solid blob that overhangs the face, so the head's extreme
    point is not reliably the nose.
    """
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo_z = min(p.z for p in points)
    height = max(p.z for p in points) - lo_z
    feet = [p for p in points if (p.z - lo_z) < 0.12 * height]
    if len(feet) < 16:
        raise SystemExit("too few foot vertices to measure facing")
    mean_y = sum(p.y for p in feet) / len(feet)
    forward = max(p.y for p in feet) - mean_y
    backward = mean_y - min(p.y for p in feet)
    return 1.0 if forward > backward else -1.0


def square_to_axes(report, obj, override=None):
    """Yaw the model so its arms lie along X and its toes point -Y.

    That is the base rig's own frame, measured from the rig rather than assumed:
    its hands sit at +/-0.739 X with equal Y and Z, and its ball (toe) bones sit
    0.149 m behind its foot (ankle) bones in Y on both sides, i.e. it faces -Y.

    Handedness needs no separate correction. Everything applied to the mesh here
    is a rotation, which cannot mirror it, and for a figure facing -Y with +Z up
    the anatomical left necessarily falls on +X -- which is where the rig's
    hand_l is.
    """
    if override is not None:
        yaw = math.radians(override)
        log(report, f"yaw: using the supplied override {override:.2f} degrees")
    else:
        yaw = measure_yaw(obj)
        log(report, f"yaw: measured arm line at {math.degrees(yaw):+.2f} degrees "
                    f"off X")
    obj.matrix_world = mathutils.Matrix.Rotation(-yaw, 4, "Z") @ obj.matrix_world
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    facing = measure_facing(obj)
    log(report, f"facing: toes point along {'+Y' if facing > 0 else '-Y'}")
    if facing > 0:
        obj.matrix_world = (mathutils.Matrix.Rotation(math.pi, 4, "Z")
                            @ obj.matrix_world)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        log(report, "  turned 180 degrees so the toes point -Y, as the rig's do")

    # Report the result in the same terms the rig is measured in, so the two can
    # be compared directly rather than taken on trust.
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo_z = min(p.z for p in points)
    height = max(p.z for p in points) - lo_z
    upper = [p for p in points if (p.z - lo_z) > 0.60 * height]
    left = max(upper, key=lambda p: p.x)
    right = min(upper, key=lambda p: p.x)
    log(report, f"  hand at +X: {tuple(round(v, 4) for v in left)}")
    log(report, f"  hand at -X: {tuple(round(v, 4) for v in right)}")
    span = left - right
    log(report, f"  arm line now {math.degrees(math.atan2(span.y, span.x)):+.2f} "
                f"degrees off X (want ~0), hand height difference "
                f"{abs(left.z - right.z) / height * 100:.1f}% of body")


def drop_loose_fragments(report, obj):
    """Keep only the largest connected shell.

    The supplied scan carries 7 extra shells of 402 vertices between them --
    photogrammetry noise that renders as specks hanging in the air next to the
    body. They are removed by connectivity rather than by a size threshold on
    bounding boxes, so nothing that is actually attached to the character can be
    caught by it.
    """
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    mesh.verts.ensure_lookup_table()

    seen = set()
    shells = []
    for vertex in mesh.verts:
        if vertex.index in seen:
            continue
        stack = [vertex]
        seen.add(vertex.index)
        component = []
        while stack:
            current = stack.pop()
            component.append(current)
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        shells.append(component)

    shells.sort(key=len, reverse=True)
    log(report, f"  connected shells: {len(shells)}"
                f"  sizes={[len(s) for s in shells[:8]]}")
    if len(shells) > 1:
        doomed = [v for shell in shells[1:] for v in shell]
        log(report, f"  dropping {len(shells) - 1} loose fragment(s), "
                    f"{len(doomed)} vertices")
        bmesh.ops.delete(mesh, geom=doomed, context="VERTS")
        mesh.to_mesh(obj.data)
        obj.data.update()
    mesh.free()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="the supplied .fbx")
    parser.add_argument("--output", required=True, help="static .glb to write")
    parser.add_argument("--target-tris", type=int, default=150000,
                        help="decimate to about this many triangles; 0 to skip "
                             "decimation entirely (used to render the "
                             "undecimated comparison)")
    parser.add_argument("--yaw", type=float, default=None,
                        help="degrees to yaw the model, overriding the measured "
                             "arm-line angle; use when the automatic read is "
                             "wrong (a pose with the arms down gives it nothing "
                             "to measure)")
    parser.add_argument("--report", default=None, help="write the log here too")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:]
                             if "--" in sys.argv else None)

    report = []
    reset()

    bpy.ops.import_scene.fbx(filepath=args.input)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        sys.exit("no mesh in the FBX")
    if len(meshes) > 1:
        select_only = meshes[0]
        bpy.ops.object.select_all(action="DESELECT")
        for mesh in meshes:
            mesh.select_set(True)
        bpy.context.view_layer.objects.active = select_only
        bpy.ops.object.join()
    body = [o for o in bpy.data.objects if o.type == "MESH"][0]
    body.name = "Body"

    if any(o.type == "ARMATURE" for o in bpy.data.objects):
        sys.exit("this FBX has an armature -- it is not a statue, and this "
                 "script is the wrong tool for it")

    log(report, f"imported {args.input}")
    log(report, f"  {len(body.data.vertices)} vertices, "
                f"{len(body.data.polygons)} faces")
    log(report, f"  materials: {[m.name for m in body.data.materials]}")
    log(report, f"  uv layers: {[u.name for u in body.data.uv_layers]}")

    # Bake the FBX importer's own axis conversion in before measuring anything,
    # so every number below is in the space the .glb will ship in.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    lo, hi = bounds(body)
    log(report, f"  bounds min={tuple(round(v, 4) for v in lo)}")
    log(report, f"  bounds max={tuple(round(v, 4) for v in hi)}")
    log(report, f"  height (Z) {hi.z - lo.z:.4f}")

    # --- orientation ---------------------------------------------------------
    # The supplied scan stands on its head: measured, the head sits at -Z and
    # the boots at +Z. Every downstream stage assumes +Z up (the rigger fits the
    # base rig's bones by height, so an inverted mesh would put the pelvis bone
    # in the skull), so this is fixed here, once, rather than cancelled out by a
    # rotation on a node somewhere in the scene tree.
    body.matrix_world = (mathutils.Matrix.Rotation(math.pi, 4, "X")
                         @ body.matrix_world)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    lo, hi = bounds(body)
    log(report, "flipped 180 degrees about X (the scan is supplied inverted)")
    log(report, f"  bounds min={tuple(round(v, 4) for v in lo)}")
    log(report, f"  bounds max={tuple(round(v, 4) for v in hi)}")

    # --- square the model to the base rig's frame ----------------------------
    # Before any centring, because the yaw is about the world Z axis and the
    # centring below is what puts the body on that axis.
    square_to_axes(report, body, args.yaw)

    lo, hi = bounds(body)

    # Sit the model on Z=0 and centre it in X/Y. The rigger measures against its
    # own base rig, which stands on the floor at the origin.
    body.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    lo, hi = bounds(body)
    log(report, f"  rested on Z=0, centred in XY; min={tuple(round(v, 4) for v in lo)}")

    drop_loose_fragments(report, body)
    log(report, f"  after fragment removal: {len(body.data.vertices)} vertices, "
                f"{len(body.data.polygons)} faces")

    before_rows = silhouette(body)
    report_silhouette(report, "silhouette before decimation", before_rows)

    # --- decimation ----------------------------------------------------------
    faces = len(body.data.polygons)
    if args.target_tris and faces > args.target_tris:
        ratio = args.target_tris / faces
        log(report, f"decimating {faces} -> ~{args.target_tris} faces "
                    f"(ratio {ratio:.4f})")
        modifier = body.modifiers.new("Decimate", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = ratio
        # Without this the decimator is free to collapse across a UV island
        # boundary, which on a photogrammetry atlas of thousands of tiny islands
        # is the whole ballgame -- it smears texture rather than losing detail.
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="Decimate")
        log(report, f"  after decimation: {len(body.data.vertices)} vertices, "
                    f"{len(body.data.polygons)} faces")
    else:
        log(report, f"no decimation ({faces} faces, target {args.target_tris})")

    after_rows = silhouette(body)
    report_silhouette(report, "silhouette after decimation", after_rows)

    log(report, "silhouette drift (after - before), as a fraction of width:")
    worst = 0.0
    for (fraction, w0, d0), (_, w1, d1) in zip(before_rows, after_rows):
        dw = (w1 - w0) / w0 if w0 else 0.0
        dd = (d1 - d0) / d0 if d0 else 0.0
        worst = max(worst, abs(dw), abs(dd))
        log(report, f"    h={fraction * 100:5.1f}%  dwidth={dw * 100:+6.2f}%"
                    f"  ddepth={dd * 100:+6.2f}%")
    log(report, f"  worst silhouette drift: {worst * 100:.2f}%")

    # Pack the images so the exporter embeds pixels rather than paths: the FBX
    # references its two maps as sibling .jpg files, which would not survive the
    # .glb moving anywhere.
    for image in bpy.data.images:
        if image.source == "FILE" and not image.packed_file:
            try:
                image.pack()
                log(report, f"  packed image {image.name} {tuple(image.size)}")
            except RuntimeError as error:
                log(report, f"!! could not pack {image.name}: {error}")

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=args.output,
        export_format="GLB",
        use_selection=True,
        # Nothing to skin or animate yet -- that is the rigger's job, and this
        # file is only its input.
        export_skins=False,
        export_animations=False,
        export_yup=True,
    )
    log(report, f"wrote {args.output}")

    if args.report:
        with open(args.report, "w") as handle:
            handle.write("\n".join(report) + "\n")


if __name__ == "__main__":
    main()
