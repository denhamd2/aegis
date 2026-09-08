#!/usr/bin/env python3
"""Rigs a static (unskinned) character mesh onto the project's base wrestler rig.

Some supplied models are statues: a posed mesh with no skeleton, no skin weights
and no animations. The Cody Rhodes model is one -- 14 meshes, 74k triangles, no
`skins` array, no JOINTS_0/WEIGHTS_0 attribute anywhere. Nothing in the game can
pose it.

This script gives such a mesh the base rig's own skeleton, so that afterwards it
needs NO bone map and NO animation retarget: the bones it ends up with are the
same bones, with the same names and the same rest pose, as
`wrestler_base.glb`. Every existing animation library -- the .glb's 43 clips, the
generated paired poses, the imported strike clips -- then applies verbatim. That
is the whole point of doing it this way rather than auto-rigging to a foreign
skeleton and retargeting: it skips the single most defect-prone phase of an
import.

## How it works, and why in this order

The obstacle is that the base rig rests in a T-pose and the supplied mesh is
usually in an A-pose. Weights cannot be bound across that difference -- a T-posed
arm bone runs through empty air beside an A-posed arm.

Nor can the armature's rest pose simply be changed to match, which is the
tempting shortcut. A bone track stores a rotation relative to its own skeleton's
rest pose, so an armature resting in an A-pose plays every T-pose-authored clip
wrongly -- the same class of fault as a bad retarget, arriving by a different
road.

The weights themselves come from the base rig's own mannequin rather than from
bone-heat ("automatic weights"). Bone-heat needs a closed volume and fails
outright on a supplied model, which is typically a dozen separate shells --
body, clothing, boots, hair, eyes, mouth parts -- with open boundaries where
they meet. Measured on the Cody mesh: 6251 non-manifold edges of 114445, and
bone-heat weighted 0 of 40448 vertices while reporting only a warning. The
mannequin, by contrast, is already skinned to these exact bones by whoever
authored the rig, so its weights are better than anything derived here, and
transferring them by nearest surface is robust to open shells.

So:

  1. Measure the supplied mesh's arm direction, shoulder to hand.
  2. Pose the base rig into that A-pose and snapshot its mannequin, deformed.
     The mannequin now stands in the supplied mesh's pose, carrying its weights.
     The base rig's own pose is then reset; its rest was never touched.
  3. Transfer vertex weights from that snapshot onto the supplied mesh by
     nearest surface. Both are in the same pose, so the mapping is meaningful.
  4. Bind the mesh to a COPY of the armature whose rest has been set to the
     A-pose, using the weights from step 3 rather than recomputing any, and
     export that.

The supplied geometry is never deformed. An earlier version did bake it back
into the base rig's T-pose so that no retarget would be needed downstream; see
the long comment at the end of main() for the measurements that killed that
idea. The exported skeleton therefore has the base rig's bone NAMES and
HIERARCHY but its own A-pose REST, and the loader must convert clips through
rest space.

## Usage

    python3 tools/assets/rig_static_wrestler.py \\
        --input  "/path/to/Cody Rhodes.glb" \\
        --base   game/assets/characters/wrestler_base.glb \\
        --output game/assets/characters/cody_rhodes.glb \\
        --scale  0.01 \\
        --report /tmp/rig_report.txt

`--scale` converts the source's units to metres; the audit probe prints the
height it read, and a figure near 180 means centimetres. The script prints the
resulting height so the conversion can be checked rather than assumed.

Requires `bpy` (`pip install bpy==4.2.0`), which runs Blender headless as a
Python module -- no Blender install needed.
"""

import argparse
import math
import sys

try:
    import bpy
    import mathutils
except ImportError:
    sys.exit("bpy is required: pip install bpy==4.2.0")


# Limbs whose direction is measured off the mesh and fitted. The legs and head
# are deliberately absent: measured on this asset they sit within 5 degrees of
# the base rig's rest, and rotating a bone chain by five degrees to chase noise
# costs accuracy in the weights rather than gaining any.
ARM_CHAINS = [("upperarm_l", 1.0), ("upperarm_r", -1.0)]

# Fraction of the model's half-width beyond which a vertex is arm rather than
# body. Half-width is the arm span, so this is "the outer half of the reach".
ARM_CUT_FRACTION = 0.5

