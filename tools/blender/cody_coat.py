#!/usr/bin/env python3
"""Cody Rhodes's entrance coat, built on his own body and skinned to his rig.

Reference: the owner's photograph of him walking out in it (see
game/assets/characters/CREDITS.md). A long white coat to mid-shin with red
panels, gold studded trim edged in blue piping, red sleeves banded in gold,
gold scale epaulettes on both shoulders, a high collar, worn open down the
chest.

Run:  python3 tools/blender/cody_coat.py
Writes game/assets/characters/cody_coat.glb and its textures
(cody_coat_body.png, cody_coat_sleeve.png, cody_coat_orm_*.png).

How it is made, and why:

* The TORSO AND SLEEVES start from his own body surface: every face of the
  body mesh whose vertices ride the spine, clavicles and arms (not the
  hands, neck or head) is copied -- so the coat deforms exactly as he does.
  The copy is then SMOOTHED (it bridges the pec, ab and spine hollows, as
  cloth does), stood off OFFSET, and pushed out wherever it still comes
  within CLEAR of him. Skin pushed out 16 mm, the first version, read as a
  painted bodysuit in the owner's video.
* It has THICKNESS (Solidify, THICK inward): an edge at the opening, the hem
  and the cuffs, and a lining on the inside (material slot 1).
* WEIGHTS are his own skinning, carried by the copied faces -- the sleeves
  bend with his elbows. The SKIRT is not a copy of anything (a coat does not
  have legs): it starts on the jacket's own outline, rounds over his seat
  (measured off the body -- see measure_hips for the 12 cm the first one was
  off) and falls nearly straight, in folds, to mid-shin, with side vents
  from mid-thigh. Mostly weighted to the pelvis, the front panels partly to
  their own thigh, so it hangs and swings rather than dragging like a
  trouser leg.
* The coat is OPEN down the front in a V, to the waist, as in the photo, the
  cut edge straightened and turned back into LAPELS.
* UVs are cylindrical in each part's own frame (round the body / round the
  arm, and up), and the textures are painted to that layout below, with a
  twill-and-folds normal map and a mottled roughness.

Deterministic: same inputs, byte-identical .glb and textures.
"""

from __future__ import annotations

import math
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import bmesh  # noqa: E402
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "game/assets/characters/cody_rhodes.glb"
OUT = REPO / "game/assets/characters/cody_coat.glb"
TEX = REPO / "game/assets/characters"

## Bones whose skin becomes coat (the dominant weight of a vertex).
COAT_BONES = {"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r",
              "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "pelvis"}
ARM_BONES = {"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"}
## The sleeve starts this far out from his centre line (his shoulder joints
## are at +-0.19).
SLEEVE_FROM_X = 0.215
## Cloth over skin. The first coat was his skin pushed out 16 mm and read as
## a painted bodysuit in the owner's video: it followed every pec and ab
## groove. Now the copied skin is SMOOTHED first (a shell bridges hollows;
## cloth does not dip into them), then stood off OFFSET, then pushed out
## wherever it still comes closer than CLEAR to the body.
OFFSET = 0.022
CLEAR = 0.016
SMOOTH_ITERS = 40
## Cloth thickness (Solidify, inward): an edge at the opening, the hem and
## the cuffs, and a darker lining seen inside.
THICK = 0.005
WAIST_Z = 1.0             # the torso part stops here; the skirt starts
HEM_Z = 0.30              # mid-shin
## The front opening, a V: half-width at the waist and at the collar.
OPEN_WAIST = 0.035
OPEN_TOP = 0.11
OPEN_TOP_Z = 1.47
## The skirt: hip ellipse at the waist, flaring to the hem.
## Half-widths (across, front-to-back) at the waist, over the seat, and at
## the hem. The first skirt went straight from the waist to a 0.31 m hem
## and stood off his legs like a lampshade from the side; a coat falls over
## the seat and then nearly straight down, the vents giving the stride room.
##
## And it was centred 2 cm behind the origin, which is 12 cm IN FRONT of his
## hips: the body mesh's hips sit at y 0.14 (the glTF bind space, not the
## armature's rest), so the front hung a hand's width off his thighs and the
## back ran inside his seat. Now measured off the body at build time
## (measure_hips): centred on his seat, SKIRT_EASE outside it at the waist
## and the seat, flaring by HEM_FLARE to the hem.
SEAT_Z = 0.86
SKIRT_EASE = (0.03, 0.032)
## The skirt starts this far above WAIST_Z, over the jacket's bottom edge,
## so no gap opens between them as he moves -- and over the band round his
## hips where the body's skin is carried by the thighs and so never became
## jacket. The painted sash sits on this seam.
SKIRT_OVERLAP = 0.10
HEM_FLARE = (0.035, 0.03)
SKIRT_FRONT_GAP = math.radians(16)  # half-angle of the open front
SKIRT_RINGS = 20
SKIRT_SEGMENTS = 64
## Side vents from mid-thigh down, so each stride opens the skirt rather
## than pushing a knee through it: half-angle round his side, and the top.
VENT_HALF = math.radians(11)
VENT_TOP_Z = 0.78
## Folds: radial ripples growing toward the hem, so it hangs as cloth.
FOLDS = 9
FOLD_AMP = 0.018
## The most a skirt vertex follows a thigh: the front panels swing with
## their leg, the back tail barely -- it hangs from the hips.
FRONT_LEG = 0.45
BACK_LEG = 0.15
## The lapels: the opening's edge turned back over the chest, narrow at the
## waist and widest at the collar.
LAPEL_WAIST = 0.018
LAPEL_TOP = 0.06


def load_body():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name == "Body")
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o is not body:
            bpy.data.objects.remove(o, do_unlink=True)
    return arm, body


