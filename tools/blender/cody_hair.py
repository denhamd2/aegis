#!/usr/bin/env python3
"""Cody Rhodes's hair, as geometry: a layered shell over his scalp.

The supplied model's hair is paint on a skull -- a short crop with no
height -- and the owner's references show it platinum, short at the sides
and back, and LONGER ON TOP, swept up off the forehead and back over the
crown. Height is geometry, so this builds it.

Run:  python3 tools/blender/cody_hair.py
Writes game/assets/characters/cody_hair.glb and cody_hair_strands.png.

How:
* The SCALP is found on the head mesh by its own UVs: every head face whose
  UV lands in the hair region of the head texture -- the same region
  tools/assets/build_cody_textures.py recolours -- so the hair starts
  exactly at the painted hairline.
* SHELLS: that scalp is copied out in layers along its normals (the
  shell-hair technique), each layer a little further out and a little
  further BACK, so the stack leans into a swept-back shape. The height
  field is tall at the front of the top (the lift off the forehead), easing
  over the crown and short at the sides and nape.
* STRANDS: every shell carries one strand texture, UV-mapped so the strands
  run front-to-back over the top and downward at the sides; the inner shells
  are dense and dark at the root, the outer ones sparse and platinum, so
  the surface breaks up into strands instead of reading as a helmet.
* It is rigid on his Head bone (hair this short does not move). It ships in
  the skeleton's own space; CodyModel hangs it on a BoneAttachment3D.

Deterministic: same inputs, byte-identical outputs.
"""

from __future__ import annotations

import importlib.util
import math
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import bmesh  # noqa: E402
import numpy as np
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "game/assets/characters/cody_rhodes.glb"
OUT = REPO / "game/assets/characters/cody_hair.glb"
STRANDS = REPO / "game/assets/characters/cody_hair_strands.png"
HEAD_MATERIAL = "xmaterial_c3d4d9e78b44a79"

_spec = importlib.util.spec_from_file_location(
    "cody_tex", REPO / "tools/assets/build_cody_textures.py")
cody_tex = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cody_tex)

LAYERS = 10
## Over this distance in from the hairline the shells come down to the skin.
HAIRLINE_TAPER = 0.045
## The height field, metres off the scalp at the outermost shell.
LIFT_FRONT = 0.062      # the front of the top, off the forehead
LIFT_CROWN = 0.032      # over the crown
LIFT_SIDE = 0.017       # the short sides and the nape
## How far the outermost shell sits BEHIND the scalp point it grew from,
## per metre of lift: the sweep.
SWEEP = 0.55