# Last bone of each arm chain, whose tail is the rig's fingertip. Used to
# compare the rig's reach against the mesh's.
ARM_TIP = {"upperarm_l": "hand_l", "upperarm_r": "hand_r"}

# Share of the arm's vertices, furthest from the shoulder, averaged to locate
# the hand. Small enough to be hand rather than forearm, large enough that no
# single stray vertex decides the fit.
HAND_CLOUD_FRACTION = 0.08

# How far the mesh's reach may differ from the rig's before the fit is unsound.
REACH_TOLERANCE = 0.08

# Bones whose distance to the mesh is checked after fitting. Bone-heat weighting
# fails outright when a bone lies outside the surface it should drive, and it
# reports that failure as a bare exception, so the check happens first and says
# which bone is the problem.
FIT_CHECK_BONES = [
    "upperarm_l", "lowerarm_l", "hand_l",
    "upperarm_r", "lowerarm_r", "hand_r",
    "thigh_l", "calf_l", "foot_l", "spine_03", "Head",
]
# Weight smoothing after the transfer, and it is not optional. Rendered
# comparison at the T-pose bake: with 0 passes the deltoids and pecs tear open
# in ragged sheets, because neighbouring vertices sample quite different parts
# of the mannequin and a sharp weight disagreement is a tear the moment the
# 61-degree arm rotation is applied. 6 passes closes it with no visible loss of
# definition anywhere else.
WEIGHT_SMOOTH_PASSES = 6
WEIGHT_SMOOTH_FACTOR = 0.5

# Radius within which vertices on different shells are treated as one surface
# for weighting, and how many times to average. 8 mm is wider than any seam gap
# on this asset and narrower than the distance between anatomically different
# parts, so a chest seam blends and the lips do not blend into the teeth.
SEAM_WELD_RADIUS_M = 0.008
SEAM_WELD_PASSES = 2

# Vertices further than this from the mannequin's surface get no useful weight
# from the transfer and are reported. Hair, boot soles and mouth interiors sit
# outside the mannequin's silhouette and are expected to appear here.
TRANSFER_MAX_DISTANCE_M = 0.25

# How far a bone may sit from the nearest vertex before the fit is called bad.
# Generous, because a bone should be *inside* the limb and the nearest surface
# vertex is then half a limb's thickness away.
FIT_TOLERANCE_M = 0.12


def log(report, message):
    print(message)
    report.append(message)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def principal_axis(points):
    """Dominant direction of a point cloud, by power iteration on its covariance.

    Used to read a limb's direction straight off the geometry. A limb is far
    longer than it is thick, so its dominant axis is its bone line -- which is
    exactly what needs matching, and it needs no joint-centre estimation.
    """
    count = len(points)
    centre = mathutils.Vector((
        sum(p.x for p in points) / count,
        sum(p.y for p in points) / count,
        sum(p.z for p in points) / count,
    ))
    covariance = [[0.0] * 3 for _ in range(3)]
    for point in points:
        d = point - centre
        for i in range(3):
            for k in range(3):
                covariance[i][k] += d[i] * d[k]
    matrix = mathutils.Matrix(covariance)
    axis = mathutils.Vector((1.0, 1.0, 1.0)).normalized()
    for _ in range(200):
        axis = (matrix @ axis).normalized()
    if axis.z > 0:
        axis = -axis  # always point down the limb, away from the shoulder
    return centre, axis


def rotate_pose_bone_to(armature, bone_name, target_direction):
    """Rotate a pose bone about its head so its axis points along `target`.

    Children follow, which is what makes one rotation per arm enough: the whole
    chain swings as a unit, the way an arm lowered from a T-pose actually moves.
    """
    pose_bone = armature.pose.bones[bone_name]
    head = armature.matrix_world @ pose_bone.head
    tail = armature.matrix_world @ pose_bone.tail
    current = (tail - head).normalized()
    target = target_direction.normalized()
    rotation = current.rotation_difference(target).to_matrix().to_4x4()
    about_head = (mathutils.Matrix.Translation(head)
                  @ rotation
                  @ mathutils.Matrix.Translation(-head))
    pose_bone.matrix = armature.matrix_world.inverted() @ about_head \
        @ armature.matrix_world @ pose_bone.matrix
    bpy.context.view_layer.update()
    return math.degrees(current.angle(target))