def dominant(v, names):
    if not v.groups:
        return None
    g = max(v.groups, key=lambda g: g.weight)
    return names[g.group]


## Where the sleeve ends, as a fraction of the forearm (elbow 0, wrist 1).
CUFF_T = 0.86


def build_torso(body, arm, centre_y):
    """Copy the coat-bone faces of the body, weld, offset, open the front."""
    names = {g.index: g.name for g in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    deform = bm.verts.layers.deform.verify()
    mw = body.matrix_world
    keep = set()
    wrists = []
    for side in ("l", "r"):
        a = arm.matrix_world @ arm.data.bones["lowerarm_" + side].head_local
        b = arm.matrix_world @ arm.data.bones["hand_" + side].head_local
        wrists.append((a, b))

    def past_wrist(p):
        # The cuff ends at the wrist: nothing past 96% of the forearm.
        for a, b in wrists:
            axis = b - a
            t = (p - a).dot(axis) / axis.length_squared
            # Measured off the forearm's LINE, not its end: the fingers run on
            # well past the wrist joint along that line.
            if t > CUFF_T and (p - (a + axis * t)).length < 0.13:
                return True
        return False
    for v in bm.verts:
        gs = v[deform]
        if not gs:
            continue
        name = names[max(gs.items(), key=lambda kv: kv[1])[0]]
        z = (mw @ v.co).z
        # Round the hips the skin is carried by the thighs: that too is
        # jacket down to the waist line, or the tights show through a band
        # of holes above the skirt.
        hip = name in ("thigh_l", "thigh_r") and z < WAIST_Z + SKIRT_OVERLAP + 0.05
        if (name in COAT_BONES or hip) and z >= WAIST_Z - 0.02 and not past_wrist(mw @ v.co):
            keep.add(v.index)
    doomed = [f for f in bm.faces if not all(v.index in keep for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0015)
    bm.normal_update()
    # Bridge the hollows: smooth the interior (the boundary -- neck, cuffs,
    # waist -- stays put, or the openings would shrink), then stand off.
    inner = [v for v in bm.verts if not v.is_boundary]
    for _ in range(SMOOTH_ITERS):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5,
                              use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        v.co = v.co + v.normal * OFFSET
    push_clear(bm, mw, body)
    # The open front: faces facing forward (-Y) inside the V.
    open_faces = []
    for f in bm.faces:
        c = mw @ f.calc_center_median()
        n = (mw.to_3x3() @ f.normal).normalized()
        if c.z < WAIST_Z or c.z > OPEN_TOP_Z + 0.06 or n.y > -0.2:
            continue
        t = min(max((c.z - WAIST_Z) / (OPEN_TOP_Z - WAIST_Z), 0.0), 1.0)
        if abs(c.x) < OPEN_WAIST + (OPEN_TOP - OPEN_WAIST) * t:
            open_faces.append(f)
    bmesh.ops.delete(bm, geom=open_faces, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Deleting whole faces leaves a saw-toothed edge. A cut edge is a
    # straight line: put every vertex on the opening's edge onto the V, and
    # every vertex on the bottom edge onto one level (the skirt covers it).
    inv = mw.inverted()
    for v in bm.verts:
        if not v.is_boundary:
            continue
        co = mw @ v.co
        cuff = None
        for a, b in wrists:
            axis = b - a
            t = (co - a).dot(axis) / axis.length_squared
            if t > 0.6 and (co - (a + axis * t)).length < 0.13:
                cuff = (a, axis, t)
        if cuff:
            # The cuff: one clean ring square to the forearm, at the line
            # past_wrist cut at -- not faces' ragged ends over the hand.
            a, axis, t = cuff
            co = co + axis * (CUFF_T - t)
        elif co.z < WAIST_Z + 0.03:
            co.z = WAIST_Z - 0.02
        elif co.z < OPEN_TOP_Z + 0.06 and co.y < centre_y - 0.06 and abs(co.x) < OPEN_TOP + 0.05:
            t = min(max((co.z - WAIST_Z) / (OPEN_TOP_Z - WAIST_Z), 0.0), 1.0)
            co.x = math.copysign(OPEN_WAIST + (OPEN_TOP - OPEN_WAIST) * t, co.x)
        else:
            continue
        v.co = inv @ co
    # Straightening moved edge vertices off the standoff; and Solidify will
    # grow the cloth THICK inward. Clear the body by both.
    bm.normal_update()
    push_clear(bm, mw, body, CLEAR + THICK)
    mesh = bpy.data.meshes.new("CoatBody")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatBody", mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = mw.copy()
    _body_groups(obj, body)
    return obj


def body_bvh(body):
    """The body surface in world space, for clearance queries."""
    mw = body.matrix_world
    verts = [mw @ v.co for v in body.data.vertices]
    polys = [tuple(p.vertices) for p in body.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def push_clear(bm, mw, body, clear=CLEAR):
    """Push out every vertex nearer than `clear` to the body, along the
    body's normal there. Smoothing pulls a convex shell inward (over the
    shoulder, the lats) -- this puts it back outside."""
    bvh = body_bvh(body)
    inv = mw.inverted()
    for v in bm.verts:
        co = mw @ v.co
        loc, nrm, _, _ = bvh.find_nearest(co)
        if loc is None:
            continue
        d = (co - loc).dot(nrm)
        if d < clear:
            v.co = inv @ (co + nrm * (clear - d))


def _body_groups(obj, body):
    """The copied faces carry the body's own skin weights in their deform
    layer, keyed by GROUP INDEX -- so the new object needs the body's groups
    in the body's order, or every weight lands on the wrong bone (the first
    build weighted a left forearm half to the right collarbone that way)."""
    for g in sorted(body.vertex_groups, key=lambda g: g.index):
        obj.vertex_groups.new(name=g.name)


def split_sleeves(torso, body):
    """The sleeves into their own object (their own texture layout): every
    face whose vertices are carried mostly by the arm bones, read straight
    off the weights the faces brought with them."""
    names = {g.index: g.name for g in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(torso.data)
    deform = bm.verts.layers.deform.verify()

    mw = torso.matrix_world

    def on_arm(v):
        # Carried by an arm bone AND outboard of the shoulder: the chest
        # beside the armpit is weighted to the upper arm too, and belongs to
        # the coat's body, not its sleeve.
        gs = v[deform]
        if not gs or names[max(gs.items(), key=lambda kv: kv[1])[0]] not in ARM_BONES:
            return False
        return abs((mw @ v.co).x) > SLEEVE_FROM_X
    arm_idx = {f.index for f in bm.faces if sum(on_arm(v) for v in f.verts) * 2 > len(f.verts)}
    sleeve_bm = bm.copy()
    bmesh.ops.delete(sleeve_bm, geom=[f for f in sleeve_bm.faces if f.index not in arm_idx], context="FACES")
    bmesh.ops.delete(sleeve_bm, geom=[v for v in sleeve_bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in arm_idx], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(torso.data)
    bm.free()
    mesh = bpy.data.meshes.new("CoatSleeve")
    sleeve_bm.to_mesh(mesh)
    sleeve_bm.free()
    obj = bpy.data.objects.new("CoatSleeve", mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = torso.matrix_world.copy()
    _body_groups(obj, body)
    return obj


def body_lookup(body):
    names = {g.index: g.name for g in body.vertex_groups}
    mw = body.matrix_world
    kd = KDTree(len(body.data.vertices))
    weights = []
    for v in body.data.vertices:
        kd.insert(mw @ v.co, v.index)
        weights.append({names[g.group]: g.weight for g in v.groups})
    kd.balance()
    return kd, weights


def copy_weights(obj, body, exclude=frozenset({"Head", "neck_01", "hand_l", "hand_r"})):
    kd, weights = body_lookup(body)
    groups = {}
    for v in obj.data.vertices:
        co = obj.matrix_world @ v.co
        # The nearest body vertex that is not head/neck/hand skin.
        for _, i, _ in kd.find_n(co, 8):
            w = {k: x for k, x in weights[i].items() if k not in exclude}
            if w:
                break
        total = sum(w.values()) or 1.0
        for name, x in w.items():
            if name not in groups:
                groups[name] = obj.vertex_groups.new(name=name)
            groups[name].add([v.index], x / total, "REPLACE")


def reweight_from_surface(obj, body, exclude=frozenset({"Head", "neck_01", "hand_l", "hand_r"})):
    """Each vertex's skin weights re-read from the body surface directly
    under it: the nearest point on the body, its face's vertex weights
    blended by closeness.

    Why: the copied faces arrive carrying their own vertex's weights, but
    SMOOTH_ITERS passes of smoothing then slide every vertex along the body
    by up to several centimetres -- so a sleeve vertex over the inner elbow
    was carrying the weights of skin that had been under the forearm. At
    rest nobody can tell; bend the elbow (the WHOA, the coat coming off) and
    the sleeve and the arm under it move differently, and the arm comes
    through. Weights read from where the cloth actually IS move it with the
    skin beneath it.
    """
    bvh = body_bvh(body)
    names = {g.index: g.name for g in body.vertex_groups}
    mw = body.matrix_world
    bverts = [mw @ v.co for v in body.data.vertices]
    group_of = {g.name: g for g in obj.vertex_groups}
    omw = obj.matrix_world
    for v in obj.data.vertices:
        co = omw @ v.co
        loc, _, fi, _ = bvh.find_nearest(co)
        if loc is None:
            continue
        poly = body.data.polygons[fi]
        acc = {}
        total = 0.0
        for vi in poly.vertices:
            k = 1.0 / ((bverts[vi] - loc).length + 1e-4)
            for g in body.data.vertices[vi].groups:
                n = names[g.group]
                if n in exclude or g.weight <= 0.0:
                    continue
                acc[n] = acc.get(n, 0.0) + g.weight * k
            total += k
        if not acc:
            continue
        top = sorted(acc.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
        norm = sum(w for _, w in top)
        for g in list(v.groups):
            obj.vertex_groups[g.group].remove([v.index])
        for n, w in top:
            if n not in group_of:
                group_of[n] = obj.vertex_groups.new(name=n)
            group_of[n].add([v.index], w / norm, "REPLACE")


def measure_hips(body):
    """(centre y, waist half-widths, seat half-widths) off the body mesh,
    arms left out (they hang beside the hips)."""
    mw = body.matrix_world
    pts = [mw @ v.co for v in body.data.vertices]
    pts = [p for p in pts if abs(p.x) < 0.25]

    def extent(z0, z1):
        band = [p for p in pts if z0 <= p.z <= z1]
        xs = [abs(p.x) for p in band]
        ys = [p.y for p in band]
        return max(xs), min(ys), max(ys)
    wx, wy0, wy1 = extent(WAIST_Z + SKIRT_OVERLAP - 0.02, WAIST_Z + SKIRT_OVERLAP + 0.01)
    sx, sy0, sy1 = extent(SEAT_Z - 0.02, WAIST_Z)
    cy = 0.5 * (sy0 + sy1)
    top = (wx + SKIRT_EASE[0], max(cy - wy0, wy1 - cy) + SKIRT_EASE[1])
    seat = (sx + SKIRT_EASE[0], 0.5 * (sy1 - sy0) + SKIRT_EASE[1])
    return cy, top, seat


def jacket_radius(torso, cy, z, n):
    """The jacket's outline at height z: its radius from (0, cy) in each of
    n angle buckets (angle 0 at the front, + round his left), gaps filled
    from the neighbours."""
    mw = torso.matrix_world
    r = [0.0] * n
    for v in torso.data.vertices:
        p = mw @ v.co
        if abs(p.z - z) > 0.02 or abs(p.x) > 0.3:
            continue
        a = math.atan2(p.x, -(p.y - cy)) % (2 * math.pi)
        k = int(a / (2 * math.pi) * n) % n
        r[k] = max(r[k], math.hypot(p.x, p.y - cy))
    for _ in range(n):
        if all(r):
            break
        r = [x or max(r[(i - 1) % n], r[(i + 1) % n]) for i, x in enumerate(r)]
    # A light smoothing: cloth spans the small dips of the outline.
    return [max(r[i], 0.5 * (r[(i - 1) % n] + r[(i + 1) % n])) for i in range(n)]


def build_skirt(body, torso):
    """The coat below the waist: open at the front, vented at both sides
    from mid-thigh down, falling in folds, flared to the hem.

    The first skirt was one closed cone weighted up to 75% to the thighs:
    each stride dragged it like a trouser leg and the knee still came
    through. Now it is three panels below the vents -- two fronts and a
    back tail -- that hang from the hips and only partly follow a leg."""
    cy, _, seat = measure_hips(body)
    hem = (seat[0] + HEM_FLARE[0], seat[1] + HEM_FLARE[1])
    # The top edge lies ON the jacket, just outside it, all the way round --
    # not an ellipse standing off it like the rim of a bucket.
    buckets = 72
    top_r = jacket_radius(torso, cy, WAIST_Z + SKIRT_OVERLAP, buckets)

    def seat_r(a, dims):
        return 1.0 / math.sqrt((math.sin(a) / dims[0]) ** 2 + (math.cos(a) / dims[1]) ** 2)
    print("skirt: centre y %.3f  seat %.3f x %.3f" % (cy, *seat))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    span = 2 * math.pi - 2 * SKIRT_FRONT_GAP

    def angle(s):
        return SKIRT_FRONT_GAP + span * s / SKIRT_SEGMENTS
    rings = []
    for r in range(SKIRT_RINGS + 1):
        t = r / SKIRT_RINGS
        z0 = WAIST_Z + SKIRT_OVERLAP
        z = z0 - (z0 - HEM_Z) * t
        # Folds start below the hips and deepen to the hem.
        amp = FOLD_AMP * max(0.0, (t - 0.12) / 0.88) ** 1.2
        ring = []
        for s in range(SKIRT_SEGMENTS + 1):
            a = angle(s)
            top = top_r[int(a / (2 * math.pi) * buckets) % buckets] + 0.006
            seat_a = max(seat_r(a, seat), top)
            if z > SEAT_Z:
                k = math.sin((z0 - z) / (z0 - SEAT_Z) * math.pi / 2)  # over the seat
                rad = top + (seat_a - top) * k
            else:
                k = (SEAT_Z - z) / (SEAT_Z - HEM_Z)
                rad = seat_a + (max(seat_r(a, hem), seat_a) - seat_a) * k
            rad += amp * math.sin(FOLDS * a)
            # Angle 0 is the front (-Y); +a goes round his left (+X).
            ring.append(bm.verts.new((rad * math.sin(a), cy - rad * math.cos(a), z)))
        rings.append(ring)

    def vented(s, z):
        # A face column centred within VENT_HALF of either side, below the
        # vent top, is left out.
        a = angle(s + 0.5)
        near_side = min(abs(a - math.pi / 2), abs(a - 3 * math.pi / 2))
        return near_side < VENT_HALF and z < VENT_TOP_Z
    for r in range(SKIRT_RINGS):
        for s in range(SKIRT_SEGMENTS):
            a, b = rings[r][s], rings[r][s + 1]
            c, d = rings[r + 1][s + 1], rings[r + 1][s]
            if vented(s, 0.5 * (a.co.z + d.co.z)):
                continue
            f = bm.faces.new((a, d, c, b))
            for loop, (rr, ss) in zip(f.loops, ((r, s), (r + 1, s), (r + 1, s + 1), (r, s + 1))):
                loop[uv].uv = (_body_u(angle(ss)), _body_v(rings[rr][ss].co.z))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Outward normals (Solidify grows inward from them).
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    f0 = bm.faces[0]
    c0 = f0.calc_center_median()
    if f0.normal.dot(Vector((c0.x, c0.y - cy, 0.0))) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("CoatSkirt")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatSkirt", mesh)
    bpy.context.collection.objects.link(obj)
    for name in ("pelvis", "thigh_l", "thigh_r"):
        obj.vertex_groups.new(name=name)
    for v in obj.data.vertices:
        t = min(max((WAIST_Z - v.co.z) / (WAIST_Z - HEM_Z), 0.0), 1.0)
        a = math.atan2(v.co.x, -(v.co.y - cy))         # 0 front, + his left
        front = math.cos(a) > 0.0
        if front:
            # A front panel follows its own leg.
            leg = t * FRONT_LEG
            side = 1.0 if v.co.x > 0 else 0.0
        else:
            leg = t * BACK_LEG
            side = min(max(0.5 + v.co.x / 0.30, 0.0), 1.0)   # +X is his left
        obj.vertex_groups["pelvis"].add([v.index], 1.0 - leg, "REPLACE")
        obj.vertex_groups["thigh_l"].add([v.index], leg * side, "REPLACE")
        obj.vertex_groups["thigh_r"].add([v.index], leg * (1.0 - side), "REPLACE")
    return obj


def build_lapels(torso, body, centre_y):
    """The front opening's edge turned back over the chest: a strip laid on
    the coat along each side of the V, narrow at the waist, widest under
    the collar, carrying the weights of the edge it folds from."""
    bm = bmesh.new()
    bm.from_mesh(torso.data)
    bm.normal_update()
    deform = bm.verts.layers.deform.verify()
    mw = torso.matrix_world
    edges = []
    for e in bm.edges:
        if not e.is_boundary:
            continue
        a, b = (mw @ v.co for v in e.verts)
        mid = 0.5 * (a + b)
        if WAIST_Z + SKIRT_OVERLAP + 0.08 < mid.z < OPEN_TOP_Z + 0.03 and mid.y < centre_y - 0.06 \
                and abs(mid.x) < OPEN_TOP + 0.04:
            edges.append(e)
    old_faces = list(bm.faces)
    uv = bm.loops.layers.uv.new("UVMap")
    made = {}

    def pair(v):
        if v in made:
            return made[v]
        co = mw @ v.co
        n = v.normal.normalized()
        t = min(max((co.z - WAIST_Z) / (OPEN_TOP_Z - WAIST_Z), 0.0), 1.0)
        width = LAPEL_WAIST + (LAPEL_TOP - LAPEL_WAIST) * t
        side = Vector((1.0 if co.x > 0 else -1.0, 0.0, 0.0))
        lateral = (side - n * side.dot(n)).normalized()
        inner = bm.verts.new(v.co + n * 0.004)
        outer = bm.verts.new(v.co + lateral * width + n * 0.009)
        for nv in (inner, outer):
            for k, w in v[deform].items():
                nv[deform][k] = w
        made[v] = (inner, outer, co.z)
        return made[v]
    for e in edges:
        va, vb = e.verts
        ia, oa, za = pair(va)
        ib, ob, zb = pair(vb)
        f = bm.faces.new((ia, ib, ob, oa))
        v_of = {ia: za, ib: zb, ob: zb, oa: za}
        u_of = {ia: 0.0, ib: 0.0, ob: 1.0, oa: 1.0}
        for loop in f.loops:
            loop[uv].uv = (u_of[loop.vert], (v_of[loop.vert] - WAIST_Z) / (OPEN_TOP_Z + 0.03 - WAIST_Z))
    bmesh.ops.delete(bm, geom=old_faces, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Face the lapel out, the way the coat faces.
    bm.normal_update()
    for f in bm.faces:
        if f.normal.y > 0.0:
            f.normal_flip()
    mesh = bpy.data.meshes.new("CoatLapel")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatLapel", mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = mw.copy()
    _body_groups(obj, body)
    return obj


def solidify(obj, lining=True):
    """Give a cloth part its thickness: THICK inward, with a rim, the inner
    shell on material slot 1 (the lining)."""
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = THICK
    mod.offset = -1.0
    mod.use_rim = True
    mod.use_even_offset = False
    mod.use_quality_normals = True
    mod.material_offset = 1 if lining else 0
    # The cut edge too: the lining shows at the hem, the cuffs, the opening.
    mod.material_offset_rim = 1 if lining else 0
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def build_collar(arm):
    """A high stand collar round the neck base, open at the front."""
    neck = arm.matrix_world @ arm.data.bones["neck_01"].head_local
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    gap = math.radians(38)
    seg = 32
    rows = []
    for k, (dz, r) in enumerate(((-0.035, 0.092), (0.05, 0.108))):
        row = []
        for s in range(seg + 1):
            a = gap + (2 * math.pi - 2 * gap) * s / seg
            row.append(bm.verts.new((neck.x + r * math.sin(a), neck.y + 0.01 - r * 0.9 * math.cos(a),
                                     neck.z + dz)))
        rows.append(row)
    for s in range(seg):
        f = bm.faces.new((rows[0][s], rows[1][s], rows[1][s + 1], rows[0][s + 1]))
        for loop, (kk, ss) in zip(f.loops, ((0, s), (1, s), (1, s + 1), (0, s + 1))):
            loop[uv].uv = (ss / seg, kk)
    mesh = bpy.data.meshes.new("CoatCollar")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatCollar", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_scales(arm):
    """Gold scale epaulettes: overlapping rows of rounded plates on each
    shoulder cap, the lowest row hanging over the top of the arm."""
    bm = bmesh.new()
    for side in (1.0, -1.0):
        name = "upperarm_l" if side > 0 else "upperarm_r"
        head = arm.matrix_world @ arm.data.bones[name].head_local
        centre = Vector((head.x + side * 0.01, head.y, head.z + 0.01))
        for row in range(5):
            # Rows from the top of the shoulder cap down over the deltoid.
            elev = math.radians(78 - row * 14)
            count = 5 + row * 2
            for k in range(count):
                az = math.radians(-65 + 130 * (k + 0.5 * (row % 2)) / count)
                # A true sphere cap on the shoulder joint: outward (side) and
                # up, swept front to back by az.
                d = Vector((side * math.cos(elev) * math.cos(az),
                            -math.cos(elev) * math.sin(az),
                            math.sin(elev))).normalized()
                p = centre + d * (0.098 + 0.004 * row)
                down = Vector((0, 0, -1)) - d * d.dot(Vector((0, 0, -1)))
                if down.length < 1e-4:
                    down = Vector((side, 0, 0))
                down.normalize()
                across = d.cross(down).normalized()
                w, h = 0.040, 0.046
                # A rounded plate: a five-sided scale, point down, each row
                # lying over the one below (shingled).
                pts = [p - across * w * 0.5 - down * h * 0.3,
                       p + across * w * 0.5 - down * h * 0.3,
                       p + across * w * 0.45 + down * h * 0.35,
                       p + down * h * 0.7,
                       p - across * w * 0.45 + down * h * 0.35]
                vs = [bm.verts.new(q + d * 0.003 * (5 - row)) for q in pts]
                bm.faces.new(vs)
    mesh = bpy.data.meshes.new("CoatScales")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatScales", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _body_u(angle):
    """Round the body: 0.5 at the front centre, wrapping at the back."""
    return (0.5 + angle / (2 * math.pi)) % 1.0


def _body_v(z):
    return (z - HEM_Z) / (1.60 - HEM_Z)


def cylindrical_uv(obj, axis_from, axis_to):
    """UVs round an axis (the body's or an arm's) and along it."""
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    a = axis_from
    ax = (axis_to - axis_from)
    length = ax.length
    ax.normalize()
    ref = Vector((0, -1, 0)) - ax * ax.dot(Vector((0, -1, 0)))
    ref.normalize()
    side = ax.cross(ref)
    for poly in mesh.polygons:
        us = []
        for li in poly.loop_indices:
            p = obj.matrix_world @ mesh.vertices[mesh.loops[li].vertex_index].co - a
            h = p.dot(ax)
            q = p - ax * h
            ang = math.atan2(q.dot(side), q.dot(ref))
            us.append([_body_u(ang), h / length, li])
        # Keep a face from straddling the wrap at the back.
        if max(u for u, _, _ in us) - min(u for u, _, _ in us) > 0.5:
            for e in us:
                if e[0] < 0.5:
                    e[0] += 1.0
        for u, v, li in us:
            layer.data[li].uv = (u, v)


def paint_body(path_rgb, path_orm):
    """White, with red panels either side of the front and down the back,
    gold studded trim edged in blue along the opening, the hem and the panel
    seams; a red-and-gold waist sash."""
    W, H = 2048, 1024
    img = Image.new("RGB", (W, H), (236, 234, 230))
    orm = Image.new("RGB", (W, H), (255, CLOTH_ROUGH, 0))  # AO, rough, metal
    d, o = ImageDraw.Draw(img), ImageDraw.Draw(orm)
    RED, GOLD, BLUE = (186, 26, 34), (214, 172, 84), (46, 52, 170)

    def band(u0, u1, colour, metal=False):
        for x0 in (u0,):
            d.rectangle((int(x0 * W), 0, int(u1 * W), H), fill=colour)
            if metal:
                o.rectangle((int(x0 * W), 0, int(u1 * W), H), fill=(255, 90, 230))

    def trim(u, width=0.012):
        band(u - width, u + width, GOLD, True)
        band(u - width - 0.004, u - width, BLUE)
        band(u + width, u + width + 0.004, BLUE)
        # Studs down the trim.
        for y in range(8, H, 26):
            cx = int(u * W)
            d.ellipse((cx - 7, y - 7, cx + 7, y + 7), fill=(245, 222, 150))

    # Red panels: at the sides of the front and a broad one down the back.
    for u0, u1 in ((0.30, 0.40), (0.60, 0.70), (0.90, 1.0), (0.0, 0.10)):
        band(u0, u1, RED)
    for u in (0.30, 0.40, 0.60, 0.70, 0.10, 0.90):
        trim(u)
    # The opening's edges (the front centre is at 0.5): gold trim either side.
    for u in (0.46, 0.54):
        trim(u, 0.014)
    # Hem.
    d.rectangle((0, H - 34, W, H), fill=GOLD)
    o.rectangle((0, H - 34, W, H), fill=(255, 90, 230))
    d.rectangle((0, H - 40, W, H - 34), fill=BLUE)
    # The waist sash: red with gold edges, at the waist line.
    wz = int(H * (1.0 - _body_v(WAIST_Z + SKIRT_OVERLAP + 0.005)))
    d.rectangle((0, wz - 22, W, wz + 22), fill=RED)
    for y in (wz - 26, wz + 22):
        d.rectangle((0, y, W, y + 4), fill=GOLD)
        o.rectangle((0, y, W, y + 4), fill=(255, 90, 230))
    img.save(path_rgb, optimize=True)
    _mottle(orm).save(path_orm, optimize=True)


def paint_sleeve(path_rgb, path_orm):
    """Red sleeves, a white stripe with blue piping down the front, and dark
    bands studded in gold every few centimetres, as in the photograph."""
    W, H = 1024, 1024
    img = Image.new("RGB", (W, H), (186, 26, 34))
    orm = Image.new("RGB", (W, H), (255, CLOTH_ROUGH, 0))
    d, o = ImageDraw.Draw(img), ImageDraw.Draw(orm)
    d.rectangle((int(0.44 * W), 0, int(0.56 * W), H), fill=(236, 234, 230))
    for u in (0.435, 0.565):
        d.rectangle((int(u * W) - 3, 0, int(u * W) + 3, H), fill=(46, 52, 170))
    for y in range(40, H, 70):
        d.rectangle((0, y, W, y + 18), fill=(40, 34, 30))
        d.rectangle((0, y + 7, W, y + 11), fill=(214, 172, 84))
        o.rectangle((0, y + 7, W, y + 11), fill=(255, 90, 230))
        for x in range(10, W, 44):
            d.ellipse((x - 7, y + 2, x + 7, y + 16), fill=(245, 222, 150))
            o.ellipse((x - 7, y + 2, x + 7, y + 16), fill=(255, 80, 240))
    img.save(path_rgb, optimize=True)
    _mottle(orm).save(path_orm, optimize=True)


## Cloth roughness in the ORM's green: a satin-backed drill, not a mirror.
CLOTH_ROUGH = 184


def _mottle(orm):
    """Break up the cloth's roughness a little (+-6%), and darken its AO
    toward the fold hollows' average -- a flat value is what reads as paint.
    Metal (the trim, the studs) is left alone."""
    a = np.asarray(orm).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n = (np.sin(xx * 0.043 + np.sin(yy * 0.021) * 3.0) * np.sin(yy * 0.057 + xx * 0.011)
         + 0.5 * np.sin(xx * 0.13 - yy * 0.09))
    cloth = a[..., 2] < 128
    a[..., 1] = np.where(cloth, a[..., 1] + n * 11.0, a[..., 1])
    a[..., 0] = np.where(cloth, 238.0 + n * 8.0, a[..., 0])
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def paint_lapel(path_rgb):
    """The turned-back lapel: red satin, gold studded trim at its outer
    edge in blue piping (u 0 is the fold, 1 the outer edge)."""
    W, H = 128, 1024
    img = Image.new("RGB", (W, H), (176, 24, 32))
    d = ImageDraw.Draw(img)
    d.rectangle((int(0.70 * W), 0, W, H), fill=(214, 172, 84))
    d.rectangle((int(0.66 * W), 0, int(0.70 * W), H), fill=(46, 52, 170))
    for y in range(10, H, 30):
        cx = int(0.85 * W)
        d.ellipse((cx - 8, y - 8, cx + 8, y + 8), fill=(245, 222, 150))
    img.save(path_rgb, optimize=True)


def _normal_png(height, strength, path):
    """A tangent-space normal map (OpenGL, +Y up) from a height field."""
    gy, gx = np.gradient(height)
    n = np.dstack((-gx * strength, gy * strength, np.ones_like(height)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255.0 + 0.5).astype(np.uint8)).save(path, optimize=True)


def _twill(h, w, period=6.0):
    """A fine diagonal twill: the weave the eye reads as cloth up close."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return 0.5 + 0.5 * np.sin((xx + yy) * (2 * math.pi / period))


def paint_normals(path_body, path_sleeve):
    """The fabric's surface: the twill everywhere; soft horizontal pull
    lines gathered above the waist sash; fine vertical folds in the skirt
    between the modelled ones, deepening to the hem. Sleeves: the twill,
    and crease rings at the elbow (the middle of the sleeve's length)."""
    H, W = 1024, 2048
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = 1.0 - yy / H                         # the body's v: 0 hem, 1 collar
    u = xx / W
    height = _twill(H, W) * 0.35
    waist_v = _body_v(WAIST_Z + SKIRT_OVERLAP + 0.005)
    # Gathered above the sash: ripples fading over 12 cm of coat.
    above = np.clip((v - waist_v) / 0.10, 0.0, 1.0)
    gather = np.exp(-((v - waist_v - 0.045) / 0.045) ** 2)
    height += gather * (above > 0) * 2.2 * np.sin(v * 2 * math.pi * 55.0) \
        * (0.6 + 0.4 * np.sin(u * 2 * math.pi * 7.0))
    # Skirt: fine folds, three between each modelled fold.
    below = np.clip((waist_v - v) / max(waist_v, 1e-3), 0.0, 1.0)
    height += below ** 1.3 * 3.0 * np.sin(u * 2 * math.pi * FOLDS * 4.0
                                          + np.sin(v * 9.0) * 0.8)
    _normal_png(height, 0.9, path_body)
    H = W = 1024
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = yy / H
    height = _twill(H, W) * 0.35
    elbow = np.exp(-((v - 0.52) / 0.07) ** 2)
    height += elbow * 2.5 * np.sin(v * 2 * math.pi * 30.0) \
        * (0.5 + 0.5 * np.cos((xx / W - 0.5) * 2 * math.pi))
    _normal_png(height, 0.9, path_sleeve)


def main() -> int:
    arm, body = load_body()
    centre_y = measure_hips(body)[0]
    torso = build_torso(body, arm, centre_y)
    lapels = build_lapels(torso, body, centre_y)
    sleeves = split_sleeves(torso, body)
    # Weights from where the cloth ended up, not where its faces came from.
    reweight_from_surface(torso, body)
    reweight_from_surface(sleeves, body)
    collar = build_collar(arm)
    copy_weights(collar, body, exclude=frozenset({"Head", "hand_l", "hand_r"}))
    scales = build_scales(arm)
    copy_weights(scales, body)
    skirt = build_skirt(body, torso)
    # UVs: the torso round the body's vertical axis, the sleeves round each
    # arm (their own island, u by the arm's side).
    # Round his own centre line (see measure_hips), so u 0.5 is his front.
    cylindrical_uv(torso, Vector((0, centre_y, HEM_Z)), Vector((0, centre_y, 1.60)))
    lay = sleeves.data.uv_layers.new(name="UVMap")
    for poly in sleeves.data.polygons:
        for li in poly.loop_indices:
            co = sleeves.matrix_world @ sleeves.data.vertices[sleeves.data.loops[li].vertex_index].co
            s = 1.0 if co.x > 0 else -1.0
            sh = arm.matrix_world @ arm.data.bones["upperarm_l" if s > 0 else "upperarm_r"].head_local
            wr = arm.matrix_world @ arm.data.bones["hand_l" if s > 0 else "hand_r"].head_local
            axis = (wr - sh)
            L = axis.length
            axis.normalize()
            p = co - sh
            h = p.dot(axis)
            q = p - axis * h
            ang = math.atan2(q.dot(axis.cross(Vector((0, -1, 0))).normalized()),
                             q.dot(Vector((0, -1, 0))))
            lay.data[li].uv = (_body_u(ang), 1.0 - h / L)
    # Materials by part (the game dresses each by name), and the cloth's
    # lining on the inner shell Solidify makes.
    parts = (torso, sleeves, collar, scales, skirt, lapels)
    for obj in parts:
        # Copied faces keep the body's material slots (skin, tights...):
        # every face of a part is that part's cloth.
        for poly in obj.data.polygons:
            poly.material_index = 0
        obj.data.materials.append(bpy.data.materials.new(obj.name))
    for obj in (torso, sleeves, skirt):
        obj.data.materials.append(bpy.data.materials.new(obj.name + "Lining"))
        solidify(obj)
    solidify(collar, lining=False)
    # Skin: every part to the armature.
    for obj in parts:
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        bpy.context.view_layer.objects.active = obj
    bpy.data.objects.remove(body, do_unlink=True)
    paint_body(TEX / "cody_coat_body.png", TEX / "cody_coat_orm_body.png")
    paint_sleeve(TEX / "cody_coat_sleeve.png", TEX / "cody_coat_orm_sleeve.png")
    paint_lapel(TEX / "cody_coat_lapel.png")
    paint_normals(TEX / "cody_coat_nrm_body.png", TEX / "cody_coat_nrm_sleeve.png")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                              use_selection=True, export_skins=True,
                              export_animations=False, export_materials="PLACEHOLDER",
                              export_yup=True)
    tris = sum(len(p.vertices) - 2 for o in parts for p in o.data.polygons)
    print("cody_coat: %d triangles -> %s" % (tris, OUT))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
