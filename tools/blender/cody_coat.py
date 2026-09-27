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

* The TORSO AND SLEEVES are his own body surface, pushed out: every face of
  the body mesh whose vertices ride the spine, clavicles and arms (not the
  hands, neck or head) is copied and offset along its normals. So the coat
  fits exactly and deforms exactly, and cannot drift off a body it was made
  from.
* WEIGHTS are copied from the nearest body vertex -- his own skinning, so the
  sleeves bend with his elbows. The SKIRT is not a copy of anything (a coat
  does not have legs): it is a flared cone from the hips, weighted to the
  pelvis at the waist and increasingly to the thigh on its side toward the
  hem, so it swings with his stride.
* The coat is OPEN down the front in a V, to the waist, as in the photo.
* UVs are cylindrical in each part's own frame (round the body / round the
  arm, and up), and the textures are painted to that layout below.

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
OFFSET = 0.016            # cloth over skin
WAIST_Z = 1.0             # the torso part stops here; the skirt starts
HEM_Z = 0.30              # mid-shin
## The front opening, a V: half-width at the waist and at the collar.
OPEN_WAIST = 0.035
OPEN_TOP = 0.11
OPEN_TOP_Z = 1.47
## The skirt: hip ellipse at the waist, flaring to the hem.
SKIRT_TOP = (0.20, 0.155)
SKIRT_HEM = (0.31, 0.25)
SKIRT_FRONT_GAP = math.radians(16)  # half-angle of the open front
SKIRT_RINGS = 12
SKIRT_SEGMENTS = 48


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


def build_torso(body, arm):
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
            if t > 0.86 and (p - (a + axis * t)).length < 0.13:
                return True
        return False
    for v in bm.verts:
        gs = v[deform]
        if not gs:
            continue
        name = names[max(gs.items(), key=lambda kv: kv[1])[0]]
        z = (mw @ v.co).z
        if name in COAT_BONES and z >= WAIST_Z - 0.02 and not past_wrist(mw @ v.co):
            keep.add(v.index)
    doomed = [f for f in bm.faces if not all(v.index in keep for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0015)
    bm.normal_update()
    for v in bm.verts:
        v.co = v.co + v.normal * OFFSET
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
    mesh = bpy.data.meshes.new("CoatBody")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatBody", mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = mw.copy()
    _body_groups(obj, body)
    return obj


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


def build_skirt():
    """A flared cone from the hips to mid-shin, open at the front."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = []
    for r in range(SKIRT_RINGS + 1):
        t = r / SKIRT_RINGS
        z = WAIST_Z + 0.01 - (WAIST_Z + 0.01 - HEM_Z) * t
        ax = SKIRT_TOP[0] + (SKIRT_HEM[0] - SKIRT_TOP[0]) * t ** 1.3
        ay = SKIRT_TOP[1] + (SKIRT_HEM[1] - SKIRT_TOP[1]) * t ** 1.3
        ring = []
        for s in range(SKIRT_SEGMENTS + 1):
            # From one side of the front gap round the back to the other.
            a = SKIRT_FRONT_GAP + (2 * math.pi - 2 * SKIRT_FRONT_GAP) * s / SKIRT_SEGMENTS
            # Angle 0 is the front (-Y); +a goes round his left (+X).
            ring.append(bm.verts.new((ax * math.sin(a), 0.02 - ay * math.cos(a), z)))
        rings.append(ring)
    for r in range(SKIRT_RINGS):
        for s in range(SKIRT_SEGMENTS):
            a, b = rings[r][s], rings[r][s + 1]
            c, d = rings[r + 1][s + 1], rings[r + 1][s]
            f = bm.faces.new((a, d, c, b))
            for loop, (rr, ss) in zip(f.loops, ((r, s), (r + 1, s), (r + 1, s + 1), (r, s + 1))):
                ang = SKIRT_FRONT_GAP + (2 * math.pi - 2 * SKIRT_FRONT_GAP) * ss / SKIRT_SEGMENTS
                loop[uv].uv = (_body_u(ang), _body_v(rings[rr][ss].co.z))
    mesh = bpy.data.meshes.new("CoatSkirt")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("CoatSkirt", mesh)
    bpy.context.collection.objects.link(obj)
    for name in ("pelvis", "thigh_l", "thigh_r"):
        obj.vertex_groups.new(name=name)
    for v in obj.data.vertices:
        t = (WAIST_Z - v.co.z) / (WAIST_Z - HEM_Z)
        leg = min(max(t, 0.0), 1.0) * 0.75
        side = min(max(0.5 + v.co.x / 0.20, 0.0), 1.0)   # +X is his left
        obj.vertex_groups["pelvis"].add([v.index], 1.0 - leg, "REPLACE")
        obj.vertex_groups["thigh_l"].add([v.index], leg * side, "REPLACE")
        obj.vertex_groups["thigh_r"].add([v.index], leg * (1.0 - side), "REPLACE")
    return obj


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
    orm = Image.new("RGB", (W, H), (255, 150, 0))      # AO, rough, metal
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
    wz = int(H * (1.0 - _body_v(WAIST_Z + 0.02)))
    d.rectangle((0, wz - 22, W, wz + 22), fill=RED)
    for y in (wz - 26, wz + 22):
        d.rectangle((0, y, W, y + 4), fill=GOLD)
        o.rectangle((0, y, W, y + 4), fill=(255, 90, 230))
    img.save(path_rgb, optimize=True)
    orm.save(path_orm, optimize=True)


def paint_sleeve(path_rgb, path_orm):
    """Red sleeves, a white stripe with blue piping down the front, and dark
    bands studded in gold every few centimetres, as in the photograph."""
    W, H = 1024, 1024
    img = Image.new("RGB", (W, H), (186, 26, 34))
    orm = Image.new("RGB", (W, H), (255, 150, 0))
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
    orm.save(path_orm, optimize=True)


def main() -> int:
    arm, body = load_body()
    torso = build_torso(body, arm)
    sleeves = split_sleeves(torso, body)
    collar = build_collar(arm)
    copy_weights(collar, body, exclude=frozenset({"Head", "hand_l", "hand_r"}))
    scales = build_scales(arm)
    copy_weights(scales, body)
    skirt = build_skirt()
    # UVs: the torso round the body's vertical axis, the sleeves round each
    # arm (their own island, u by the arm's side).
    cylindrical_uv(torso, Vector((0, 0.02, HEM_Z)), Vector((0, 0.02, 1.60)))
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
    # Skin: every part to the armature.
    for obj in (torso, sleeves, collar, scales, skirt):
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        mat = bpy.data.materials.new(obj.name)
        obj.data.materials.append(mat)
        bpy.context.view_layer.objects.active = obj
    bpy.data.objects.remove(body, do_unlink=True)
    paint_body(TEX / "cody_coat_body.png", TEX / "cody_coat_orm_body.png")
    paint_sleeve(TEX / "cody_coat_sleeve.png", TEX / "cody_coat_orm_sleeve.png")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                              use_selection=True, export_skins=True,
                              export_animations=False, export_materials="PLACEHOLDER",
                              export_yup=True)
    tris = sum(len(p.vertices) - 2 for o in (torso, sleeves, collar, scales, skirt)
               for p in o.data.polygons)
    print("cody_coat: %d triangles -> %s" % (tris, OUT))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