def _inside(poly, x, y):
    n, inside = len(poly), False
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def is_hair(u, v):
    """The texture's hair region (build_cody_textures.py), in UV space."""
    x, y = u, 1.0 - v
    if y > cody_tex.HAIR_BOTTOM:
        return False
    for x0, y0, x1, y1 in cody_tex.CORNERS:
        if x0 <= x <= x1 and y0 <= y <= y1:
            return False
    return not _inside(cody_tex.SKIN, x, y)


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = bpy.data.objects["Body"]
    head_mat = [i for i, m in enumerate(body.data.materials) if m.name == HEAD_MATERIAL][0]

    bm = bmesh.new()
    bm.from_mesh(body.data)
    uv = bm.loops.layers.uv.active
    doomed = []
    for f in bm.faces:
        if f.material_index != head_mat:
            doomed.append(f)
            continue
        cu = sum(l[uv].uv.x for l in f.loops) / len(f.loops)
        cv = sum(l[uv].uv.y for l in f.loops) / len(f.loops)
        if not is_hair(cu, cv):
            doomed.append(f)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
    bm.normal_update()
    mw = body.matrix_world
    pts = [mw @ v.co for v in bm.verts]
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    top, bottom = max(zs), min(zs)
    front, back = min(ys), max(ys)
    print("scalp: %d verts, %d faces, z %.3f..%.3f, y %.3f..%.3f"
          % (len(bm.verts), len(bm.faces), bottom, top, front, back))

    # Every shell tapers down to the scalp at the hairline. Without it the
    # stack ended in a wall at the forehead -- each shell's edge a step, the
    # darker inner shells showing between them as a brown band -- where real
    # hair grows OUT of the skin and has no height at all at its edge.
    # Only the FOREHEAD hairline: tapering all round the patch also pulled
    # the hair down onto the skull around each ear's notch, where it sank
    # into the scalp and showed as a grey patch at the temple.
    boundary = set()
    for e in bm.edges:
        if len(e.link_faces) == 1:
            for v in e.verts:
                n = (mw.to_3x3() @ v.normal).normalized()
                if n.y < -0.25 and (mw @ v.co).z > bottom + 0.45 * (top - bottom):
                    boundary.add(v)
    from mathutils.kdtree import KDTree
    edge_kd = KDTree(len(boundary))
    for i, v in enumerate(boundary):
        edge_kd.insert(mw @ v.co, i)
    edge_kd.balance()

    def taper(p):
        _, _, d = edge_kd.find(p)
        return smooth(d / HAIRLINE_TAPER)

    def lift(p, n):
        # Wide, soft transitions from the top to the sides: a sharp one left
        # a groove along each temple that shaded as a grey hollow.
        up = smooth((p.z - (bottom + 0.35 * (top - bottom))) / (0.65 * (top - bottom)))
        frontness = smooth((back - p.y) / (back - front))
        on_top = up * smooth((n.z + 0.15) / 0.95)
        h = LIFT_SIDE + (LIFT_CROWN - LIFT_SIDE) * on_top
        h += (LIFT_FRONT - LIFT_CROWN) * on_top * frontness ** 1.5
        return h

    # Strand UVs, ONE continuous layout (the first version switched between
    # a top mapping and a side mapping on the surface normal, and the seam
    # between them smeared the strands into a grey patch at each temple):
    # u runs AROUND the head's front-to-back axis (arc length over the top
    # and down each side), v runs back from the hairline and down the sides,
    # so strands lie combed back over the top and down-and-back at the sides.
    cx = 0.5 * (max(xs) + min(xs))
    # The axis sits well BELOW the head: an axis through the skull fanned
    # the strands out from one point on the forehead (planes through it cut
    # the front of the head radially). From below, lines of constant u run
    # nearly straight up the front and back over the top, the way hair
    # combed back off the forehead lies.
    cz = bottom - 0.35

    def strand_uv(p, n):
        ang = math.atan2(p.x - cx, p.z - cz)
        u = ang * (top - cz) * 6.0
        v = (p.y - front) * 11.0 + (top - p.z) * 7.0
        return u, v

    base = bm.copy()
    base.verts.ensure_lookup_table()
    parts = []
    for layer in range(LAYERS + 1):
        k = layer / LAYERS
        lb = base.copy()
        luv = lb.loops.layers.uv.active
        for v in lb.verts:
            p = mw @ v.co
            n = (mw.to_3x3() @ v.normal).normalized()
            h = lift(p, n) * taper(p)
            off = n * (0.004 + h * k) + Vector((0.0, SWEEP * h * k * k, 0.0))
            v.co = mw.inverted() @ (p + off)
        for f in lb.faces:
            for l in f.loops:
                p = mw @ l.vert.co
                n = (mw.to_3x3() @ l.vert.normal).normalized()
                l[luv].uv = strand_uv(p, n)
        mesh = bpy.data.meshes.new("HairShell%02d" % layer)
        lb.to_mesh(mesh)
        lb.free()
        obj = bpy.data.objects.new("HairShell%02d" % layer, mesh)
        bpy.context.collection.objects.link(obj)
        # Shade as ITSELF: the copied scalp carried the head's custom split
        # normals, so every shell lit like the skull underneath it -- the
        # temple hollow showed through the hair as a grey patch.
        with bpy.context.temp_override(object=obj, active_object=obj,
                                       selected_objects=[obj]):
            if mesh.has_custom_normals:
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        for poly in mesh.polygons:
            poly.use_smooth = True
        # Into the ARMATURE's space: CodyModel re-expresses it in the Head
        # bone's rest frame using Godot's own rest pose, so no Blender bone
        # axis convention leaks into the placement.
        obj.matrix_world = arm.matrix_world.inverted() @ mw
        mesh.transform(obj.matrix_basis)
        obj.matrix_basis.identity()
        mat = bpy.data.materials.new(obj.name)
        mesh.materials.append(mat)
        parts.append(obj)
    base.free()
    bm.free()
    for o in list(bpy.data.objects):
        if o not in parts:
            bpy.data.objects.remove(o, do_unlink=True)
    paint_strands()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_materials="PLACEHOLDER", export_yup=True,
                              export_animations=False, export_skins=False)
    print("cody_hair: %d shells -> %s" % (len(parts), OUT))
    return 0


def paint_strands():
    """CLUMPS of strands, running along v -- the owner's references show
    his hair in chunky, separated pieces swept back (visual QA against
    them: a texture of single fine fibres read as an even cap).

    Each clump is a tapered bundle: 5-9 strands fanning from a wide root to a
    shared point, one tone per clump (bleached hair streaks by the piece),
    with a darker core. RGB is that tone; alpha is coverage, strongest down
    each clump's middle, so the outer shells -- cut at higher alpha -- keep
    only clump centres and the silhouette breaks into pieces."""
    rng = np.random.default_rng(23)
    W = H = 1024
    alpha = Image.new("L", (W, H), 0)
    shade = Image.new("L", (W, H), 200)
    da, ds = ImageDraw.Draw(alpha), ImageDraw.Draw(shade)
    for _ in range(820):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        length = rng.uniform(260, 560)
        half = rng.uniform(8, 30)
        lean = rng.normal(0.0, 26.0)
        tone = int(rng.uniform(150, 255))
        strands = int(rng.integers(5, 10))
        for k in range(strands):
            f = (k / (strands - 1)) * 2.0 - 1.0
            start = (x + f * half, y)
            end = (x + lean + f * half * 0.15, y + length)
            core = 1.0 - abs(f) * 0.6
            a_val = int(255 * core * rng.uniform(0.75, 1.0))
            t_val = max(60, min(255, int(tone * (0.85 + 0.15 * core))))
            for dx in (-W, 0, W):
                for dy in (-H, 0, H):
                    seg = [(start[0] + dx, start[1] + dy), (end[0] + dx, end[1] + dy)]
                    da.line(seg, fill=a_val, width=3)
                    ds.line(seg, fill=t_val, width=3)
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.2))
    shade = shade.filter(ImageFilter.GaussianBlur(1.0))
    rgb = Image.merge("RGB", (shade, shade, shade))
    rgb.putalpha(alpha)
    rgb.save(STRANDS, optimize=True)


if __name__ == "__main__":
    bpy_exit.finish(main())