def weld_seam_weights(body, report, radius, passes):
    """Average skin weights across mesh-shell boundaries, by distance.

    A supplied model is a set of separate shells -- torso, arms, trousers,
    boots, hair -- that abut without sharing vertices. Measured on the Cody
    mesh: 224 connected shells, and 5275 of its 40448 vertices lie within a
    millimetre of a *different* shell.

    That matters because every weighting method here is per-vertex: two
    vertices a hair apart, one on the chest shell and one on the arm shell, can
    receive quite different weights. The moment the shoulder rotates they move
    differently and the seam opens -- rendered, a dark crack running around the
    deltoid, which reads as a hole in the character rather than as a weighting
    artefact.

    Blender's own weight smoothing travels along EDGES, so it cannot cross a
    seam that has no edge across it, and no number of passes will. This walks
    distance instead of topology, which is the only thing that reaches.

    Geometry is untouched; only weights change. Vertices are not merged, both
    because that would alter the supplied mesh and because it would weld
    surfaces that are meant to stay separate, such as the lips to the teeth.
    """
    mesh = body.data
    points = [v.co.copy() for v in mesh.vertices]
    tree = mathutils.kdtree.KDTree(len(points))
    for index, point in enumerate(points):
        tree.insert(point, index)
    tree.balance()

    # Shell id per vertex, by flood fill along edges.
    shell = [-1] * len(points)
    neighbours = [[] for _ in points]
    for edge in mesh.edges:
        a, b = edge.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    current = 0
    for start in range(len(points)):
        if shell[start] != -1:
            continue
        stack = [start]
        shell[start] = current
        while stack:
            here = stack.pop()
            for other in neighbours[here]:
                if shell[other] == -1:
                    shell[other] = current
                    stack.append(other)
        current += 1

    seam = [index for index, point in enumerate(points)
            if any(j != index and shell[j] != shell[index]
                   for (_, j, _) in tree.find_range(point, radius))]
    log(report, f"  {current} connected shells; {len(seam)} vertices lie within "
                f"{radius * 1000:.0f} mm of a different one")
    if not seam:
        return

    for _ in range(passes):
        weights = [{g.group: g.weight for g in mesh.vertices[i].groups}
                   for i in range(len(points))]
        updates = {}
        for index in seam:
            pool = [j for (_, j, _) in tree.find_range(points[index], radius)]
            totals = {}
            for j in pool:
                for group, weight in weights[j].items():
                    totals[group] = totals.get(group, 0.0) + weight
            total = sum(totals.values())
            if total <= 0.0:
                continue
            updates[index] = {g: w / total for g, w in totals.items() if w > 0.0}
        groups = list(body.vertex_groups)
        for index, blended in updates.items():
            for group in groups:
                group.remove([index])
            for group_index, weight in blended.items():
                groups[group_index].add([index], weight, "REPLACE")
    log(report, f"  welded {len(seam)} seam vertices over {passes} passes")


def select_only(obj):
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="the static .glb")
    parser.add_argument("--base", required=True, help="wrestler_base.glb")
    parser.add_argument("--output", required=True, help="rigged .glb to write")
    parser.add_argument("--scale", type=float, default=1.0,
                        help="multiply source units by this to reach metres")
    parser.add_argument("--report", default=None, help="write the log here too")
    parser.add_argument("--mapping", default="POLY_NEAREST",
                        help="comma-separated Blender vert_mapping passes for "
                             "the weight transfer, applied in order")
    parser.add_argument("--max-texture", type=int, default=0,
                        help="downscale any texture larger than this on a side; "
                             "0 leaves them alone. A supplied model often ships "
                             "4096-square atlases that put the .glb over "
                             "GitHub's 100 MB per-file hard limit")
    parser.add_argument("--diagnose", action="store_true",
                        help="report which vertices the T-pose bake distorts "
                             "and which bone drives them")
    parser.add_argument("--smooth", type=int, default=None,
                        help="weight smoothing passes (default "
                             f"{WEIGHT_SMOOTH_PASSES})")
    args = parser.parse_args()

    report = []
    reset()

    # --- the pristine base armature, kept aside and never posed ---------------
    base_objects = import_gltf(args.base)
    base_armature = next(o for o in base_objects if o.type == "ARMATURE")
    # Named "Armature" deliberately, and it matters. The generated animation
    # libraries -- paired_poses.tres, strike_clips.tres -- carry track paths of
    # the form "Armature/Skeleton3D:pelvis", resolved against the model's own
    # AnimationPlayer. Export this node under any other name and every one of
    # those tracks silently resolves to nothing: the wrestler plays the .glb's
    # own clips correctly and stands inert through every grapple and strike.
    base_armature.name = "Armature"
    # The mannequin is kept: it is the weight source. The stray icosphere the
    # base .glb also ships is not.
    base_meshes = [o for o in base_objects if o.type == "MESH"]
    mannequin = max(base_meshes, key=lambda o: len(o.data.vertices))
    for obj in base_meshes:
        if obj is not mannequin:
            bpy.data.objects.remove(obj, do_unlink=True)
    log(report, f"base rig: {len(base_armature.data.bones)} bones, "
                f"weight source '{mannequin.name}' "
                f"({len(mannequin.data.vertices)} vertices)")

    # --- the supplied mesh ---------------------------------------------------
    source_objects = import_gltf(args.input)
    source_meshes = [o for o in source_objects if o.type == "MESH"]
    if any(o.type == "ARMATURE" for o in source_objects):
        sys.exit("input already has an armature -- this script is for static "
                 "meshes; run the normal import instead")
    log(report, f"source: {len(source_meshes)} meshes, "
                f"{sum(len(m.data.vertices) for m in source_meshes)} vertices")

    # --- texture budget, before anything else touches the images -------------
    # Done here rather than just before export: Blender unloads image data it
    # is not currently using, and by export time `has_data` is False for these,
    # so a downscale placed there silently does nothing and the file ships at
    # full size.
    #
    # Worth doing at all because a supplied model is usually authored for a
    # renderer with no file-size limit. This one ships a 4096-square skin atlas
    # among twelve maps, which puts the .glb at 104 MB -- over GitHub's 100 MB
    # per-file hard limit, so it cannot be committed at all.
    if args.max_texture:
        for image in bpy.data.images:
            longest = max(image.size) if len(image.size) else 0
            if longest <= args.max_texture:
                continue
            factor = args.max_texture / longest
            was = tuple(image.size)
            image.scale(max(1, int(image.size[0] * factor)),
                        max(1, int(image.size[1] * factor)))
            image.pack()   # re-pack from the scaled pixels, not the original
            log(report, f"  texture {image.name}: {was[0]}x{was[1]} -> "
                        f"{image.size[0]}x{image.size[1]}")

    # One object, so there is one bind and one set of vertex groups. Material
    # slots survive the join and glTF re-splits them into primitives on export,
    # so nothing about the look changes.
    select_only(source_meshes[0])
    for mesh in source_meshes[1:]:
        mesh.select_set(True)
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Body"

    if args.scale != 1.0:
        body.scale = (args.scale,) * 3
        select_only(body)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    points = [body.matrix_world @ v.co for v in body.data.vertices]
    lo = mathutils.Vector((min(p[i] for p in points) for i in range(3)))
    hi = mathutils.Vector((max(p[i] for p in points) for i in range(3)))
    log(report, f"source height after scaling: {hi.z - lo.z:.3f} m "
                f"(base rig is 1.829 m)")
    if not 1.4 < (hi.z - lo.z) < 2.4:
        sys.exit(f"height {hi.z - lo.z:.2f} m is not human -- fix --scale")

    # Feet on the floor and centred, so the armature's own rest position lines
    # up without a per-model offset.
    body.location = (-(lo.x + hi.x) / 2.0, -(lo.y + hi.y) / 2.0, -lo.z)
    select_only(body)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # --- measure the arms ----------------------------------------------------
    points = [body.matrix_world @ v.co for v in body.data.vertices]
    # Isolate each arm by lateral reach alone. Measured on this asset the torso,
    # hips and boots all stay inside |x| = 0.20 while the arms run out to 0.52,
    # so a cut at ARM_CUT_FRACTION of the half-span takes the arm and nothing
    # else. An earlier version also filtered on height and ended up selecting
    # the whole side of the torso, whose principal axis is vertical -- it
    # reported the arms as pointing straight up, and the fit check below caught
    # it before anything was bound.
    arm_cut = ARM_CUT_FRACTION * (hi.x - lo.x) / 2.0
    axes = {}
    for bone_name, side in ARM_CHAINS:
        limb = [p for p in points if (p.x * side) > arm_cut]
        if len(limb) < 200:
            sys.exit(f"could not isolate {bone_name}: only {len(limb)} vertices "
                     f"beyond x={arm_cut:.3f} m")

        # Aim the chain from the rig's OWN shoulder at the mesh's hand, rather
        # than along the arm's principal axis. The principal axis is the arm
        # mass's line, and the mass includes the deltoid, which sits outboard of
        # the shoulder joint -- so a chain rotated to that direction but rooted
        # at the joint leaves the elbow and hand 15-20 cm outside the flesh.
        # Two points the geometry gives reliably are better than one direction
        # it gives approximately.
        shoulder = base_armature.matrix_world \
            @ base_armature.data.bones[bone_name].head_local
        far = sorted(limb, key=lambda p: (p - shoulder).length)
        hand_cloud = far[int(len(far) * (1.0 - HAND_CLOUD_FRACTION)):]
        hand = mathutils.Vector((
            sum(p.x for p in hand_cloud) / len(hand_cloud),
            sum(p.y for p in hand_cloud) / len(hand_cloud),
            sum(p.z for p in hand_cloud) / len(hand_cloud),
        ))
        reach = (hand - shoulder).length
        chain_length = (base_armature.matrix_world
                        @ base_armature.data.bones[ARM_TIP[bone_name]].tail_local
                        - shoulder).length
        axes[bone_name] = (hand - shoulder).normalized()
        log(report, f"{bone_name}: hand at ({hand.x:+.3f},{hand.y:+.3f},"
                    f"{hand.z:+.3f}) from {len(hand_cloud)} vertices; "
                    f"reach {reach:.3f} m vs rig chain {chain_length:.3f} m "
                    f"({100.0 * (reach / chain_length - 1.0):+.1f}%)")
        if abs(reach / chain_length - 1.0) > REACH_TOLERANCE:
            log(report, f"!! {bone_name}: the mesh's arm and the rig's arm differ "
                        f"in length by more than {REACH_TOLERANCE:.0%}. The hand "
                        f"bone will not reach the mesh's hand, so grip IK will "
                        f"aim at the wrong place. Proportions need matching.")

    # --- pose the base rig into that A-pose, and snapshot its mannequin ------
    # The mannequin is the weight source. Posing the base rig (its POSE, never
    # its rest) puts the mannequin in the supplied mesh's pose so that a
    # nearest-surface transfer maps like to like.
    select_only(base_armature)
    bpy.ops.object.mode_set(mode="POSE")
    for bone_name, _ in ARM_CHAINS:
        moved = rotate_pose_bone_to(base_armature, bone_name, axes[bone_name])
        log(report, f"{bone_name}: rotated {moved:.1f} deg to reach it")
    bpy.ops.object.mode_set(mode="OBJECT")

    select_only(mannequin)
    bpy.ops.object.duplicate()
    posed_mannequin = bpy.context.view_layer.objects.active
    posed_mannequin.name = "MannequinPosed"
    bpy.ops.object.convert(target="MESH")   # bakes the pose into the geometry
    log(report, f"weight source: mannequin posed to match, "
                f"{len(posed_mannequin.data.vertices)} vertices, "
                f"{len(posed_mannequin.vertex_groups)} vertex groups")

    # --- fit a COPY of the armature, and put the original back ---------------
    fitted = base_armature.copy()
    fitted.data = base_armature.data.copy()
    fitted.animation_data_clear()
    fitted.name = "FittedRig"
    bpy.context.collection.objects.link(fitted)
    select_only(fitted)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    log(report, "fitted rig: pose applied as rest")

    # The pristine rig goes back to its T-pose rest, untouched and unposed.
    select_only(base_armature)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.transforms_clear()
    bpy.ops.object.mode_set(mode="OBJECT")

    # --- is every bone actually inside the mesh? -----------------------------
    # Asked before binding: a bone outside the flesh it should drive produces
    # weights that look plausible in a table and tear the mesh on the first
    # frame of animation.
    tree = mathutils.kdtree.KDTree(len(points))
    for index, point in enumerate(points):
        tree.insert(point, index)
    tree.balance()
    worst = 0.0
    for bone_name in FIT_CHECK_BONES:
        bone = fitted.data.bones.get(bone_name)
        if bone is None:
            continue
        middle = fitted.matrix_world @ ((bone.head_local + bone.tail_local) / 2.0)
        _, _, distance = tree.find(middle)
        worst = max(worst, distance)
        flag = "  <-- OUTSIDE" if distance > FIT_TOLERANCE_M else ""
        log(report, f"  fit check {bone_name:<12} {distance * 100:5.1f} cm "
                    f"to nearest surface{flag}")
    if worst > FIT_TOLERANCE_M:
        log(report, "!! at least one bone sits outside the mesh; weights there "
                    "will be wrong. Adjust the fit before trusting the result.")

    # --- transfer the weights ------------------------------------------------
    for bone in base_armature.data.bones:
        if bone.use_deform and bone.name not in body.vertex_groups:
            body.vertex_groups.new(name=bone.name)
    # POLY_NEAREST, not POLYINTERP_VNORPROJ. Normal projection is the textbook
    # answer for a target bulkier than its source and it was tried and rendered:
    # it does fix the chest, whose vertices otherwise find the mannequin's ARM
    # as their nearest surface, but it destroys the limbs. An arm vertex's
    # normal points radially out of the arm, so its ray crosses open space and
    # lands on the torso or on nothing, and the arms come out as ragged sheets.
    # Nearest-surface plus the smoothing below is worse in theory at the armpit
    # and better everywhere it can be seen.
    #
    # Project along each vertex's own normal rather than taking the nearest
    # surface. The supplied wrestler is far bulkier than the mannequin, so a
    # nearest-surface lookup from a vertex on the outer chest lands on the
    # mannequin's ARM -- the chest then inherits arm weights, and rotating the
    # arm back to the T-pose tears the pecs and deltoids open. Rendered and
    # confirmed: nearest-surface produced jagged shoulder tearing that normal
    # projection does not, because a chest vertex's normal points out of the
    # chest and finds the mannequin's chest however far away it is.
    # Two passes, and both are needed.
    #
    # Nearest-surface first, because it always produces an answer: every vertex
    # ends up weighted, including ones the projection below cannot reach. A
    # vertex left with no weight at all does not merely deform badly, it stays
    # pinned at the origin while the rest of the body walks away.
    #
    # Normal projection second, overwriting wherever its ray actually lands.
    # Measured on this asset it reaches 39791 of 40448 vertices; the 657 it
    # misses -- hair strands, the inside of the mouth, surfaces whose normals
    # point into the body -- keep the first pass's weights.
    for mapping in [m for m in args.mapping.split(",") if m]:
        select_only(body)
        posed_mannequin.select_set(True)
        bpy.context.view_layer.objects.active = posed_mannequin
        bpy.ops.object.data_transfer(
            data_type="VGROUP_WEIGHTS",
            vert_mapping=mapping,
            layers_select_src="ALL",
            layers_select_dst="NAME",
            mix_mode="REPLACE",
        )

    # Smooth the weights before anything is baked with them. Transferred weights
    # are per-vertex samples of another mesh's weights, so neighbouring vertices
    # can land on quite different parts of the source and disagree sharply; a
    # sharp disagreement is a crease or a tear the moment the joint bends.
    smooth_passes = (WEIGHT_SMOOTH_PASSES if args.smooth is None else args.smooth)
    if smooth_passes:
        select_only(body)
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_smooth(
            group_select_mode="ALL",
            factor=WEIGHT_SMOOTH_FACTOR,
            repeat=smooth_passes,
        )
        bpy.ops.object.mode_set(mode="OBJECT")
        log(report, f"smoothed weights: {smooth_passes} passes at "
                    f"factor {WEIGHT_SMOOTH_FACTOR}")
    weighted = sum(1 for v in body.data.vertices if v.groups)
    log(report, f"transferred weights: {weighted}/{len(body.data.vertices)} "
                f"vertices carry at least one")
    if weighted < len(body.data.vertices) * 0.98:
        sys.exit("weight transfer left too many vertices unweighted; they would "
                 "stay pinned at the origin while the body moves")

    # How far each vertex had to reach for its weights. A vertex far outside the
    # mannequin's silhouette -- hair, a boot sole -- takes the nearest surface's
    # weights, which is right in kind but worth knowing the extent of.
    source_points = [posed_mannequin.matrix_world @ v.co
                     for v in posed_mannequin.data.vertices]
    source_tree = mathutils.kdtree.KDTree(len(source_points))
    for index, point in enumerate(source_points):
        source_tree.insert(point, index)
    source_tree.balance()
    far = 0
    for vertex in body.data.vertices:
        _, _, distance = source_tree.find(body.matrix_world @ vertex.co)
        if distance > TRANSFER_MAX_DISTANCE_M:
            far += 1
    log(report, f"  {far} vertices ({100.0 * far / len(body.data.vertices):.1f}%) "
                f"lie more than {TRANSFER_MAX_DISTANCE_M * 100:.0f} cm from the "
                f"mannequin and took their weights from its nearest surface")

    if SEAM_WELD_PASSES:
        weld_seam_weights(body, report, SEAM_WELD_RADIUS_M, SEAM_WELD_PASSES)

    # --- bind to the fitted rig, using those weights -------------------------
    select_only(body)
    fitted.select_set(True)
    bpy.context.view_layer.objects.active = fitted
    # Plain "Armature Deform": it must not recompute anything.
    bpy.ops.object.parent_set(type="ARMATURE")
    log(report, "bound to the fitted rig with the transferred weights")

    # --- finish -------------------------------------------------------------
    # The mesh is NOT baked back into the base rig's T-pose, and this is the
    # most important decision in the file.
    #
    # It was baked, at first: pose the fitted rig back to the T-pose, bake the
    # deformation into the geometry, and hand the result to the pristine base
    # armature, so the model would need no retarget at all. That works, and it
    # ruins the shoulders. The base rig's mannequin has a hard weight boundary
    # between clavicle and upperarm, so driving a 61-degree rotation through it
    # tears the deltoid open -- measured, 450 vertices on edges whose length
    # changed by more than 1.6x, split symmetrically between upperarm_l/r and
    # clavicle_l/r, and rendered, dark torn patches across both shoulders.
    # More weight smoothing does not touch it (6 passes: 450 vertices, 30
    # passes: 484), because the discontinuity is in the source weights and not
    # in how they were sampled.
    #
    # So the supplied geometry ships exactly as supplied, resting in its own
    # A-pose, and the rest-pose difference is resolved where it belongs: in the
    # animation retarget at load time, which this project already implements and
    # has proven on another model. The arm still bends at runtime, but as
    # ordinary skinning from a bind pose rather than as a permanent 61-degree
    # deformation baked into the vertices.
    #
    # The consequence for the caller: the exported skeleton's REST POSE is the
    # A-pose, not the base rig's. Its bone names and hierarchy are identical, so
    # a name map is not needed, but a rest-space conversion is. See the
    # import-wrestler skill's references/traps.md, section Retarget.
    bpy.data.objects.remove(posed_mannequin, do_unlink=True)
    bpy.data.objects.remove(mannequin, do_unlink=True)
    bpy.data.objects.remove(base_armature, do_unlink=True)

    # Named "Armature" because the generated animation libraries carry track
    # paths of the form "Armature/Skeleton3D:pelvis".
    fitted.name = "Armature"

    armature_modifiers = [m for m in body.modifiers if m.type == "ARMATURE"]
    if not armature_modifiers or armature_modifiers[0].object is not fitted:
        sys.exit("bind failed: the body has no armature modifier, so the export "
                 "would be unskinned")
    weighted = sum(1 for v in body.data.vertices if v.groups)
    log(report, f"armature modifier present; {weighted}/{len(body.data.vertices)} "
                f"vertices carry weights")
    if weighted < len(body.data.vertices):
        sys.exit("some vertices carry no weight; they would stay pinned at the "
                 "origin while the body moves")
    log(report, "rest pose is the supplied model's own A-pose -- the loader must "
                "retarget the base rig's clips through rest space")

    # --- export --------------------------------------------------------------
    # Select by hand rather than iterating view_layer.objects: after the
    # removals above that collection still yields stale None entries.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    fitted.select_set(True)
    bpy.context.view_layer.objects.active = fitted
    bpy.ops.export_scene.gltf(
        filepath=args.output,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        # The base rig's clips are authored against ITS rest pose, and this
        # skeleton rests in the A-pose, so shipping them here would ship 42
        # wrong clips. They are retargeted at load time instead.
        export_animations=False,
        export_yup=True,
    )
    log(report, f"wrote {args.output}")

    if args.report:
        with open(args.report, "w") as handle:
            handle.write("\n".join(report) + "\n")


if __name__ == "__main__":
    main()
